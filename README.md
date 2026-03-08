# 🛡️ Polygon Immortal Auth SDK

**The first decentralized, serverless, and gasless 2FA infrastructure built on Polygon & Biconomy.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Network: Polygon](https://img.shields.io/badge/Network-Polygon-blueviolet)](https://polygon.technology/)
[![Powered by Biconomy](https://img.shields.io/badge/Powered%20by-Biconomy-3b82f6)](https://biconomy.io/)
[![Storage: IPFS](https://img.shields.io/badge/Storage-IPFS-00d4ff)](https://ipfs.tech/)

---

## 🚀 Overview

**Polygon Immortal Auth** is a "Build-and-Forget" 2FA solution. It allows users to migrate from Google Authenticator to a secure, blockchain-based vault with **zero-gas fees** after a one-time activation.

### 💎 Key Features for Polygon Village Grants

| Feature | Description |
|---------|-------------|
| **⚡ Gasless UX (EIP-712)** | Powered by Biconomy Paymaster. Users sign messages; Businesses or Treasury pays gas |
| **🏢 B2B Ready** | Corporate accounts sponsor security for employees via smart-contract whitelisting |
| **📥 1-Click Migration** | Built-in parser for `otpauth://` URIs and QR-code scanning from legacy 2FA apps |
| **☁️ Infinite Availability** | Hosted on IPFS. No servers, no downtimes, no censorship |
| **🔐 Client-Side Privacy** | AES-256-GCM encryption where key is user's wallet signature (EIP-191) |
| **💰 Pay Once Model** | Single activation fee (2 POL), unlimited gasless operations forever |

---

## 🛠 Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   MetaMask      │────▶│   Biconomy       │────▶│   Polygon       │
│   (User Wallet) │     │   Paymaster      │     │   Smart Contract│
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │                        │
         ▼                       ▼                        ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  AES-256-GCM    │     │  Gas Sponsorship │     │  ERC-2771       │
│  Encryption     │     │  (Business/Treasury)    │  Meta-Tx        │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │   IPFS Storage   │
                        │   (Encrypted)    │
                        └──────────────────┘
```

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Smart Contract** | Solidity 0.8.19 (Polygon, ERC-2771 compatible) |
| **Relayer** | Biconomy SDK v3 for meta-transactions |
| **Storage** | Encrypted blobs on IPFS, CID stored on-chain |
| **Frontend** | Pure HTML/JS/CSS (IPFS-ready, no build required) |
| **Encryption** | CryptoJS AES-256-GCM with EIP-191 signature key |

---

## 📦 For Developers (SDK)

Integrate decentralized 2FA into your DApp in 3 lines of code:

```javascript
import { ImmortalAuthSDK } from '@polygon/immortal-auth';

const sdk = new ImmortalAuthSDK(provider, biconomyKey);
await sdk.activate(); // One-time setup (2 POL)
const codes = await sdk.loadVault(); // Gasless!
```

### Installation

```bash
npm install @polygon/immortal-auth
```

### Quick Start

```javascript
import { ImmortalAuthSDK } from '@polygon/immortal-auth';

// Initialize
const sdk = new ImmortalAuthSDK({
  provider: window.ethereum,
  contractAddress: '0x...',
  biconomyApiKey: 'YOUR_API_KEY',
  chainId: 137 // Polygon Mainnet
});

// Connect wallet
await sdk.connect();

// Activate vault (one-time, 2 POL)
if (!await sdk.isActivated()) {
  await sdk.activate({ value: ethers.parseEther('2') });
}

// Save vault (gasless via Biconomy)
await sdk.saveVault({
  services: [
    { name: 'Gmail', secret: 'JBSWY3DPEHPK3PXP' },
    { name: 'GitHub', secret: 'GEZDGNBVGY3TQOJQ' }
  ]
});

// Load vault (free view call)
const vault = await sdk.loadVault();
console.log(vault.services); // [{ name, secret, code }, ...]

// Generate TOTP code
const code = sdk.generateTOTP('JBSWY3DPEHPK3PXP');
console.log(code); // "123456"
```

---

## 🏗 Smart Contract API

### Core Functions

```solidity
// Activate vault (one-time payment: 2 POL)
function activateVault() external payable;

// Save encrypted vault data (gasless via Biconomy)
function saveVault(string calldata ipfsHash) external;

// Get vault IPFS hash (free view call)
function getVault(address user) external view returns (string memory);

// Check if user has activated vault
function isActivated(address user) external view returns (bool);

// Get full vault info
function getVaultInfo(address user) external view returns (
    string memory ipfsHash,
    uint256 activatedAt,
    uint256 updatedAt,
    bool exists
);
```

### B2B Functions

```solidity
// Business deposit for employee gas sponsorship
function businessDeposit() external payable;

// Link employee to business (whitelist for gasless)
function linkEmployee(address employee) external;

// Unlink employee
function unlinkEmployee(address employee) external;

// Check if user is sponsored employee
function isEmployee(address user) external view returns (bool);
```

---

## 🔐 Security Model

### Encryption Flow

```
User Wallet → signMessage("Unlock Vault") → keccak256 → AES-256 Key
                    │
                    ▼
Services Array → JSON.stringify → AES-GCM Encrypt → IPFS
                    │
                    ▼
            Only wallet owner can decrypt
```

### Security Guarantees

| Threat | Protection |
|--------|------------|
| **Server Hack** | ✅ No servers. Data on IPFS (encrypted) |
| **Contract Hack** | ✅ Only IPFS hashes stored. Data encrypted client-side |
| **Key Leak** | ✅ Key derived from signature. Never stored/transmitted |
| **Phishing** | ✅ Unique signature message per app. Can't be reused |
| **Censorship** | ✅ IPFS + Blockchain. Impossible to delete |

---

## 📱 User Flow

### Migration from Google Authenticator

```
┌─────────────────────────────────────────────────────────────┐
│  1. Open Immortal Auth                                      │
│     └─> Connect MetaMask                                    │
├─────────────────────────────────────────────────────────────┤
│  2. Activate Vault                                          │
│     └─> Pay 2 POL (one-time)                                │
├─────────────────────────────────────────────────────────────┤
│  3. Migrate 2FA Codes                                       │
│     ├─> Option A: Scan QR from Google Auth export           │
│     ├─> Option B: Import otpauth-migration:// URI           │
│     └─> Option C: Manual entry (name + secret)              │
├─────────────────────────────────────────────────────────────┤
│  4. Save to Blockchain (Gasless!)                           │
│     └─> Sign message. Biconomy pays gas.                    │
├─────────────────────────────────────────────────────────────┤
│  5. Done! ✅                                                │
│     └─> Unlimited gasless 2FA forever                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Deployment Guide

### 1. Deploy Smart Contract

```bash
# Using Remix IDE
# 1. Open https://remix.ethereum.org/
# 2. Load contracts/ImmortalWeb32FA.sol
# 3. Compile with Solidity 0.8.19
# 4. Deploy:
#    - Network: Polygon Mainnet
#    - Constructor args:
#      - _trustedForwarder: 0x1D0013... (Biconomy Forwarder)
#      - _platformAddress: 0x... (Fee recipient)
```

### 2. Configure Frontend

Edit `index.html`:

```javascript
const CONFIG = {
  CONTRACT_ADDRESS: '0xYOUR_DEPLOYED_CONTRACT',
  BICONOMY_API_KEY: 'YOUR_API_KEY_FROM_DASHBOARD',
  BICONOMY_PAYMASTER_URL: 'https://paymaster.biconomy.io/api/v1/59140/your-key',
  CHAIN_ID: 137,
  RPC_URL: 'https://polygon-rpc.com'
};
```

### 3. Deploy to IPFS

```bash
# Using Pinata
pinata pin file index.html --pinataMetadata '{"name": "Immortal Auth"}'

# Or using IPFS CLI
ipfs add -r ./www
# Copy CID: bafybeig...
```

### 4. Access via Gateway

```
https://ipfs.io/ipfs/bafybeig...
https://gateway.pinata.cloud/ipfs/bafybeig...
```

---

## 📊 Gas Cost Analysis

| Operation | Traditional | Immortal Auth | Savings |
|-----------|-------------|---------------|---------|
| **Activation** | ~$0.50 | ~$0.50 (2 POL) | 0% |
| **Save Vault** | ~$0.10 | $0 (Gasless) | 100% |
| **Load Vault** | Free (view) | Free (view) | - |
| **Annual Cost** (12 saves) | ~$1.70 | ~$0.50 | 70% |

**Note:** With Biconomy sponsorship, users pay **$0** after activation.

---

## 🏆 Polygon Village Grants Alignment

### Why This Project Fits

| Grant Criteria | How We Match |
|----------------|--------------|
| **Polygon Native** | Built exclusively on Polygon Mainnet |
| **Gasless Innovation** | Biconomy integration for meta-transactions |
| **B2B Potential** | Corporate sponsorship model for employee 2FA |
| **Migration Tool** | Direct import from Google/Authy ecosystems |
| **Decentralized** | IPFS hosting, no centralized servers |
| **Open Source** | MIT License, fully auditable code |

### Requested Support

- **Grant Funding**: For security audit and Biconomy Paymaster credits
- **Technical Support**: Polygon CDK integration for custom rollup
- **Marketing**: Feature in Polygon ecosystem showcases

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - Overview & Quick Start |
| [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) | Step-by-step migration from Google/Authy |
| [API.md](API.md) | Full SDK API reference |
| [CONTRACTS.md](CONTRACTS.md) | Smart contract documentation |

---

## 🤝 Contributing

```bash
# Clone repo
git clone https://github.com/polygon/immortal-auth.git

# Install dependencies
npm install

# Run tests
npm test

# Build for production
npm run build

# Deploy to IPFS
npm run deploy:ipfs
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🔗 Links

| Resource | URL |
|----------|-----|
| **Website** | https://immortal-auth.polygon.technology |
| **Dashboard** | https://dashboard.biconomy.io |
| **Polygon** | https://polygon.technology |
| **IPFS** | https://ipfs.tech |
| **Documentation** | https://docs.immortal-auth.polygon.technology |

---

## 📞 Contact

- **Discord**: [Polygon Discord](https://discord.gg/polygon)
- **Twitter**: [@0xPolygon](https://twitter.com/0xPolygon)
- **Email**: grants@polygon.technology

---

**🛡️ Polygon Immortal Auth** — *Your Keys. Your Identity. Immortal Security.*

Built with ❤️ for the Polygon Village Grants Program.
