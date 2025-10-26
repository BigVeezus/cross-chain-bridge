// Type definitions for ethers.js events
export interface NFTLockedEvent {
  args: {
    bridgeId: string;
    nftContract: string;
    tokenId: bigint;
    owner: string;
    destinationChainId: bigint;
    timestamp: bigint;
  };
}

export interface BatchLockedEvent {
  args: {
    bridgeIds: string[];
    merkleRoot: string;
    count: bigint;
  };
}

export type BridgeEvent = NFTLockedEvent | BatchLockedEvent;
