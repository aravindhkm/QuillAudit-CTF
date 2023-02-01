// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CBDVendor} from "./CBDVendor.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {ICBDVendorFactory} from "./interfaces/ICBDVendorFactory.sol";
import {ICBDManager} from "./interfaces/ICBDManager.sol";

contract CBDVendorFactory is Ownable, Pausable, ICBDVendorFactory {
    using SafeTransferLib for address;

    address public tresuryWallet;
    uint96 public tresuryFee;

    ICBDManager public manager;

    constructor(address _manager) {
        manager = ICBDManager(_manager);
    }

    receive() external payable {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setTresuryAddress(address newTresuryWallet) public onlyOwner {
        tresuryWallet = newTresuryWallet;
    }

    function setNewManager(address newManager) public onlyOwner {
        if(newManager == address(0)) revert ZeroAddress();

        manager = ICBDManager(newManager);
    }

    function setTresuryFee(uint96 newFee) external onlyOwner {
        tresuryFee = newFee;
    }

    function hasMinterRole(address account) external view returns (bool) {
        return manager.isMinter(account);
    }

    function createNewVendor(
        string memory name,
        string memory symbol,
        address nftOwner
    ) external payable whenNotPaused {
        if(tresuryFee != 0 && tresuryWallet != address(0)) {
            if(msg.value <= tresuryFee) revert InvalidFee();

            tresuryWallet.safeTransferETH(msg.value);
        }

        CBDVendor newVendor = new CBDVendor(name,symbol,nftOwner,nftOwner);
        newVendor.setNewVendor(address(newVendor));

        emit vendorAddress(msg.sender,address(newVendor));
    }


}