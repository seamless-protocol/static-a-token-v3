// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';
import {StaticATokenLM} from "../../src/StaticATokenLM.sol";

contract StaticATokenLMHarness is StaticATokenLM {
    constructor(IPool pool, IRewardsController rewardsController) StaticATokenLM(pool, rewardsController) {}

    function exposed__startIndex(address rewardToken) external view returns (RewardIndexCache memory) {
        return _startIndex[rewardToken];
    }

    function exposed__userRewardsData(address user, address reward) external view returns (UserRewardsData memory) {
        return _userRewardsData[user][reward];
    }
}
