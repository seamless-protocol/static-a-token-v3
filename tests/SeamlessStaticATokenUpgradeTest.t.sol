// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {DeployUpgrade} from "../scripts/DeployUpgrade.s.sol";
import {StaticATokenLM} from "../src/StaticATokenLM.sol";
import {ITransparentProxyFactory} from
    "solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol";
import {IRewardsController} from "aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import {IPool} from "aave-address-book/AaveV3Ethereum.sol";
import {Constants} from "../scripts/seamless/Constants.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {TransparentUpgradeableProxy} from "solidity-utils/contracts/transparent-proxy/TransparentUpgradeableProxy.sol";
import {StaticATokenFactory} from "../src/StaticATokenFactory.sol";

contract SeamlessStaticATokenUpgradeTest is Test {
    StaticATokenFactory staticATokenFactoryProxy = StaticATokenFactory(Constants.STATIC_ATOKEN_FACTORY);
    IPool pool;
    StaticATokenLM staticATokenImplementation;
    StaticATokenFactory staticATokenFactoryImplementation;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("base"), 25798489);

        pool = IPool(IPoolAddressesProvider(Constants.POOL_ADDRESSES_PROVIDER).getPool());

        staticATokenImplementation = new StaticATokenLM(pool, IRewardsController(Constants.REWARDS_CONTROLLER));

        staticATokenFactoryImplementation = new StaticATokenFactory(
            pool,
            Constants.TIMELOCK_SHORT,
            ITransparentProxyFactory(Constants.TRANSPARENT_PROXY_FACTORY),
            address(staticATokenImplementation)
        );
    }

    function test_upgrade() external {
        _upgradeAll();

        vm.prank(Constants.TIMELOCK_SHORT);
        assertEq(
            TransparentUpgradeableProxy(payable(address(staticATokenFactoryProxy))).implementation(),
            address(staticATokenFactoryImplementation)
        );

        // check factory is updated
        assertEq(address(staticATokenImplementation), staticATokenFactoryProxy.STATIC_A_TOKEN_IMPL());
        // check all tokens are updated
        address[] memory tokens = staticATokenFactoryProxy.getStaticATokens();

        for (uint256 i = 0; i < tokens.length; i++) {
            vm.prank(Constants.TIMELOCK_SHORT);
            assertEq(
                TransparentUpgradeableProxy(payable(tokens[i])).implementation(), address(staticATokenImplementation)
            );
        }
    }

    function test_validateDomainSeparator() public {
        _upgradeAll();

        address[] memory staticATokens = staticATokenFactoryProxy.getStaticATokens();

        for (uint256 i = 0; i < staticATokens.length; i++) {
            bytes32 separator1 = StaticATokenLM(staticATokens[i]).DOMAIN_SEPARATOR();

            for (uint256 j = 0; j < staticATokens.length; j++) {
                if (i != j) {
                    bytes32 separator2 = StaticATokenLM(staticATokens[j]).DOMAIN_SEPARATOR();
                    assertNotEq(separator1, separator2, "DOMAIN_SEPARATOR_MUST_BE_UNIQUE");
                }
            }
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
