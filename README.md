# ZeroPay Subscription

A decentralized subscription payment system built on Ethereum that enables merchants to create subscription plans and receive recurring payments in ERC20 tokens.

## Features

- **Merchant Management**: Merchants can register and configure accepted payment tokens
- **Subscription Plans**: Create flexible subscription plans with custom amounts and periods
- **Recurring Payments**: Automated recurring payment processing with commission handling
- **Multi-Token Support**: Accept multiple ERC20 tokens for subscriptions
- **Commission System**: Configurable commission rates with min/max limits
- **Subscription Control**: Users can start and cancel subscriptions at any time

## Architecture

### Core Components

- **ZeroPaySubscription**: Main contract handling subscription logic
- **Merchant**: Stores merchant information and accepted tokens
- **Plan**: Subscription plan with amount, period, and merchant info
- **Subscription**: Active subscription with payment details and next claim time

### Commission Model

The contract implements a flexible commission system:
- Commission rate (percentage)
- Minimum commission amount
- Maximum commission amount

## Installation

This project uses [Foundry](https://book.getfoundry.sh/).

```bash
forge install
```

## Testing

Run the comprehensive test suite:

```bash
forge test
```

Run tests with verbosity:

```bash
forge test -vvv
```

Run specific test:

```bash
forge test --match-test testCreateSubscription
```

## Deployment

### Environment Setup

Create a `.env` file with the following variables:

```bash
PRIVATE_KEY=your_private_key
INITIAL_OWNER=0x...  # Optional, defaults to deployer address
COMMISSION_RATE=5  # Optional, default 5%
COMMISSION_MIN=1000000000000000000  # Optional, default 1 token (18 decimals)
COMMISSION_MAX=100000000000000000000  # Optional, default 100 tokens (18 decimals)
RPC_URL=your_rpc_url
```

### Deploy to Network

```bash
source .env
forge script script/Subscription.s.sol:SubscriptionScript --rpc-url $RPC_URL --broadcast --verify
```

### Deploy to Local Network

Start Anvil:
```bash
anvil
```

Deploy:
```bash
forge script script/Subscription.s.sol:SubscriptionScript --rpc-url http://localhost:8545 --broadcast
```

## Usage

### For Merchants

1. **Register as Merchant**
   ```solidity
   subscription.merchant(receiverAddress);
   ```

2. **Configure Accepted Tokens**
   ```solidity
   address[] memory adds = [token1, token2];
   address[] memory dels = [];
   subscription.tokens(adds, dels);
   ```

3. **Create Subscription Plan**
   ```solidity
   subscription.plan(amount, period);
   ```

4. **Cancel Plan**
   ```solidity
   subscription.unplan(planId);
   ```

### For Customers

1. **Subscribe to Plan**
   ```solidity
   token.approve(subscriptionAddress, amount);
   subscription.subscripte(planId, customerAddress, tokenAddress);
   ```

2. **Cancel Subscription**
   ```solidity
   subscription.unsubscripte(subscriptionId);
   ```

### For Anyone

**Claim Subscription Payment** (after period expires):
```solidity
subscription.claim(subscriptionId);
```

### For Owner

**Claim Accumulated Fees**:
```solidity
address[] memory tokens = [token1, token2];
subscription.claimFee(tokens, payeeAddress);
```

## Contract Interface

### Events

- `PlanStarted(uint256 indexed id, address merchant, uint256 amount, uint256 period)`
- `PlanCanceled(uint256 indexed id)`
- `SubscriptionStarted(uint256 indexed id, uint256 plan, address customer, address payer, address token, uint256 nextTime)`
- `SubscriptionCanceled(uint256 indexed id)`
- `SubscriptionClaimed(uint256 indexed id)`

### Error Codes

- `M01`: Invalid receiver address (cannot be zero address) or merchant not registered
- `M02`: Unauthorized plan modification
- `M03`: Plan is not active
- `M04`: Token not supported by merchant
- `M05`: Subscription is not active
- `M06`: Too early to claim (period not elapsed)

## Development

### Build

```bash
forge build
```

### Format

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

## Security Considerations

- Uses OpenZeppelin's SafeERC20 for secure token transfers
- Ownable pattern for admin functions
- Input validation on all public functions
- Careful handling of commission calculations to prevent overflow

## License

MIT

## Foundry Documentation

For more information on Foundry:

https://book.getfoundry.sh/
