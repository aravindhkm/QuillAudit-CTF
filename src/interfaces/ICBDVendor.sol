
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICBDVendor {
    function vendorWallet() external view returns (address);
    function safeMintWithPermit( 
        address from,
        address to,
        uint256 tokenId,
        string memory uri,
        uint256 blockExpiry,
        uint8 v,
        bytes32 r,
        bytes32 s) external;

    event vendorAddress(address indexed owner,address indexed newVendor);

    error InvalidFee();
    error ZeroAddress();
    error NonceAlreadyUsed();
    error InvalidMinter();
    error MintOptionDisable();
    error BlockExpired();
}