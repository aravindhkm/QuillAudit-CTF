
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICBDVendorFactory {
    error InvalidFee();
    error ZeroAddress();
    
    function hasMinterRole(address account) external view returns (bool);
    event vendorAddress(address indexed owner,address indexed newVendor);
}