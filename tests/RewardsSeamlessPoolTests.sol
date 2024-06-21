// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {AToken} from 'aave-v3-core/contracts/protocol/tokenization/AToken.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveV3Avalanche, IPool, AaveV3AvalancheAssets} from 'aave-address-book/AaveV3Avalanche.sol';
import {DataTypes, ReserveConfiguration} from 'aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {StaticATokenLM, IERC20, IERC20Metadata, ERC20} from '../src/StaticATokenLM.sol';
import {RayMathExplicitRounding, Rounding} from '../src/RayMathExplicitRounding.sol';
import {IStaticATokenLM} from '../src/interfaces/IStaticATokenLM.sol';
import {SigUtils} from './SigUtils.sol';
import {BaseTest} from './TestBase.sol';
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';

contract RewardsSeamlessPoolTests is BaseTest {
  using RayMathExplicitRounding for uint256;

  address public constant override UNDERLYING = 0x4200000000000000000000000000000000000006; // WETH
  address public constant override A_TOKEN = 0x48bf8fCd44e2977c8a9A744658431A8e6C0d866c; // sWETH
  address public constant EMISSION_ADMIN = 0x6e081F9ebb2B2f07C2f771074EBB32dDac141d14;
  address public constant REWARD_TOKEN = 0x1C7a460413dD4e964f96D8dFC56E7223cE88CD85; // SEAM;

  // Seamless addresses provider
  IPoolAddressesProvider constant POOL_ADDRESSES_PROVIDER =
        IPoolAddressesProvider(0x0E02EB705be325407707662C6f6d3466E939f3a0);

  IRewardsController constant REWARDS_CONTROLLER = IRewardsController(0x91Ac2FfF8CBeF5859eAA6DdA661feBd533cD3780);

  IPool public override pool; 

  address[] rewardTokens;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('base'), 15709500);

    pool = IPool(POOL_ADDRESSES_PROVIDER.getPool());

    rewardTokens.push(REWARD_TOKEN);

    super.setUp();
  }

  /// @dev fuzz test confirming that user has the same rewards in the pool as in a staticAToken 
  /// for the same amount deposited
  function test_rewardsSameInPool(address user, uint256 amount, uint256 skipBlocks) public {
    vm.stopPrank();

    vm.assume(user != address(0));
    amount = bound(amount, 0.1 ether, 10 ether);
    skipBlocks = bound(skipBlocks, 1, 10000); 

    vm.startPrank(user);
    // deposit to pool
    _fundUser(amount, user);
    _underlyingToAToken(amount, user);

    // deposit to statAToken
    _fundUser(amount, user);
    _depositAToken(amount, user);

    vm.stopPrank();

    _skipBlocks(uint128(skipBlocks));

    uint256 rewardsPool = _getPoolRewards(user);
    uint256 rewardsStatAToken = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN);

    assertApproxEqAbs(rewardsPool, rewardsStatAToken, 1);
  }

  /// @dev test confirming that existing user can deposit part of his aTokens to the StaticATokenLM 
  /// and continue to accrue rewards in both pool and staticAToken
  function test_existingUserHasBothRewards() public {
    address user = 0xdD6354A00c35dEBF1DCE94B08209664A3b7bBAAA;

    uint256 startBalance = IERC20(A_TOKEN).balanceOf(user);
    uint256 amountToDeposit = 1 ether;
    assertGt(startBalance, amountToDeposit);

    vm.startPrank(user);
    // claim existing accrued pool rewards so we start from 0
    _claimPoolRewards(user);

    IERC20(this.A_TOKEN()).approve(address(staticATokenLM), amountToDeposit);
    staticATokenLM.deposit(amountToDeposit, user, 10, false);
    vm.stopPrank();

    _skipBlocks(1000);

    uint256 rewardsPool = _getPoolRewards(user);
    uint256 rewardsStatAToken = staticATokenLM.getClaimableRewards(user, REWARD_TOKEN);

    assertGt(rewardsPool, 0);
    assertGt(rewardsStatAToken, 0);
    
    vm.startPrank(user);
    uint256 claimedPoolRewards = _claimPoolRewards(user);
    uint256 claimedStatATokenRewards = _claimStatATokenRewards(user);
    vm.stopPrank();

    assertEq(claimedPoolRewards, rewardsPool);
    assertEq(claimedStatATokenRewards, rewardsStatAToken);
  }

  function _getPoolRewards(address user) internal view returns(uint256) {
    address[] memory assets = new address[](1);
    assets[0] = A_TOKEN;
    return REWARDS_CONTROLLER.getUserRewards(assets, user, REWARD_TOKEN);
  }

  function _claimPoolRewards(address user) internal returns(uint256) {
    address[] memory assets = new address[](1);
    assets[0] = A_TOKEN;
    return REWARDS_CONTROLLER.claimRewards(assets, type(uint256).max, user, REWARD_TOKEN);
  }

  function _claimStatATokenRewards(address user) internal returns(uint256) {
    uint256 beforeBalance = IERC20(REWARD_TOKEN).balanceOf(user);
    staticATokenLM.claimRewards(user, rewardTokens);
    uint256 afterBalance = IERC20(REWARD_TOKEN).balanceOf(user);
    return afterBalance - beforeBalance;
  }
}
