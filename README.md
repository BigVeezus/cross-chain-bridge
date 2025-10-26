# 🌉 ZK NFT Bridge

A complete cross-chain NFT bridge with Zero-Knowledge proof verification, automated relayer service, and modern web interface.

## 🚀 Quick Start

```bash
# Clone and setup
git clone <your-repo-url>
cd cross-chain-bridge
chmod +x setup.sh
./setup.sh

# Choose option 12: Complete setup
# This will install dependencies, deploy contracts, and start all services
```

**That's it!** Your bridge will be running at `http://localhost:3000`

## 📋 What This Does

### For Users (Simple)
- **Bridge NFTs** between different blockchains
- **Lock** your NFT on source chain → **Get** wrapped NFT on destination chain
- **Unlock** wrapped NFT → **Get** original NFT back
- **Batch operations** for gas efficiency

### For Developers (Technical)
- **Lock & Mint Mechanism**: NFTs locked on source, wrapped NFTs minted on destination
- **ZK Proof Verification**: Mock zero-knowledge proofs for demonstration
- **Automated Relayer**: Watches events and automatically processes bridge operations
- **Merkle Tree Batching**: Gas-optimized batch operations
- **Full-Stack UI**: Next.js frontend with wallet integration

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Source Chain  │    │     Relayer     │    │ Destination     │
│   (Ethereum)    │◄──►│   Service       │◄──►│ Chain (L2)      │
│                 │    │                 │    │                 │
│ • Original NFTs │    │ • Watches events │    │ • Wrapped NFTs  │
│ • Lock contract │    │ • Generates ZK   │    │ • Mint contract │
│ • Unlock logic  │    │ • Auto-mints     │    │ • Burn logic    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Tech Stack

- **Smart Contracts**: Solidity + Foundry
- **Relayer**: TypeScript + Ethers.js
- **Frontend**: Next.js + React + Tailwind CSS
- **Wallet**: Wagmi + RainbowKit
- **Testing**: Local Anvil chains

## 📁 Project Structure

```
cross-chain-bridge/
├── contracts/              # Smart contracts
│   ├── src/               # Source contracts
│   ├── test/              # Contract tests
│   └── script/            # Deployment scripts
├── relayer/               # Automated relayer service
│   └── src/               # TypeScript relayer code
├── frontend/              # Next.js web application
│   └── src/               # React components
├── setup.sh              # Unified setup script
└── package.json          # Monorepo configuration
```

## 🎮 How to Use

### 1. **Setup** (One-time)
```bash
./setup.sh
# Choose option 12: Complete setup
```

### 2. **Use the Bridge**
1. Visit `http://localhost:3000`
2. Click "Connect Wallet" (auto-connects to first Anvil account)
3. Click "Mint Test NFT" to create test NFTs
4. Select NFTs and click "Bridge NFT →"
5. Watch the relayer automatically mint wrapped NFTs!

### 3. **Unlock NFTs**
1. Select wrapped NFTs
2. Click "Unlock NFT ←"
3. Watch original NFTs get unlocked!

## 🔧 Available Commands

### Setup Script Options
```bash
./setup.sh
# 1) Check dependencies
# 2) Install all dependencies  
# 3) Compile contracts
# 4) Run tests
# 5) Deploy contracts
# 6) Setup environment files
# 7) Start local chains
# 8) Start relayer
# 9) Start frontend
# 10) Full setup (1-6)
# 11) Start all services (7-9)
# 12) Complete setup (1-9) ← RECOMMENDED
# 13) Fix and restart services
```

### Manual Commands
```bash
# Install all dependencies
pnpm install:all

# Build contracts
pnpm build:contracts

# Run tests
pnpm test:contracts

# Deploy contracts
pnpm deploy:contracts

# Start services
pnpm start:relayer
pnpm start:frontend
pnpm start:chains

# Clean everything
pnpm clean
```

## 🌐 Services & Ports

| Service | URL | Description |
|---------|-----|-------------|
| **Frontend** | `http://localhost:3000` | Web interface |
| **Source Chain** | `http://localhost:8545` | Ethereum (Chain ID: 1) |
| **Destination Chain** | `http://localhost:8546` | L2 (Chain ID: 421614) |
| **Relayer** | Background process | Automated bridge processing |

## 🔍 Troubleshooting

### Common Issues

**"Connect Wallet" not working?**
- Make sure contracts are deployed (run option 5 in setup.sh)
- Check that local chains are running

**Relayer not processing?**
- Check relayer logs for errors
- Verify contract addresses in `.env` files
- Ensure chains are running

**TypeScript errors?**
- Run `pnpm type-check` to verify compilation
- All TypeScript issues have been resolved

### Reset Everything
```bash
# Stop all services
pkill -f anvil
pkill -f relayer  
pkill -f frontend

# Clean and restart
pnpm clean
./setup.sh
# Choose option 12: Complete setup
```

## 📊 Features

### ✅ Implemented
- [x] Cross-chain NFT locking/unlocking
- [x] Automated relayer service
- [x] ZK proof verification (mock)
- [x] Merkle tree batching
- [x] Modern web interface
- [x] Wallet integration
- [x] Gas optimization
- [x] Comprehensive testing
- [x] TypeScript support
- [x] Unified setup script

### 🚧 Future Enhancements
- [ ] Real ZK proof generation
- [ ] Multiple chain support
- [ ] Production deployment
- [ ] Advanced UI features
- [ ] Analytics dashboard

## 🧪 Testing

```bash
# Run all contract tests
cd contracts && forge test

# Test specific functionality
forge test --match-test testLockNFT
forge test --match-test testBatchLockNFTs
forge test --match-test testMintWrappedNFT
```

## 📝 Smart Contracts

### Core Contracts
- **SourceBridge**: Locks NFTs and emits events
- **DestinationBridge**: Mints wrapped NFTs and handles burns
- **MockNFT**: Test NFT for demonstration
- **WrappedNFT**: Internal contract for wrapped NFTs

### Key Functions
```solidity
// Lock single NFT
function lockNFT(address nftContract, uint256 tokenId) external

// Lock multiple NFTs (gas optimized)
function batchLockNFTs(address[] calldata nftContracts, uint256[] calldata tokenIds) external

// Mint wrapped NFT
function mintWrappedNFT(bytes32 bridgeId, address originalContract, uint256 originalTokenId, address recipient) external

// Unlock original NFT
function unlockNFT(address nftContract, uint256 tokenId) external
```

## 🔐 Security

- **Access Control**: Only bridge contracts can mint/burn
- **Reentrancy Protection**: Safe external calls
- **Input Validation**: Comprehensive parameter checks
- **Event Logging**: Full audit trail
- **ZK Proof Verification**: Cryptographic validation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `pnpm test:contracts`
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

- **Issues**: Create a GitHub issue
- **Documentation**: Check this README
- **Setup Problems**: Run `./setup.sh` option 13

---

**Ready to bridge NFTs? Run `./setup.sh` and choose option 12!** 🚀