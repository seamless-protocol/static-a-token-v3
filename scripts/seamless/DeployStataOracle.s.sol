// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Script, console} from "forge-std/Script.sol";
import {Constants} from "./Constants.sol";
import {StataOracle} from '../../src/StataOracle.sol';

contract DeployStataOracle is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        StataOracle stataOracle = new StataOracle(Constants.POOL_ADDRESSES_PROVIDER);

        console.log("StataOracle deployed: ", address(stataOracle));

        vm.stopBroadcast();
    }
}