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
        uint256 plan;
        address payer;
        address customer;
        address token;
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
    event SubscriptionStarted(uint256 indexed id, uint256 plan, address customer, address payer, address token, uint256 nextTime);

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
     * @param _amount The amount of the new plan
     * @param _period The period seconds of the new plan
     */
    function plan(uint256 _amount, uint256 _period) external {
        Merchant storage m = merchants[msg.sender];
        require(m.receiver != address(0), "M01");

        planId += 1;

        Plan storage p = plans[planId];
        p.merchant = msg.sender;
        p.amount = _amount;
        p.period = _period;
        p.isActived = true;

        emit PlanStarted(planId, msg.sender, _amount, _period);
    }

    /**
     * @dev Cancel the plan from merchant
     * @param id The id of the plan
     */
    function unplan(uint256 id) external {
        Plan storage p = plans[id];
        require(p.merchant != msg.sender, "M02");

        p.isActived = false;

        emit PlanCanceled(id);
    }

    /**
     * @dev Create new subscription for customer
     * @param _plan The plan id of the new subscription
     * @param _customer The customer address of the new subscription
     * @param _token The payment token of the new subscription
     */
    function subscripte(uint256 _plan, address _customer, address _token) external {
        Plan storage p = plans[_plan];
        require(p.isActived, "M03");
        Merchant storage m = merchants[p.merchant];
        require(m.tokens[_token], "M04");

        subscriptionId += 1;
        uint256 nextTime = block.timestamp + p.period; // because first transfer
        Subscription storage s = subscriptions[subscriptionId];
        s.plan = _plan;
        s.payer = msg.sender;
        s.customer = _customer;
        s.token = _token;
        s.nextTime = nextTime;
        s.isActived = true;

        // do first transfer
        uint256 fee = commission(p.amount);
        fees[s.token] += fee;
        IERC20(s.token).safeTransfer(s.payer, p.amount);
        IERC20(s.token).safeTransfer(m.receiver, p.amount - fee);

        emit SubscriptionStarted(subscriptionId, _plan, _customer, msg.sender, _token, nextTime);
    }

    /**
     * @dev Cancel the subscription from customer
     * @param id The id of the subscription
     */
    function unsubscripte(uint256 id) external {
        Subscription storage s = subscriptions[id];
        require(s.isActived, "M05");

        s.isActived = false;

        emit SubscriptionCanceled(id);
    }

    /**
     * @dev Claim new period amount of a subscription
     * @param id The id of the subscription
     */
    function claim(uint256 id) external {
        Subscription storage s = subscriptions[id];
        require(s.isActived, "M05");
        require(block.timestamp >= s.nextTime, "M06");

        Plan storage p = plans[s.plan];
        Merchant storage m = merchants[p.merchant];

        s.nextTime = s.nextTime + p.period;

        // do transfer
        uint256 fee = commission(p.amount);
        fees[s.token] += fee;
        IERC20(s.token).safeTransfer(s.payer, p.amount);
        IERC20(s.token).safeTransfer(m.receiver, p.amount - fee);

        emit SubscriptionClaimed(id);

    }

    /**
     * @dev Calculate the commission of the pay
     * @param amount The amount of the pay
     * @return The commission fee of the pay
     */
    function commission(uint256 amount) public view returns (uint256) {
        uint256 comm = amount * commissionRate / 100;
        if (comm < commissionMin) {
            return commissionMin;
        }

        if (comm > commissionMax) {
            return commissionMax;
        }

        return comm;
    }

    /**
     * @dev Claim all the fee of the tokens for owner
     * @param _tokens The token address
     * @param _payee The receiver account
     */
    function claimFee(address[] memory _tokens, address _payee) external onlyOwner {
        for (uint i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            IERC20(token).safeTransfer(_payee, fees[token]);
        }
    }
}
