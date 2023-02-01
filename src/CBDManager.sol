// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ICBDManager} from "./interfaces/ICBDManager.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

contract CBDManager is Ownable, Pausable, ReentrancyGuard, AccessControl, ICBDManager {
    using SafeTransferLib for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public vendorExchange;
    address public vendorFactory;

    struct VendorInfo {
        uint256 balance;
        uint256 timestamp;
    }

    mapping (address => VendorInfo) public VendorStore;
    EnumerableSet.AddressSet private NftStore;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        _setRoleAdmin(MINTER_ROLE,DEFAULT_ADMIN_ROLE);
    }

    receive() external payable {}
    
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function init(
        address _vendorExchange,
        address _vendorFactory
    ) external {
        require(vendorExchange == address(0) && vendorFactory == address(0));

        vendorExchange = _vendorExchange;
        vendorFactory  = _vendorFactory;
    }

    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE,account);
    }

    function setVendorExchange(address newVendorExchange) external onlyOwner {
        if(newVendorExchange == address(0)) revert ZeroAddress();

        vendorExchange = newVendorExchange;
    }

    function setVendorFactory(address newVendorFactory) external onlyOwner {
        if(newVendorFactory == address(0)) revert ZeroAddress();

        vendorFactory = newVendorFactory;
    }

    function setNewVendor(address newVendor) external whenNotPaused{
        if(msg.sender == vendorFactory) revert OnlyFactory();

        NftStore.add(newVendor);
    }

    function addVendorBalance(address account,uint256 amount) external whenNotPaused {
        if(msg.sender == vendorExchange) revert OnlyExchange();

        VendorStore[account].balance += amount;
    }

    function claim(uint256 amountOut) external whenNotPaused nonReentrant {
        VendorInfo storage store = VendorStore[msg.sender];

        if(amountOut > store.balance) revert InsufficientBalance();

        store.balance -= amountOut;
        (msg.sender).safeTransferETH(amountOut);
    }

    function getVendorLength() external view returns (uint256) {
         return NftStore.length();
    }
    
    function getVendorAddressAt(uint256 index) external view returns (address) {
        return NftStore.at(index);
    }

    function getAllVendors() external view returns (address[] memory) {
        return NftStore.values();
    }
    
    function getVendorContains(address account) external view returns (bool) {
        return NftStore.contains(account);
    }
}