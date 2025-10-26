"use client";

import { useState, useEffect } from "react";
import { ethers } from "ethers";

const SOURCE_RPC =
  process.env.NEXT_PUBLIC_SOURCE_RPC || "http://localhost:8545";
const DEST_RPC = process.env.NEXT_PUBLIC_DEST_RPC || "http://localhost:8546";
const SOURCE_BRIDGE = process.env.NEXT_PUBLIC_SOURCE_BRIDGE || "";
const DEST_BRIDGE = process.env.NEXT_PUBLIC_DEST_BRIDGE || "";
const MOCK_NFT = process.env.NEXT_PUBLIC_MOCK_NFT || "";

const SOURCE_BRIDGE_ABI = [
  "function lockNFT(address nftContract, uint256 tokenId) returns (bytes32)",
  "function batchLockNFTs(address[] nftContracts, uint256[] tokenIds) returns (bytes32[], bytes32)",
  "function isLocked(address nftContract, uint256 tokenId) view returns (bool)",
  "event NFTLocked(bytes32 indexed bridgeId, address indexed nftContract, uint256 indexed tokenId, address owner, uint256 destinationChainId, uint256 timestamp)",
];

const DEST_BRIDGE_ABI = [
  "function getWrappedNFTAddress() view returns (address)",
  "function isMinted(bytes32 bridgeId) view returns (bool)",
  "event NFTMinted(bytes32 indexed bridgeId, address indexed recipient, uint256 wrappedTokenId, address originalContract, uint256 originalTokenId, uint256 timestamp)",
];

const NFT_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function tokenOfOwnerByIndex(address owner, uint256 index) view returns (uint256)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function approve(address to, uint256 tokenId)",
  "function setApprovalForAll(address operator, bool approved)",
  "function isApprovedForAll(address owner, address operator) view returns (bool)",
  "function mint(address to) returns (uint256)",
];

interface NFT {
  tokenId: string;
  contract: string;
  isLocked: boolean;
}

