// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {EscrowFactory} from "../src/EscrowFactory.sol";

contract EsFScript is Script {
    EscrowFactory public escrowFactory;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address accessTokenSepContract = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        escrowFactory = new EscrowFactory(7200, 7200, accessTokenSepContract);
        vm.stopBroadcast();
    }
}
