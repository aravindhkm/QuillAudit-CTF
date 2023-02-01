
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICBDManager {    
    error ZeroAddress();
    error OnlyExchange();
    error OnlyFactory();
    error InsufficientBalance();

    function setNewVendor(address newVendor) external;
    function addVendorBalance(address account,uint256 amount) external;
    function getVendorContains(address account) external view returns (bool);
    function isMinter(address account) external view returns (bool);
}