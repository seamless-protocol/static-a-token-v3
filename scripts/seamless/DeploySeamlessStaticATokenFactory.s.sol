// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Script, console} from "forge-std/Script.sol";
import {DeployATokenFactory} from '../Deploy.s.sol';
import {ITransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol';
import {IRewardsController} from 'aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol';
import {IPool} from 'aave-address-book/AaveV3Ethereum.sol';
import {Constants} from "./Constants.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {StaticATokenFactory} from '../../src/StaticATokenFactory.sol';

contract DeploySeamlessStaticATokenFactory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        StaticATokenFactory staticATokenFactory = DeployATokenFactory._deploy(
          ITransparentProxyFactory(Constants.TRANSPARENT_PROXY_FACTORY),
          Constants.TIMELOCK_SHORT,
          IPool(IPoolAddressesProvider(Constants.POOL_ADDRESSES_PROVIDER).getPool()),
          IRewardsController(Constants.REWARDS_CONTROLLER)
        );

        console.log("StaticATokenFactory deployed: ", address(staticATokenFactory));

        vm.stopBroadcast();
    }
}