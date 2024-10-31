# MAAT Finance

### What is MAAT?

MAAT is a chain-agnostic meta-yield aggregator, built with Stargate V2 and LayerZero V2 technologies. MAAT autonomously manages the user's portfolio, providing the best possible APY on the market. 
The current product is in the MVP stage and we are planning to further increase APYs with new features in the upcoming versions.

### How does MAAT work?

MAAT aggregates yield from various protocols, such as AAVE, Harvest, Stargate, Yearn, etc. Users don't have to manually search for the most profitable strategy, as MAAT enables autonomous portfolio management with 30+ built-in yield strategies across 8+ chains. Additionally, funds are automatically rebalanced according to market conditions, ensuring that users benefit from optimal returns at all times.

## Documentation

TBA

![MaatVaultV1 Class Diagram](./assets/MaatVaultV1.svg)
*MaatVaultV1 - Class Diagram*
## Usage

#### Instal Dependencies
Install required NPM packages
```shell
npm install
```

Install required git submodules recursively
```shell
git submodule update --recursive
```

#### Build

```shell
forge build
```

#### Test

```shell
forge test
```

#### Deploy
This repo contains no production deployment script, it's moved to separate repo `maat-v1-deployment`.