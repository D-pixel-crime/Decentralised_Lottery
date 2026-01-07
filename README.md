# Decetralised Lottery — Foundry Raffle Project

A decentralized, automated lottery smart contract built with **Solidity** and **Foundry**.
This project implements **Chainlink VRF** for provably fair randomness and **Chainlink Automation** for automated winner selection.

It features extensive **Fuzz Testing**, **Unit/Integration Testing**, and **Deployment Scripting**.

---

## 📜 Overview

`Raffle` is a smart contract that allows users to enter a lottery by paying an entrance fee. After a specific time interval, the contract automatically:
1.  **Closes** the lottery.
2.  **Selects** a random winner using a verifiable source of randomness.
3.  **Transfers** the entire balance of the contract to the winner.
4.  **Resets** for the next round.


---

## 📌 Key Features

* **Provably Fair:** Uses Chainlink VRF so the random number cannot be manipulated by miners or the developer.
* **Fully Automated:** Uses Chainlink Automation; the developer does not need to manually trigger the draw.
* **Robust Testing:**
* **Unit Tests:** Checks state changes, reverts, and modifiers.
* **Fuzz Testing:** `test_raffleEntrySuccessAndEmitsFuzzTesting` *and many other tests* ensures the contract handles edge values correctly.
* **Integration Tests:** Validates the interaction between the contract, the VRF Mock, and the upkeep logic.


* **Gas Efficient:** Custom errors and optimized state checks.
---

## 🔄 Lottery Logic Flow


```mermaid
flowchart TD
    User[Participant] -->|Enter with ETH| Raffle[Raffle Contract]
    Check[Chainlink Automation] -->|Check Upkeep (Time Passed?)| Raffle
    Raffle -->|Perform Upkeep (Request Randomness)| VRF[Chainlink VRF Coordinator]
    VRF -->|Fulfill Random Words| Raffle
    Raffle -->|Pick Winner & Send Balance| Winner[Winner Address]
    Raffle -->|Reset| Raffle

```

---

## 🛠 Tech Stack

* **Language:** Solidity `^0.8.0`
* **Framework:** [Foundry](https://getfoundry.sh/)
* **Libraries:**
    * `forge-std` — Foundry standard library
    * `chainlink-brownie-contracts` — Chainlink interfaces
    * `solmate` — Gas optimized building blocks


* **Chainlink Services:**
    * **VRF v2.5** (Verifiable Random Function) — For selecting a random winner.
    * **Automation (Keepers)** — For triggering the lottery draw automatically based on time.



---

## 📂 Project Structure

Based on the provided file structure:

```text
.
├── script/
│   ├── DeployRaffle.s.sol          # Deployment script
│   └── HelperConfig.s.sol          # Network configuration (Sepolia/Anvil/Mainnet)
│
├── src/
│   └── Raffle.sol                  # Main Lottery Smart Contract
│
├── test/
│   ├── integration/
│   │   └── IntegrationTestsRaffle.t.sol # Full lottery cycle tests
│   ├── mocks/
│   │   └── LinkToken.sol           # Mock Link token for local testing
│   └── unit/
│       └── UnitTestsRaffle.t.sol   # Unit tests with Fuzzing
│
├── foundry.toml                    # Foundry configuration
└── Makefile                        # Shortcuts for scripts

```

---

## ⚙️ Installation

1. **Clone the repository**
```bash
git clone https://github.com/D-pixel-crime/Decentralised_Lottery.git
cd decentralized-lottery

```


2. **Install Foundry** (if not already installed)
```bash
curl -L [https://foundry.paradigm.xyz](https://foundry.paradigm.xyz) | bash
foundryup

```


3. **Install dependencies**
```bash
forge install

```


4. **Create `.env` file**
```env
SEPOLIA_RPC_URL="your-sepolia-rpc-url"
PRIVATE_KEY="your-private-key"
ETHERSCAN_API_KEY="your-etherscan-api-key"
MAINNET_RPC_URL="your-mainnet-rpc-url"

```



---

## 🧪 Running Tests

This project uses `Makefile` shortcuts for ease of use.

### Unit Tests (Local)

Runs unit tests including **Fuzz tests** (checking thousands of inputs) on a local Anvil chain with Mocks.

```bash
forge test
# or
make test

```

### Integration Tests

Simulates a full lottery cycle: Enter $\rightarrow$ Time Travel $\rightarrow$ Trigger Automation $\rightarrow$ Mock VRF Response $\rightarrow$ Check Winner.

```bash
forge test --mt test_fullRaffleCycleFuzzyTesting

```

### Test Coverage

To see how much of the contract is tested:

```bash
forge coverage

```

---

## 🚀 Deployment *(Refer to the Makefile for more options)*

### Deploy to Local Anvil Chain

1. Start a local node in a separate terminal:
```bash
anvil

```


2. Deploy using the script:
```bash
forge script script/DeployRaffle.s.sol --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key <ANVIL_PRIVATE_KEY> --broadcast

```



### Deploy to Sepolia Testnet

Using the `Makefile` (ensure your `.env` is configured):

```bash
make deploy-sepolia

```

Or manually via Forge:

```bash
forge script script/DeployRaffle.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

```

---

## 📜 License

This project is licensed under the MIT License.
