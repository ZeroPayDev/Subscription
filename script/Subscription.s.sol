// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ZeroPaySubscription} from "../src/Subscription.sol";

contract SubscriptionScript is Script {
    ZeroPaySubscription public subscription;

    // Default deployment parameters
    uint256 public constant DEFAULT_COMMISSION_RATE = 5; // 5%
    uint256 public constant DEFAULT_COMMISSION_MIN = 1e18; // 1 token
    uint256 public constant DEFAULT_COMMISSION_MAX = 100e18; // 100 tokens

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initialOwner = vm.envOr("INITIAL_OWNER", vm.addr(deployerPrivateKey));
        uint256 commissionRate = vm.envOr("COMMISSION_RATE", DEFAULT_COMMISSION_RATE);
        uint256 commissionMin = vm.envOr("COMMISSION_MIN", DEFAULT_COMMISSION_MIN);
        uint256 commissionMax = vm.envOr("COMMISSION_MAX", DEFAULT_COMMISSION_MAX);

        vm.startBroadcast(deployerPrivateKey);

        subscription = new ZeroPaySubscription(initialOwner, commissionRate, commissionMin, commissionMax);

        console.log("ZeroPaySubscription deployed at:", address(subscription));
        console.log("Initial Owner:", initialOwner);
        console.log("Commission Rate:", commissionRate, "%");
        console.log("Commission Min:", commissionMin);
        console.log("Commission Max:", commissionMax);

        vm.stopBroadcast();
    }
}
