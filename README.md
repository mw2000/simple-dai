# SimpleDAISystem Contract

## Overview
The `SimpleDAISystem` contract is a simplified version of a decentralized finance (DeFi) system, resembling platforms like MakerDAO. It allows users to deposit Ethereum (ETH) as collateral to generate a Dai-like stablecoin (referred to as Dai in this document). The system utilizes Chainlink Oracles for accurate ETH/USD price feeds, ensuring that the system's operations are based on current market data.

## Features
- **ETH Collateralization**: Users can lock ETH as collateral to mint Dai.
- **Dai Generation**: Based on the ETH deposited, users can generate an equivalent amount of Dai as per the current ETH/USD price.
- **Liquidation**: If the collateral's value falls below a certain threshold, the system allows for liquidation of the collateral to ensure the system's stability.
- **Withdrawal**: Users can withdraw their ETH collateral, partially or fully, as long as their vault remains above the minimum required collateralization ratio.
- **Dai Repayment**: Users can pay back the generated Dai to reduce their debt in the system.

## Key Helper Contracts
- **`AggregatorV3Interface`**: An interface to interact with Chainlink price feeds.
- **`MockV3Aggregator`**: A mock contract for simulating Chainlink price feed behavior in testing environments.

## Contract Mechanics
### Deposit Vault
Users deposit ETH into the system, which is then locked as collateral. The contract checks if the vault (the user's account) stays above the minimum collateralization ratio before allowing Dai generation.

### Dai Generation
Upon depositing ETH, users can generate a Dai amount equivalent to the value of the deposited ETH. The current ETH/USD price feed is used to determine the equivalent Dai amount.

### Liquidation
If a user’s collateral value falls below a certain threshold (150% collateralization ratio), the system allows for liquidation. During liquidation, the collateral can be partially or fully seized to cover the outstanding debt, ensuring the system's stability.

### Withdrawal
Users can withdraw their ETH collateral, provided their vault remains above the minimum required collateralization ratio.

### Dai Repayment
Users can repay their Dai debt at any time. The repayment reduces the outstanding debt in the user's vault.

### Stability Fee
An interest rate charged over time on generated Dai. This is a crucial feature for a realistic DeFi lending platform as it accounts for the risk and provides an incentive mechanism for the system.

## Current Limitations and Future Improvements
- **Governance and Upgradability**: The contract does not currently include governance features for parameters like the collateralization ratio, stability fee rates, and other critical system settings. Implementing governance mechanisms would allow for a more decentralized and adaptable system.

## Testing
The contract includes a comprehensive test suite using Foundry, ensuring the contract functions as expected under various scenarios. The `MockV3Aggregator` contract is used to simulate Chainlink price feeds, allowing for controlled testing environments.


## Foundry Commands

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```
