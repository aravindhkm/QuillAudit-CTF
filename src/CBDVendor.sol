// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {EIP712} from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "openzeppelin-contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ICBDVendor} from "./interfaces/ICBDVendor.sol";
import {ICBDVendorFactory} from "./interfaces/ICBDVendorFactory.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";


contract CBDVendor is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ICBDVendor, EIP712{
    bytes32 private constant PERMIT_TYPEHASH = keccak256("Permit(address seller,address buyer,uint256 tokenId,string uri,uint256 blockExpiry)");

    ICBDVendorFactory private immutable factory;
    address private currentVendor;
    bool public isMintable;

    mapping (bytes32 => bool) private _nonces;

    constructor(
        string memory name,
        string memory symbol,
        address newVendor,
        address owner
        ) ERC721(name, symbol) EIP712(name, "1.0") {
        if(newVendor == address(0)) revert ZeroAddress();
        if(owner == address(0)) revert ZeroAddress();

        currentVendor = newVendor;
        factory = ICBDVendorFactory(msg.sender);

        _transferOwnership(owner);
    }

    function vendorWallet() external view virtual override returns (address) {
        return currentVendor;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function setMintOption(bool status) external onlyOwner {
        isMintable = status;
    }

    function setTokenURI(uint256 tokenId, string memory uri) external onlyOwner {
        _setTokenURI(tokenId, uri);
    }

    function setNewVendor(address newVendor) external onlyOwner{
        if(newVendor == address(0)) revert ZeroAddress();

        currentVendor = newVendor;
    }

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function safeMintWithPermit( 
        address from,
        address to,
        uint256 tokenId,
        string memory uri,
        uint256 blockExpiry,
        uint8 v,
        bytes32 r,
        bytes32 s) external {
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH,from,to,tokenId,keccak256(bytes(uri)),blockExpiry));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);

        if(block.number >= blockExpiry) revert BlockExpired();
        if(!isMintable) revert MintOptionDisable();
        if(signer == address(0)) revert ZeroAddress();
        if(_nonces[hash]) revert NonceAlreadyUsed();
        if(!(factory.hasMinterRole(signer))) revert InvalidMinter();

        _nonces[hash] = true;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}