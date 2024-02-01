// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import {SimpleDAISystem} from "src/SimpleDAISystem.sol";

contract SimpleDAISystemScript is Script {
    function setUp() public {}
    function run() public {
        vm.startBroadcast();

        SimpleDAISystem simpleDai = new SimpleDAISystem(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        vm.stopBroadcast();
    }
}