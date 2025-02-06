// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {DeployUpgrade} from "../scripts/DeployUpgrade.s.sol";
import {StaticATokenLM, IERC20} from "../src/StaticATokenLM.sol";
import {IStaticATokenLM} from "../src/interfaces/IStaticATokenLM.sol";
import {StaticATokenLMHarness} from "./harness/StaticATokenLMHarness.sol";
import {ITransparentProxyFactory} from
    "solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol";
import {IRewardsController} from "aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import {IPool} from "aave-address-book/AaveV3Ethereum.sol";
import {Constants} from "../scripts/seamless/Constants.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {TransparentUpgradeableProxy} from "solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol";
import {StaticATokenFactory} from "../src/StaticATokenFactory.sol";

contract SeamlessStaticATokenUpgradeTest is Test {
    IERC20 constant USDbC = IERC20(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA);
    IERC20 constant WETH = IERC20(0x4200000000000000000000000000000000000006);
    address constant esSEAM = 0x998e44232BEF4F8B033e5A5175BDC97F2B10d5e5;
    StaticATokenFactory constant staticATokenFactoryProxy = StaticATokenFactory(Constants.STATIC_ATOKEN_FACTORY);

    IPool pool;
    StaticATokenLMHarness staticATokenImplementation;
    StaticATokenFactory staticATokenFactoryImplementation;

    address[] staticATokens;

    address user = makeAddr("user");

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("base"), 25798489);

        pool = IPool(IPoolAddressesProvider(Constants.POOL_ADDRESSES_PROVIDER).getPool());

        staticATokenImplementation = new StaticATokenLMHarness(pool, IRewardsController(Constants.REWARDS_CONTROLLER));

        staticATokenFactoryImplementation = new StaticATokenFactory(
            pool,
            Constants.TIMELOCK_SHORT,
            ITransparentProxyFactory(Constants.TRANSPARENT_PROXY_FACTORY),
            address(staticATokenImplementation)
        );

        staticATokens = staticATokenFactoryProxy.getStaticATokens();
    }

    function test_initializeV2() public {
        _upgradeAll();

        address[] memory tokens = staticATokenFactoryProxy.getStaticATokens();

        for (uint256 i = 0; i < tokens.length; i++) {
            address[] memory rewardTokens = StaticATokenLM(tokens[i]).rewardTokens();

            for (uint256 j = 0; j < rewardTokens.length; j++) {
                IStaticATokenLM.RewardIndexCache memory startIndex =
                    StaticATokenLMHarness(tokens[i]).exposed__startIndex(rewardTokens[j]);
                assertEq(startIndex.lastUpdatedIndex, startIndex.lastUpdatedIndex_deprecated);
            }
        }
    }

    /// @dev OG Points reward index on USDbC is one example of index being too big. This is to test that is fixed with the upgrade
    function test_updateUserIndexTooBig(uint256 amount) public {
        StaticATokenLM statsUSDbC = StaticATokenLM(staticATokenFactoryProxy.getStaticAToken(address(USDbC)));

        // Bound is not correctly setting fuzz parameter limits, using assume works correctly though for some reason here. Maybe a foundry bug
        vm.assume(amount > 1 && amount < statsUSDbC.maxDeposit(address(0)));

        deal(address(USDbC), user, amount);

        vm.startPrank(user);

        USDbC.approve(address(statsUSDbC), amount);

        vm.expectRevert("SafeCast: value doesn't fit in 128 bits");
        statsUSDbC.deposit(amount, user, 0, true);

        vm.stopPrank();

        _upgradeAll();

        vm.prank(user);
        statsUSDbC.deposit(amount, user, 0, true);
    }

    function test_claimRewards(uint8 tokenSeed, uint256 amount, uint16 timeWarp) public {
        // Bound is not correctly setting fuzz parameter limits, using assume works correctly though for some reason here. Maybe a foundry bug
        vm.assume(tokenSeed < (staticATokens.length - 1));

        StaticATokenLMHarness randomStaticAToken = StaticATokenLMHarness(staticATokens[tokenSeed]);

        vm.assume(address(randomStaticAToken) != address(USDbC));
        vm.assume(amount > 1 && amount < randomStaticAToken.maxDeposit(address(0)));

        _upgradeAll();

        IERC20 underlyingAsset = IERC20(randomStaticAToken.asset());

        deal(address(underlyingAsset), user, amount);

        vm.startPrank(user);

        underlyingAsset.approve(address(randomStaticAToken), amount);
        randomStaticAToken.deposit(amount, user, 0, true);

        vm.stopPrank();

        // accrue rewards
        vm.warp(block.timestamp + timeWarp);

        address[] memory rewardTokens = randomStaticAToken.rewardTokens();

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            // esSEAM cannot be claimed from staticATokens since it is not transferable
            if (rewardTokens[i] == esSEAM) {
                continue;
            }

            address[] memory temp = new address[](1);
            temp[0] = rewardTokens[i];

            vm.prank(user);
            randomStaticAToken.claimRewardsToSelf(temp);

            IStaticATokenLM.UserRewardsData memory userRewardsData =
                randomStaticAToken.exposed__userRewardsData(user, rewardTokens[i]);

            assertEq(userRewardsData.unclaimedRewards, 0);

            if (randomStaticAToken.getClaimableRewards(user, rewardTokens[i]) > 0) {
                assertEq(
                    userRewardsData.rewardsIndexOnLastInteraction,
                    randomStaticAToken.getCurrentRewardsIndex(rewardTokens[i])
                );
            }

            assertNotEq(randomStaticAToken.getCurrentRewardsIndex(rewardTokens[i]), 0);
            assertEq(randomStaticAToken.getClaimableRewards(user, rewardTokens[i]), 0);
        }
    }

    function test_claimableRewardsUnchangedAfterUpgrade(uint256 amount, uint16 timeWarp) public {
        StaticATokenLM statsWETH = StaticATokenLM(staticATokenFactoryProxy.getStaticAToken(address(WETH)));

        // Bound is not correctly setting fuzz parameter limits, using assume works correctly though for some reason here. Maybe a foundry bug
        vm.assume(amount > 1 && amount < statsWETH.maxDeposit(address(0)));

        deal(address(WETH), user, amount);

        vm.startPrank(user);

        WETH.approve(address(statsWETH), amount);

        statsWETH.deposit(amount, user, 0, true);

        vm.stopPrank();

        // accrue rewards
        vm.warp(block.timestamp + timeWarp);

        address[] memory rewardTokens = statsWETH.rewardTokens();
        uint256[] memory claimableBefore = new uint256[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            claimableBefore[i] = statsWETH.getClaimableRewards(user, rewardTokens[i]);
        }

        _upgradeAll();

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            assertEq(statsWETH.getClaimableRewards(user, rewardTokens[i]), claimableBefore[i]);
        }
    }

    function test_upgrade() public {
        address prevTransparentProxyFactory = address(staticATokenFactoryProxy.TRANSPARENT_PROXY_FACTORY());
        address prevPool = address(staticATokenFactoryProxy.POOL());
        address prevAdmin = staticATokenFactoryProxy.ADMIN();
        address prevRewardsController =
            address(StaticATokenLM(staticATokenFactoryProxy.STATIC_A_TOKEN_IMPL()).INCENTIVES_CONTROLLER());

        _upgradeAll();

        vm.prank(Constants.TIMELOCK_SHORT);
        assertEq(
            TransparentUpgradeableProxy(payable(address(staticATokenFactoryProxy))).implementation(),
            address(staticATokenFactoryImplementation)
        );
        assertEq(address(staticATokenFactoryProxy.TRANSPARENT_PROXY_FACTORY()), prevTransparentProxyFactory);
        assertEq(address(staticATokenFactoryProxy.POOL()), prevPool);
        assertEq(staticATokenFactoryProxy.ADMIN(), prevAdmin);

        // check factory is updated
        assertEq(address(staticATokenImplementation), staticATokenFactoryProxy.STATIC_A_TOKEN_IMPL());
        // check all tokens are updated
        address[] memory tokens = staticATokenFactoryProxy.getStaticATokens();

        for (uint256 i = 0; i < tokens.length; i++) {
            vm.prank(Constants.TIMELOCK_SHORT);
            assertEq(
                TransparentUpgradeableProxy(payable(tokens[i])).implementation(), address(staticATokenImplementation)
            );
            assertEq(address(StaticATokenLM(tokens[i]).POOL()), prevPool);
            assertEq(address(StaticATokenLM(tokens[i]).INCENTIVES_CONTROLLER()), prevRewardsController);
        }
    }

    function _upgradeAll() public {
        address[] memory tokens = staticATokenFactoryProxy.getStaticATokens();

        vm.startPrank(Constants.TIMELOCK_SHORT);

        for (uint256 i = 0; i < tokens.length; i++) {
            TransparentUpgradeableProxy(payable(tokens[i])).upgradeToAndCall(
                address(staticATokenImplementation), abi.encodeWithSelector(StaticATokenLM.initializeV2.selector)
            );
        }
        TransparentUpgradeableProxy(payable(address(staticATokenFactoryProxy))).upgradeTo(
            address(staticATokenFactoryImplementation)
        );

        vm.stopPrank();
    }
}