export default function Home() {
  const [account, setAccount] = useState<string>("");
  const [sourceNFTs, setSourceNFTs] = useState<NFT[]>([]);
  const [destNFTs, setDestNFTs] = useState<NFT[]>([]);
  const [selectedNFTs, setSelectedNFTs] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState("");
  const [sourceProvider, setSourceProvider] =
    useState<ethers.JsonRpcProvider | null>(null);
  const [destProvider, setDestProvider] =
    useState<ethers.JsonRpcProvider | null>(null);

  useEffect(() => {
    const srcProvider = new ethers.JsonRpcProvider(SOURCE_RPC);
    const dstProvider = new ethers.JsonRpcProvider(DEST_RPC);
    setSourceProvider(srcProvider);
    setDestProvider(dstProvider);
  }, []);

  const connectWallet = async () => {
    try {
      if (typeof window.ethereum === "undefined") {
        // Use default account for local testing
        const signer = await sourceProvider!.getSigner(0);
        const address = await signer.getAddress();
        setAccount(address);
        setStatus("Connected to local account");
        loadNFTs(address);
        return;
      }

      const provider = new ethers.BrowserProvider(window.ethereum);
      await provider.send("eth_requestAccounts", []);
      const signer = await provider.getSigner();
      const address = await signer.getAddress();
      setAccount(address);
      setStatus("Wallet connected!");
      loadNFTs(address);
    } catch (error: any) {
      setStatus(`Error: ${error.message}`);
    }
  };

  const loadNFTs = async (address: string) => {
    if (!sourceProvider || !destProvider) return;

    try {
      setLoading(true);

      // Load source chain NFTs
      const nftContract = new ethers.Contract(
        MOCK_NFT,
        NFT_ABI,
        sourceProvider
      );
      const balance = await nftContract.balanceOf(address);

      const sourceNFTList: NFT[] = [];
      for (let i = 0; i < Number(balance); i++) {
        const tokenId = await nftContract.tokenOfOwnerByIndex(address, i);
        const sourceBridge = new ethers.Contract(
          SOURCE_BRIDGE,
          SOURCE_BRIDGE_ABI,
          sourceProvider
        );
        const isLocked = await sourceBridge.isLocked(MOCK_NFT, tokenId);

        sourceNFTList.push({
          tokenId: tokenId.toString(),
          contract: MOCK_NFT,
          isLocked,
        });
      }

      setSourceNFTs(sourceNFTList);

      // Load destination chain NFTs
      const destBridge = new ethers.Contract(
        DEST_BRIDGE,
        DEST_BRIDGE_ABI,
        destProvider
      );
      const wrappedNFTAddress = await destBridge.getWrappedNFTAddress();
      const wrappedNFT = new ethers.Contract(
        wrappedNFTAddress,
        NFT_ABI,
        destProvider
      );

      try {
        const wrappedBalance = await wrappedNFT.balanceOf(address);
        const destNFTList: NFT[] = [];

        for (let i = 0; i < Number(wrappedBalance); i++) {
          const tokenId = await wrappedNFT.tokenOfOwnerByIndex(address, i);
          destNFTList.push({
            tokenId: tokenId.toString(),
            contract: wrappedNFTAddress,
            isLocked: false,
          });
        }

        setDestNFTs(destNFTList);
      } catch (err) {
        console.log("No wrapped NFTs yet");
        setDestNFTs([]);
      }

      setStatus("NFTs loaded!");
    } catch (error: any) {
      setStatus(`Error loading NFTs: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const toggleNFTSelection = (tokenId: string) => {
    const newSelection = new Set(selectedNFTs);
    if (newSelection.has(tokenId)) {
      newSelection.delete(tokenId);
    } else {
      newSelection.add(tokenId);
    }
    setSelectedNFTs(newSelection);
  };

  const bridgeNFTs = async () => {
    if (selectedNFTs.size === 0) {
      setStatus("Please select NFTs to bridge");
      return;
    }

    try {
      setLoading(true);
      setStatus("Preparing bridge transaction...");

      const signer = await sourceProvider!.getSigner(account || 0);
      const nftContract = new ethers.Contract(MOCK_NFT, NFT_ABI, signer);
      const sourceBridge = new ethers.Contract(
        SOURCE_BRIDGE,
        SOURCE_BRIDGE_ABI,
        signer
      );

      // Check approval
      const isApproved = await nftContract.isApprovedForAll(
        account,
        SOURCE_BRIDGE
      );

      if (!isApproved) {
        setStatus("Approving bridge contract...");
        const approveTx = await nftContract.setApprovalForAll(
          SOURCE_BRIDGE,
          true
        );
        await approveTx.wait();
        setStatus("Approval confirmed!");
      }

      const tokenIds = Array.from(selectedNFTs);

      if (tokenIds.length === 1) {
        // Single NFT bridge
        setStatus("Locking NFT on source chain...");
        const tx = await sourceBridge.lockNFT(MOCK_NFT, tokenIds[0]);
        const receipt = await tx.wait();

        // Get bridge ID from event
        const event = receipt.logs.find((log: any) => {
          try {
            const parsed = sourceBridge.interface.parseLog(log);
            return parsed?.name === "NFTLocked";
          } catch {
            return false;
          }
        });

        setStatus(
          `✅ NFT locked! Bridge ID: ${event ? "Generated" : "Check logs"}`
        );
      } else {
        // Batch bridge
        setStatus(`Locking ${tokenIds.length} NFTs in batch...`);
        const contracts = new Array(tokenIds.length).fill(MOCK_NFT);
        const tx = await sourceBridge.batchLockNFTs(contracts, tokenIds);
        await tx.wait();

        setStatus(
          `✅ ${tokenIds.length} NFTs locked! Relayer will mint on destination chain.`
        );
      }

      // Wait a bit for relayer to process
      setTimeout(() => {
        loadNFTs(account);
        setSelectedNFTs(new Set());
      }, 3000);
    } catch (error: any) {
      setStatus(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const mintTestNFT = async () => {
    try {
      setLoading(true);
      setStatus("Minting test NFT...");

      const signer = await sourceProvider!.getSigner(account || 0);
      const nftContract = new ethers.Contract(MOCK_NFT, NFT_ABI, signer);

      const tx = await nftContract.mint(account);
      await tx.wait();

      setStatus("✅ Test NFT minted!");
      loadNFTs(account);
    } catch (error: any) {
      setStatus(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 text-white">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-cyan-400 to-purple-400 bg-clip-text text-transparent">
            🌉 ZK NFT Bridge
          </h1>
          <p className="text-xl text-gray-300">
            Cross-chain NFT transfers with Zero-Knowledge Proofs
          </p>
        </div>

        {/* Connect Wallet */}
        {!account ? (
          <div className="max-w-md mx-auto bg-white/10 backdrop-blur-lg rounded-2xl p-8 text-center">
            <button
              onClick={connectWallet}
              className="bg-gradient-to-r from-cyan-500 to-blue-500 hover:from-cyan-600 hover:to-blue-600 text-white font-bold py-4 px-8 rounded-xl text-lg transition-all transform hover:scale-105"
            >
              Connect Wallet
            </button>
          </div>
        ) : (
          <>
            {/* Account Info */}
            <div className="max-w-6xl mx-auto mb-8 bg-white/10 backdrop-blur-lg rounded-2xl p-6">
              <div className="flex justify-between items-center">
                <div>
                  <p className="text-gray-400 text-sm">Connected Account</p>
                  <p className="text-lg font-mono">
                    {account.slice(0, 6)}...{account.slice(-4)}
                  </p>
                </div>
                <button
                  onClick={mintTestNFT}
                  disabled={loading}
                  className="bg-green-500 hover:bg-green-600 disabled:bg-gray-500 text-white font-bold py-2 px-6 rounded-lg transition-all"
                >
                  Mint Test NFT
                </button>
              </div>
            </div>

            {/* Status */}
            {status && (
              <div className="max-w-6xl mx-auto mb-6">
                <div className="bg-blue-500/20 border border-blue-500/50 rounded-lg p-4 text-center">
                  {status}
                </div>
              </div>
            )}

            {/* Main Bridge Interface */}
            <div className="max-w-6xl mx-auto grid md:grid-cols-2 gap-8">
              {/* Source Chain */}
              <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-6">
                <h2 className="text-2xl font-bold mb-4 flex items-center">
                  <span className="mr-2">⛓️</span> Source Chain
                </h2>
                <p className="text-gray-400 text-sm mb-4">
                  Select NFTs to bridge
                </p>

                {sourceNFTs.length === 0 ? (
                  <div className="text-center py-12 text-gray-400">
                    <p>No NFTs found</p>
                    <p className="text-sm mt-2">
                      Mint some test NFTs to get started!
                    </p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {sourceNFTs.map((nft) => (
                      <div
                        key={nft.tokenId}
                        onClick={() =>
                          !nft.isLocked && toggleNFTSelection(nft.tokenId)
                        }
                        className={`p-4 rounded-xl cursor-pointer transition-all ${
                          nft.isLocked
                            ? "bg-gray-600/30 border-2 border-gray-500 cursor-not-allowed"
                            : selectedNFTs.has(nft.tokenId)
                            ? "bg-cyan-500/30 border-2 border-cyan-400"
                            : "bg-white/5 border-2 border-transparent hover:bg-white/10"
                        }`}
                      >
                        <div className="flex justify-between items-center">
                          <div>
                            <p className="font-bold">NFT #{nft.tokenId}</p>
                            <p className="text-xs text-gray-400 font-mono">
                              {nft.contract.slice(0, 6)}...
                              {nft.contract.slice(-4)}
                            </p>
                          </div>
                          {nft.isLocked && (
                            <span className="bg-yellow-500/20 text-yellow-300 text-xs px-3 py-1 rounded-full">
                              🔒 Locked
                            </span>
                          )}
                          {selectedNFTs.has(nft.tokenId) && (
                            <span className="bg-cyan-500 text-white text-xs px-3 py-1 rounded-full">
                              ✓ Selected
                            </span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                {selectedNFTs.size > 0 && (
                  <button
                    onClick={bridgeNFTs}
                    disabled={loading}
                    className="w-full mt-6 bg-gradient-to-r from-cyan-500 to-blue-500 hover:from-cyan-600 hover:to-blue-600 disabled:from-gray-500 disabled:to-gray-600 text-white font-bold py-4 px-6 rounded-xl transition-all transform hover:scale-105"
                  >
                    {loading
                      ? "Processing..."
                      : `Bridge ${selectedNFTs.size} NFT${
                          selectedNFTs.size > 1 ? "s" : ""
                        } →`}
                  </button>
                )}
              </div>

              {/* Destination Chain */}
              <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-6">
                <h2 className="text-2xl font-bold mb-4 flex items-center">
                  <span className="mr-2">🎁</span> Destination Chain
                </h2>
                <p className="text-gray-400 text-sm mb-4">
                  Wrapped NFTs (minted by relayer)
                </p>

                {destNFTs.length === 0 ? (
                  <div className="text-center py-12 text-gray-400">
                    <p>No wrapped NFTs yet</p>
                    <p className="text-sm mt-2">
                      Bridge some NFTs to see them here!
                    </p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {destNFTs.map((nft) => (
                      <div
                        key={nft.tokenId}
                        className="p-4 rounded-xl bg-purple-500/20 border-2 border-purple-400"
                      >
                        <div className="flex justify-between items-center">
                          <div>
                            <p className="font-bold">
                              Wrapped NFT #{nft.tokenId}
                            </p>
                            <p className="text-xs text-gray-400 font-mono">
                              {nft.contract.slice(0, 6)}...
                              {nft.contract.slice(-4)}
                            </p>
                          </div>
                          <span className="bg-purple-500/30 text-purple-200 text-xs px-3 py-1 rounded-full">
                            ✨ Wrapped
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Info Cards */}
            <div className="max-w-6xl mx-auto mt-8 grid md:grid-cols-3 gap-4">
              <div className="bg-white/5 backdrop-blur-lg rounded-xl p-4 text-center">
                <p className="text-3xl mb-2">🔐</p>
                <p className="text-sm text-gray-400">ZK Proof Verification</p>
              </div>
              <div className="bg-white/5 backdrop-blur-lg rounded-xl p-4 text-center">
                <p className="text-3xl mb-2">🌳</p>
                <p className="text-sm text-gray-400">
                  Merkle Batch Optimization
                </p>
              </div>
              <div className="bg-white/5 backdrop-blur-lg rounded-xl p-4 text-center">
                <p className="text-3xl mb-2">⚡</p>
                <p className="text-sm text-gray-400">Automated Relayer</p>
              </div>
            </div>
          </>
        )}

        {/* Footer */}
        <div className="text-center mt-12 text-gray-400 text-sm">
          <p>Built with Solidity, TypeScript, ethers.js & Next.js</p>
          <p className="mt-2">
            ⚠️ Demo only - Uses mock ZK proofs for local testing
          </p>
        </div>
      </div>
    </div>
  );
}
