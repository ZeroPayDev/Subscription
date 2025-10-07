// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ZeroPaySubscription
 * @dev Handles subscrption plan and subscription logic and claim
 */
contract ZeroPaySubscription is Ownable {
    using SafeERC20 for IERC20;

    /// @dev Struct representing a merchant
    struct Merchant {
        address receiver;
        mapping(address => bool) tokens;
    }

    /// @dev Struct representing a plan
    struct Plan {
        address merchant;
        uint256 amount;
        uint256 period;
        bool isActived;
    }

    /// @dev Struct representing a plan
    struct Subscription {
        address plan;
        address payer;
        address customer;
        address token;
        uint256 times;
        uint256 nextTime;
        bool isActived;
    }

    /// @dev Commmission rate of the pay
    uint256 private commissionRate;

    /// @dev Commmission minimum of the pay
    uint256 private commissionMin;

    /// @dev Commmission maximum of the pay
    uint256 private commissionMax;

    /// @dev Counter for plan IDs
    uint256 private planId;

    /// @dev Counter for subscription IDs
    uint256 private subscriptionId;

    /// @dev Mapping of merchant address to merchant info
    mapping(address => Merchant) public merchants;

    /// @dev Mapping of session ID to subscription plan
    mapping(uint256 => Plan) public plans;

    /// @dev Mapping of session ID to subscription plan
    mapping(uint256 => Subscription) public subscriptions;

    /// @dev Mapping of token to amount
    mapping(address => uint256) fees;

    /// @dev Event emitted when a plan is started
    event PlanStarted(uint256 indexed id, address merchant, uint256 amount, uint256 period);

    /// @dev Event emitted when a plan is canceled
    event PlanCanceled(uint256 indexed id);

    /// @dev Event emitted when a subscription is started
    event SubscriptionStarted(uint256 indexed id, uint256 plan, address customer, address token, uint256 times, uint256 nextTime);

    /// @dev Event emitted when a subscription is canceled
    event SubscriptionCanceled(uint256 indexed id);

    /// @dev Event emitted when a subscriotion claimed
    event SubscriptionClaimed(uint256 indexed id);

    /**
     * @dev Constructor initializes the Subscription
     * @param _initialOwner The initial owner of the contract (typically governance)
     */
    constructor(address _initialOwner, uint256 _commissionRate, uint256 _commissionMin, uint256 _commissionMax) Ownable(_initialOwner) {
        commissionRate = _commissionRate;
        commissionMin = _commissionMin;
        commissionMax = _commissionMax;
    }

    /**
     * @dev Set the merchant info
     * @param receiver The address of the receiver token
     */
    function merchant(address receiver) external {
        require(receiver != address(0), "M01");

        merchants[msg.sender].receiver = receiver;
    }

    /**
     * @dev Add/del tokens in merchant info
     * @param adds The addresses of added tokens
     * @param dels The addresses of deleted tokens
     */
    function tokens(address[] memory adds, address[] memory dels) external {
        Merchant storage m = merchants[msg.sender];
        for (uint i = 0; i < adds.length; i++) {
            m.tokens[adds[i]] = true;
        }

        for (uint i = 0; i < dels.length; i++) {
            delete m.tokens[dels[i]];
        }
    }

    /**
     * @dev Create new plan for merchant
     * @param amount The amount of the new plan
     * @param period The period seconds of the new plan
     */
    function plan(uint256 amount, uint256 period) external {
        Merchant storage m = merchants[msg.sender];
        require(m.receiver != address(0), "M01");

        planId += 1;

        Plan storage p = plans[planId];
        p.merchant = msg.sender;
        p.amount = amount;
        p.period = period;
        p.isActived = true;

        emit PlanStarted(planId, msg.sender, amount, period);
    }

    function unplan(uint256 id) external {
        Plan storage p = plans[id];
        require(p.merchant != msg.sender, "M02");

        p.isActived = false;

        emit PlanCanceled(id);
    }

    function subscripte(address plan, address customer, address token, uint256 times) external {
        Plan storage p = plans[id];
        require(p.isActived, "M03");

        subscriptionId += 1;
        uint256 nextTime = block.timestamp + p.period; // because done first transfer
        Subscription storage s = subscriptions[subscriptionId];
        s.plan = plan;
        s.payer = msg.sender;
        s.customer = customer;
        s.token = token;
        s.times = times - 1;
        s.nextTime = nextTime;
        s.isActived = true;

        // do first transfer
        uint256 fee = commission(p.amount);
        fees[token] += fee;
        IERC20(token).safeTransfer(s.payer, p.amount - fee);

        emit SubscriotionStarted(subscriptionId, plan, customer, token, times, nextTime);
    }

    function unsubscripte(uint256 id) external {
        Subscription storage s = subscriptions[id];
        require(s.isActived, "M04");

        s.isActived = false;

        emit SubscriptionCanceled(id);
    }

    function claim(uint256 id) external {
        Subscription storage s = subscriptions[id];
        require(s.isActived, "M04");
        require(block.timestamp >= s.nextTime, "M05");

        Plan storage p = plans[id];
        s.nextTime = s.nextTime + p.peroid;
        s.times -= 1;

        // do transfer
        uint256 fee = commission(p.amount);
        fees[token] += fee;
        IERC20(token).safeTransfer(s.payer, p.amount - fee);

        emit SubscriptionClaimed(id);

    }

    function commission(uint256 amount) public returns (uint256) {
        uint256 comm = amount * commissionRate / 100;
        if (comm < commissionMin) {
            return commissionMin;
        }

        if (comm > commissionMax) {
            return commissionMax;
        }

        return comm;
    }

    function fee(address[] tokens, address payee) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            IERC20(token).safeTransfer(fees[token], payee);
        }
    }
}
