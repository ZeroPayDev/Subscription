// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ZeroPaySubscription} from "../src/Subscription.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract SubscriptionTest is Test {
    ZeroPaySubscription public subscription;
    ERC20Mock public token;

    address owner = address(1);
    address merchant = address(2);
    address receiver = address(3);
    address customer = address(4);
    address payer = address(5);

    uint256 commissionRate = 5; // 5%
    uint256 commissionMin = 1e18; // 1 token
    uint256 commissionMax = 100e18; // 100 tokens

    uint256 planAmount = 50e18; // 50 tokens
    uint256 planPeriod = 30 days;

    event PlanStarted(uint256 indexed id, address merchant, uint256 amount, uint256 period);
    event PlanCanceled(uint256 indexed id);
    event SubscriptionStarted(uint256 indexed id, uint256 plan, address customer, address payer, address token, uint256 nextTime);
    event SubscriptionCanceled(uint256 indexed id);
    event SubscriptionClaimed(uint256 indexed id);

    function setUp() public {
        subscription = new ZeroPaySubscription(owner, commissionRate, commissionMin, commissionMax);
        token = new ERC20Mock();

        // Setup merchant
        vm.prank(merchant);
        subscription.merchant(receiver);

        address[] memory adds = new address[](1);
        adds[0] = address(token);
        address[] memory dels = new address[](0);

        vm.prank(merchant);
        subscription.tokens(adds, dels);

        // Mint tokens to payer
        token.mint(payer, 10000e18);

        vm.prank(payer);
        token.approve(address(subscription), type(uint256).max);
    }

    function testConstructor() public view {
        assertEq(subscription.owner(), owner);
    }

    function testMerchantSetup() public {
        address newMerchant = address(6);
        address newReceiver = address(7);

        vm.prank(newMerchant);
        subscription.merchant(newReceiver);

        (address merchantReceiver) = subscription.merchants(newMerchant);
        assertEq(merchantReceiver, newReceiver);
    }

    function testMerchantSetupRevertsZeroAddress() public {
        vm.expectRevert(bytes("M01"));
        vm.prank(merchant);
        subscription.merchant(address(0));
    }

    function testAddTokens() public {
        address newMerchant = address(8);
        address newReceiver = address(9);

        vm.prank(newMerchant);
        subscription.merchant(newReceiver);

        address[] memory adds = new address[](2);
        adds[0] = address(0x123);
        adds[1] = address(0x456);
        address[] memory dels = new address[](0);

        vm.prank(newMerchant);
        subscription.tokens(adds, dels);
    }

    function testRemoveTokens() public {
        address[] memory adds = new address[](1);
        adds[0] = address(0x789);
        address[] memory dels = new address[](0);

        vm.prank(merchant);
        subscription.tokens(adds, dels);

        // Now remove it
        address[] memory adds2 = new address[](0);
        address[] memory dels2 = new address[](1);
        dels2[0] = address(0x789);

        vm.prank(merchant);
        subscription.tokens(adds2, dels2);
    }

    function testCreatePlan() public {
        vm.expectEmit(true, false, false, true);
        emit PlanStarted(1, merchant, planAmount, planPeriod);

        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        (address planMerchant, uint256 amount, uint256 period, bool isActived) = subscription.plans(1);
        assertEq(planMerchant, merchant);
        assertEq(amount, planAmount);
        assertEq(period, planPeriod);
        assertTrue(isActived);
    }

    function testCreatePlanRevertsNoMerchant() public {
        address newMerchant = address(10);

        vm.expectRevert(bytes("M01"));
        vm.prank(newMerchant);
        subscription.plan(planAmount, planPeriod);
    }

    function testCancelPlan() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        vm.expectEmit(true, false, false, false);
        emit PlanCanceled(1);

        vm.prank(merchant);
        subscription.unplan(1);

        (,, , bool isActived) = subscription.plans(1);
        assertFalse(isActived);
    }

    function testCreateSubscription() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        uint256 payerBalanceBefore = token.balanceOf(payer);
        uint256 receiverBalanceBefore = token.balanceOf(receiver);

        uint256 expectedNextTime = block.timestamp + planPeriod;

        vm.expectEmit(true, false, false, true);
        emit SubscriptionStarted(1, 1, customer, payer, address(token), expectedNextTime);

        vm.prank(payer);
        subscription.subscribe(1, customer, address(token));

        (uint256 plan, address subPayer, address subCustomer, address subToken, uint256 nextTime, bool isActived) =
            subscription.subscriptions(1);

        assertEq(plan, 1);
        assertEq(subPayer, payer);
        assertEq(subCustomer, customer);
        assertEq(subToken, address(token));
        assertEq(nextTime, expectedNextTime);
        assertTrue(isActived);

        // Check balances - first payment should have been made
        uint256 fee = subscription.commission(planAmount);
        assertEq(token.balanceOf(payer), payerBalanceBefore - planAmount);
        assertEq(token.balanceOf(receiver), receiverBalanceBefore + planAmount - fee);
    }

    function testCreateSubscriptionRevertsInactivePlan() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        vm.prank(merchant);
        subscription.unplan(1);

        vm.expectRevert(bytes("M03"));
        vm.prank(payer);
        subscription.subscribe(1, customer, address(token));
    }

    function testCreateSubscriptionRevertsUnsupportedToken() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        ERC20Mock unsupportedToken = new ERC20Mock();

        vm.expectRevert(bytes("M04"));
        vm.prank(payer);
        subscription.subscribe(1, customer, address(unsupportedToken));
    }

    function testCancelSubscription() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        vm.prank(payer);
        subscription.subscribe(1, customer, address(token));

        vm.expectEmit(true, false, false, false);
        emit SubscriptionCanceled(1);

        vm.prank(payer);
        subscription.unsubscribe(1);

        (,,,,, bool isActived) = subscription.subscriptions(1);
        assertFalse(isActived);
    }

    function testClaimSubscription() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        vm.prank(payer);
        subscription.subscribe(1, customer, address(token));

        uint256 payerBalanceBefore = token.balanceOf(payer);
        uint256 receiverBalanceBefore = token.balanceOf(receiver);

        // Fast forward time
        vm.warp(block.timestamp + planPeriod);

        vm.expectEmit(true, false, false, false);
        emit SubscriptionClaimed(1);

        subscription.claim(1);

        // Check balances - second payment should have been made
        uint256 fee = subscription.commission(planAmount);
        assertEq(token.balanceOf(payer), payerBalanceBefore - planAmount);
        assertEq(token.balanceOf(receiver), receiverBalanceBefore + planAmount - fee);

        // Check nextTime updated
        (,,,, uint256 nextTime,) = subscription.subscriptions(1);
        assertEq(nextTime, block.timestamp + planPeriod);
    }

    function testClaimSubscriptionRevertsTooEarly() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        vm.prank(payer);
        subscription.subscribe(1, customer, address(token));

        // Try to claim immediately
        vm.expectRevert(bytes("M06"));
        subscription.claim(1);
    }

    function testClaimSubscriptionRevertsInactive() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        vm.prank(payer);
        subscription.subscribe(1, customer, address(token));

        vm.prank(payer);
        subscription.unsubscribe(1);

        vm.warp(block.timestamp + planPeriod);

        vm.expectRevert(bytes("M05"));
        subscription.claim(1);
    }

    function testCommissionCalculation() public view {
        // Test normal case: 5% of 50 = 2.5 tokens
        uint256 comm1 = subscription.commission(50e18);
        assertEq(comm1, 2.5e18);

        // Test minimum: 5% of 10 = 0.5, should return min 1 token
        uint256 comm2 = subscription.commission(10e18);
        assertEq(comm2, commissionMin);

        // Test maximum: 5% of 3000 = 150, should return max 100 tokens
        uint256 comm3 = subscription.commission(3000e18);
        assertEq(comm3, commissionMax);
    }

    function testClaimFee() public {
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        vm.prank(payer);
        subscription.subscribe(1, customer, address(token));

        uint256 expectedFee = subscription.commission(planAmount);

        address feeReceiver = address(11);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        vm.prank(owner);
        subscription.claimFee(tokens, feeReceiver);

        assertEq(token.balanceOf(feeReceiver), expectedFee);
    }

    function testClaimFeeOnlyOwner() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        vm.expectRevert();
        vm.prank(merchant);
        subscription.claimFee(tokens, merchant);
    }

    function testMultipleSubscriptions() public {
        // Create multiple plans
        vm.prank(merchant);
        subscription.plan(planAmount, planPeriod);

        vm.prank(merchant);
        subscription.plan(planAmount * 2, planPeriod * 2);

        // Create multiple subscriptions
        vm.prank(payer);
        subscription.subscribe(1, customer, address(token));

        address payer2 = address(12);
        token.mint(payer2, 10000e18);
        vm.prank(payer2);
        token.approve(address(subscription), type(uint256).max);

        vm.prank(payer2);
        subscription.subscribe(2, customer, address(token));

        // Verify both subscriptions exist
        (uint256 plan1,,,,, bool isActived1) = subscription.subscriptions(1);
        (uint256 plan2,,,,, bool isActived2) = subscription.subscriptions(2);

        assertEq(plan1, 1);
        assertEq(plan2, 2);
        assertTrue(isActived1);
        assertTrue(isActived2);
    }

    function testFuzzCommission(uint256 amount) public view {
        vm.assume(amount < type(uint256).max / 100);

        uint256 comm = subscription.commission(amount);
        uint256 expectedComm = amount * commissionRate / 100;

        if (expectedComm < commissionMin) {
            assertEq(comm, commissionMin);
        } else if (expectedComm > commissionMax) {
            assertEq(comm, commissionMax);
        } else {
            assertEq(comm, expectedComm);
        }
    }
}
