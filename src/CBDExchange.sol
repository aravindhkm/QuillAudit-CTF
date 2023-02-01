
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {Order,SigStore,MintParams,AssetType} from  "./utils/DataTypes.sol";
import {OrderState} from "./utils/OrderState.sol";
import {ICBDManager} from "./interfaces/ICBDManager.sol";
import {ICBDVendor} from "./interfaces/ICBDVendor.sol";

contract CBDExchange is OrderState, Ownable, Pausable {
    using ECDSA for bytes32;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    address public beneficiaryAddress;
    address public buyerFeeSigner;
    uint256 public beneficiaryFee; 
    uint256 public royaltyFeeLimit;
    uint256 public vendorFeeLimit;
    ICBDManager public manager;
    address public weth;

    // auth token for exchange
    mapping(address => bool) public allowedToken;

    event MatchOrder(
        address indexed sellToken,
        uint256 indexed sellTokenId,
        uint256 sellValue,
        address owner,
        address buyToken,
        uint256 buyTokenId,
        uint256 buyValue,
        address buyer,
        uint256 orderType
    );

    event Cancel(
        address indexed sellToken,
        uint256 indexed sellTokenId,
        address owner,
        address buyToken,
        uint256 buyTokenId
    );

	constructor(
		address payable beneficiary,
        address buyerfeesigner,
        uint256 beneficiaryfee,
        address cbdManagerAddr,
        address wethAddr
	)  {
		royaltyFeeLimit = 50;
		beneficiaryAddress = beneficiary;
        buyerFeeSigner = buyerfeesigner;
        beneficiaryFee = beneficiaryfee;
        manager = ICBDManager(cbdManagerAddr);
        weth = wethAddr;
    }                                    

    receive() external payable {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function sell(
        Order calldata order,
        SigStore calldata sig,
        SigStore calldata buyerFeeSig,
        uint256 royaltyFee,
        uint256 vendorFee,
        address payable royaltyReceipt,
        bool isStore,
        MintParams memory storeParams
    ) external payable whenNotPaused {
        require((block.timestamp <= order.expiryTime), "S-1");
        require(order.orderType == 1, "S-2");
        require(order.key.owner != msg.sender, "S-3");

        validateOrderSignature(order, sig);
        validateBuyerFeeSig(order, royaltyFee, royaltyReceipt, buyerFeeSig);

        transferSellFee(
            order, 
            royaltyReceipt, 
            isStore ? ICBDVendor(order.key.sellAsset.token).vendorWallet() : address(0), 
            royaltyFee, 
            vendorFee, 
            msg.sender
        );
        setCompleted(order, true);
        transferToken(order, msg.sender, isStore, storeParams);
        emitMatchOrder(order, msg.sender);
    }

    function buy(
        Order calldata order,
        SigStore calldata sig,
        SigStore calldata buyerFeeSig,
        uint256 royaltyFee,
        uint256 vendorFee,
        address payable royaltyReceipt,
        bool isStore,
        MintParams memory storeParams
    ) external whenNotPaused {
        require((block.timestamp <= order.expiryTime), "B-1");
        require(order.orderType == 2, "B-2");
        require(order.key.owner != msg.sender, "B-3");
        validateOrderSignature(order, sig);
        validateBuyerFeeSig(order, royaltyFee, royaltyReceipt, buyerFeeSig);
        
        transferBuyFee(
            order, 
            royaltyReceipt,
            isStore ? ICBDVendor(order.key.buyAsset.token).vendorWallet() : address(0), 
            royaltyFee, 
            vendorFee, 
            msg.sender
        );
        setCompleted(order, true);
        transferToken(order, msg.sender, isStore, storeParams);
        emitMatchOrder(order, msg.sender);
    }

    function bid(
        Order calldata order,
        SigStore calldata sig,
        SigStore calldata buyerSig,
        SigStore calldata buyerFeeSig,
        address buyer,
        uint256 buyingAmount,
        uint256 royaltyFee,
        uint256 vendorFee,
        address payable royaltyReceipt,
        bool isStore,
        MintParams memory storeParams
    ) external whenNotPaused {
        require((block.timestamp <= order.expiryTime), "A-1");
        require(buyingAmount >= order.buying, "A-2");	
        require(order.orderType == 3, "A-3");
        require(order.key.owner == msg.sender, "A-4");

        validateOrderSignature(order, sig);
        validateBidOrderSignature(order, buyerSig, buyer, buyingAmount);
        validateBuyerFeeSig(order, royaltyFee, royaltyReceipt, buyerFeeSig);

        setCompleted(order, true);
        setCompletedBidOrder(order, true, buyer, buyingAmount);

        transferBidFee(
            order.key.buyAsset.token,
            order.key.owner,
            buyingAmount,
            royaltyReceipt,
            isStore ? ICBDVendor(order.key.sellAsset.token).vendorWallet() : address(0),
            royaltyFee,
            vendorFee,
            buyer
        );
        transferToken(order, buyer, isStore, storeParams);
        emitMatchOrder(order, buyer);
    }

    function nftValidation(IERC721 asset,uint256 nftId) internal view returns (bool) {
       return asset.ownerOf(nftId) == address(0);
    }
    
    function transferToken(
        Order calldata order,
        address buyer,
        bool isStore,
        MintParams memory storeParams
    ) internal {
        if (order.key.sellAsset.assetType == AssetType.ERC721 || order.key.buyAsset.assetType == AssetType.ERC721) {
            if (order.orderType == 1 || order.orderType == 3) {
                if (!isStore) {
                    if(manager.getVendorContains(order.key.sellAsset.token)){
                        require(nftValidation(IERC721(order.key.sellAsset.token),order.key.sellAsset.tokenId), "R-N");
                    }
                    
                    IERC721(order.key.sellAsset.token).safeTransferFrom(
                        order.key.owner,
                        buyer,
                        order.key.sellAsset.tokenId
                    );
                } else {
                    require(manager.getVendorContains(order.key.sellAsset.token), "TK-1");
                    ICBDVendor(order.key.sellAsset.token).safeMintWithPermit(                        
                        order.key.owner,
                        buyer,
                        order.key.sellAsset.tokenId,
                        storeParams.uri,
                        storeParams.blockExpiry,
                        storeParams.v,
                        storeParams.r,
                        storeParams.s
                    );
                }
            } else if (order.orderType == 2) {
                if (!isStore) {
                    if(manager.getVendorContains(order.key.sellAsset.token)){
                        require(nftValidation(IERC721(order.key.sellAsset.token),order.key.sellAsset.tokenId), "R-N");
                    }

                    IERC721(order.key.buyAsset.token).safeTransferFrom(
                        buyer,
                        order.key.owner,
                        order.key.buyAsset.tokenId
                    );
                } else {
                    require(manager.getVendorContains(order.key.buyAsset.token), "TK-2");
                    ICBDVendor(order.key.buyAsset.token).safeMintWithPermit(                        
                        buyer,
                        order.key.owner,
                        order.key.buyAsset.tokenId,
                        storeParams.uri,
                        storeParams.blockExpiry,
                        storeParams.v,
                        storeParams.r,
                        storeParams.s
                    );
                }
            }
        } else if (order.key.sellAsset.assetType == AssetType.ERC1155 || order.key.buyAsset.assetType == AssetType.ERC1155) {
            if (order.orderType == 1 || order.orderType == 3) {
                if (!isStore) {
                    IERC1155(order.key.sellAsset.token).safeTransferFrom(                        
                        order.key.owner,
                        buyer,
                        order.key.sellAsset.tokenId,
                        order.selling,
                        "0x"
                    );
                } else {
                    require(manager.getVendorContains(order.key.sellAsset.token), "TK-3");
                    ICBDVendor(order.key.sellAsset.token).safeMintWithPermit(                        
                        order.key.owner,
                        buyer,
                        order.key.sellAsset.tokenId,
                        storeParams.uri,
                        storeParams.blockExpiry,
                        storeParams.v,
                        storeParams.r,
                        storeParams.s
                    );
                }
            } else if (order.orderType == 2) {
                if (!isStore) {
                    IERC1155(order.key.buyAsset.token).safeTransferFrom(              
                        buyer,
                        order.key.owner,
                        order.key.buyAsset.tokenId,
                        order.buying,
                        "0x"
                    );
                } else {
                    require(manager.getVendorContains(order.key.buyAsset.token), "TK-4");
                    ICBDVendor(order.key.buyAsset.token).safeMintWithPermit(
                        buyer,
                        order.key.owner,
                        order.key.buyAsset.tokenId,
                        storeParams.uri,
                        storeParams.blockExpiry,
                        storeParams.v,
                        storeParams.r,
                        storeParams.s
                    );
                }
            }
        } else {
            revert("invalid assest");
        }
    }

    function transferSellFee(
        Order calldata order,
        address royaltyReceipt,
        address vendorReceipt,
        uint256 royaltyFee,
        uint256 vendorFee,
        address buyer
    ) internal {
        if (order.key.buyAsset.token == address(0x00)) {
            require(msg.value == order.buying, "TS-1");
            transferEthFee(
                order.buying,
                order.key.owner,
                royaltyFee,
                vendorFee,
                royaltyReceipt,
                vendorReceipt
            );
        } else if (order.key.buyAsset.token == weth) {
            transferWethFee(
                order.buying,
                order.key.owner,
                buyer,
                royaltyFee,
                vendorFee,
                royaltyReceipt,
                vendorReceipt
            );
        } else {
            transferErc20Fee(
                order.key.buyAsset.token,
                order.buying,
                order.key.owner,
                buyer,
                royaltyFee,
                vendorFee,
                royaltyReceipt,
                vendorReceipt
            );
        }
    }

    function transferBuyFee(
        Order calldata order,
        address royaltyReceipt,
        address vendorReceipt,
        uint256 royaltyFee,
        uint256 vendorFee,
        address buyer
    ) internal {
        if (order.key.sellAsset.token == weth) {
            transferWethFee(
                order.selling,
                buyer,
                order.key.owner,
                royaltyFee,
                vendorFee,
                royaltyReceipt,
                vendorReceipt
            );
        } else {
            transferErc20Fee(
                order.key.sellAsset.token,
                order.selling,
                buyer,
                order.key.owner,
                royaltyFee,
                vendorFee,
                royaltyReceipt,
                vendorReceipt
            );
        }
    }

    function transferBidFee(
        address assest,
        address seller,
        uint256 buyingAmount,
        address royaltyReceipt,
        address vendorReceipt,
        uint256 royaltyFee,
        uint256 vendorFee,
        address buyer
    ) internal {
        if (assest == weth) {
            transferWethFee(
                buyingAmount,
                seller,
                buyer,
                royaltyFee,
                vendorFee,
                royaltyReceipt,
                vendorReceipt
            );
        } else {
            transferErc20Fee(
                assest,
                buyingAmount,
                seller,
                buyer,
                royaltyFee,
                vendorFee,
                royaltyReceipt,
                vendorReceipt
            );
        }
    }

    function transferEthFee(
        uint256 amount,
        address _seller,
        uint256 royaltyFee,
        uint256 vendorFee,
        address royaltyReceipt,
        address vendorReceipt
    ) internal {
        (
            uint256 protocolfee,
            uint256 secoundaryFee,
            uint256 vendorShare,
            uint256 remaining
        ) = transferFeeView(amount, 
            royaltyReceipt == address(0) ? 0 :royaltyFee, 
            vendorReceipt == address(0) ? 0 : vendorFee);
        if (protocolfee > 0) {
            beneficiaryAddress.safeTransferETH(protocolfee);
        }
        if ((secoundaryFee > 0) && (royaltyReceipt != address(0x00))) {
            royaltyReceipt.safeTransferETH(secoundaryFee);
        }
        if ((vendorShare > 0) && (vendorReceipt != address(0x00))) {
            address(manager).safeTransferETH(vendorShare);
            manager.addVendorBalance(vendorReceipt,vendorShare);
        }
        if (remaining > 0) {
            _seller.safeTransferETH(remaining);
        }
    }

    function transferWethFee(
        uint256 amount,
        address _seller,
        address buyer,
        uint256 royaltyFee,
        uint256 vendorFee,
        address royaltyReceipt,
        address vendorReceipt
    ) internal {
        (
            uint256 protocolfee,
            uint256 secoundaryFee,
            uint256 vendorShare,
            uint256 remaining
        ) = transferFeeView(amount, 
                royaltyReceipt == address(0) ? 0 :royaltyFee, 
                vendorReceipt == address(0) ? 0 : vendorFee);
        if (protocolfee > 0) {
            ERC20(weth).safeTransferFrom(
                buyer,
                beneficiaryAddress,
                protocolfee
            );
        }
        if ((secoundaryFee > 0) && (royaltyReceipt != address(0x00))) {
            ERC20(weth).safeTransferFrom(buyer, royaltyReceipt, secoundaryFee);
        }
        if ((vendorShare > 0) && (vendorReceipt != address(0x00))) {
            ERC20(weth).safeTransferFrom(buyer, vendorReceipt, vendorShare);
        }
        if (remaining > 0) {
            ERC20(weth).safeTransferFrom(buyer, _seller, remaining);
        }
    }

    function transferErc20Fee(
        address token,
        uint256 amount,
        address _seller,
        address buyer,
        uint256 royaltyFee,
        uint256 vendorFee,
        address royaltyReceipt,
        address vendorReceipt
    ) internal {
        require(allowedToken[token], "TE-1");

        (
            uint256 protocolfee,
            uint256 secoundaryFee,
            uint256 vendorShare,
            uint256 remaining
        ) = transferFeeView(amount, 
                royaltyReceipt == address(0) ? 0 :royaltyFee, 
                vendorReceipt == address(0) ? 0 : vendorFee);
        if (protocolfee > 0) {
            ERC20(token).safeTransferFrom(
                buyer,
                beneficiaryAddress,
                protocolfee
            );
        }
        if ((secoundaryFee > 0) && (royaltyReceipt != address(0x00))) {            
            ERC20(token).safeTransferFrom(
                buyer,
                royaltyReceipt,
                secoundaryFee
            );
        }
        if ((vendorShare > 0) && (vendorReceipt != address(0x00))) {
            ERC20(token).safeTransferFrom(
                buyer,
                vendorReceipt,
                vendorShare
            );
        }
        if (remaining > 0) {
            ERC20(token).safeTransferFrom(buyer, _seller, remaining);
        }
    }

    function transferFeeView(uint256 amount, uint256 royaltyPcent, uint256 vendorPcent)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 protocolFee = (amount * beneficiaryFee) / 1000;

        uint256 secoundaryFee;
        uint256 vendorShareFee;

        if(royaltyPcent > 0) {
            uint256 royaltyShare = royaltyPcent > royaltyFeeLimit ? royaltyFeeLimit : royaltyPcent;
            secoundaryFee = (amount * royaltyShare) / 1000;
        }
        
        if(vendorPcent > 0) {
            uint256 vendorShare = vendorPcent > vendorFeeLimit ? vendorFeeLimit : royaltyPcent;
            vendorShareFee = (amount * vendorShare) / 1000;
        }

        uint256 remaining = amount - (protocolFee + secoundaryFee + vendorShareFee);

        return (protocolFee, secoundaryFee, vendorShareFee, remaining);
    }

    function emitMatchOrder(Order memory order, address buyer) internal {
        emit MatchOrder(
            order.key.sellAsset.token,
            order.key.sellAsset.tokenId,
            order.selling,
            order.key.owner,
            order.key.buyAsset.token,
            order.key.buyAsset.tokenId,
            order.buying,
            buyer,
            order.orderType
        );
    }

    function cancel(Order calldata order) external {
        require(order.key.owner == msg.sender, "C-1");
        setCompleted(order, true);
        emit Cancel(
            order.key.sellAsset.token,
            order.key.sellAsset.tokenId,
            msg.sender,
            order.key.buyAsset.token,
            order.key.buyAsset.tokenId
        );
    }

    function validateBuyerFeeSig(
        Order memory order,
        uint256 buyerFee,
        address royaltyReceipt,
        SigStore memory sig
    ) internal view {
        require(
            prepareBuyerFeeMessage(order, buyerFee, royaltyReceipt).recover(
                sig.v,
                sig.r,
                sig.s
            ) == buyerFeeSigner,
            "VB"
        );
    }

    function validateBuyerFeeSigView(
        Order memory order,
        uint256 buyerFee,
        address royaltyReceipt,
        SigStore memory sig
    ) public pure returns (address) {
            return prepareBuyerFeeMessage(order, buyerFee, royaltyReceipt).recover(
                sig.v,
                sig.r,
                sig.s
            ); 
    }

    function toEthSignedMessageHash(bytes32 hash, SigStore memory sig)
        public
        pure
        returns (address signer)
    {
        signer = hash.recover(sig.v, sig.r, sig.s);
    }

    function setBeneficiary(address newBeneficiary) external onlyOwner {
        if(newBeneficiary == address(0x00)) revert ZeroAddress();

        beneficiaryAddress = newBeneficiary;
    }

    function setBuyerFeeSigner(address newBuyerFeeSigner) external onlyOwner {
        if(newBuyerFeeSigner == address(0x00)) revert ZeroAddress();

        buyerFeeSigner = newBuyerFeeSigner;
    }

    function setBeneficiaryFee(uint256 newbeneficiaryfee) external onlyOwner {
        beneficiaryFee = newbeneficiaryfee;
    }

    function setRoyaltyFeeLimit(uint256 newRoyaltyFeeLimit) external onlyOwner {
        royaltyFeeLimit = newRoyaltyFeeLimit;
    }

    function setVendorFeeLimit(uint256 newVendorFeeLimit) external onlyOwner {
        vendorFeeLimit = newVendorFeeLimit;
    }

    function setTokenStatus(address token, bool status) external onlyOwner {
        if(token == address(0x00)) revert ZeroAddress();

        allowedToken[token] = status;
    }

    function recoverLeftOverEth(uint256 amount) external onlyOwner {
        owner().safeTransferETH(amount);
    }

    function recoverLeftOverToken(ERC20 token,uint256 amount) external onlyOwner {
        token.safeTransfer(owner(),amount);
    }
}