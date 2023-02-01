
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

enum AssetType {
    ERC20,
    ERC721,
    ERC1155
}

struct Asset {
    address token;
    uint256 tokenId;
    AssetType assetType;
}

struct OrderKey {
    /* who signed the order */
    address payable owner;
    /* what has owner */
    Asset sellAsset;
    /* what wants owner */
    Asset buyAsset;
}

struct Order {
    OrderKey key;
    /* how much has owner (in wei, or UINT256_MAX if ERC-721) */
    uint256 selling;
    /* how much wants owner (in wei, or UINT256_MAX if ERC-721) */
    uint256 buying;
    /* fee for selling  secoundary sale*/
    uint256 sellerFee;
    /* random numbers*/
    uint256 salt;
    /* expiry time for order*/
    uint256 expiryTime; // for bid auction auction time + bidexpiry
    /* order Type */
    uint256 orderType; // 1.sell , 2.buy, 3.bid
}

/* An ECDSA signature. */
struct SigStore {
    /* v parameter */
    uint8 v;
    /* r parameter */
    bytes32 r;
    /* s parameter */
    bytes32 s;
}

struct MintParams {
    uint256 blockExpiry;
    uint8 v;
    bytes32 r;
    bytes32 s;
    string uri;
}