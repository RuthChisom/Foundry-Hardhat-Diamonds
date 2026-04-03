// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, Listing} from "../libraries/LibAppStorage.sol";

interface IMarketplace {
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Sold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event Cancelled(uint256 indexed tokenId);

    function list(uint256 tokenId, uint256 price) external;
    function buy(uint256 tokenId) external;
    function cancelListing(uint256 tokenId) external;
    function getListing(uint256 tokenId) external view returns (Listing memory);
}

contract MarketplaceFacet is IMarketplace {
    AppStorage internal s;

    function list(uint256 _tokenId, uint256 _price) external override {
        require(s.owners[_tokenId] == msg.sender, "Marketplace: Not owner");
        require(_price > 0, "Marketplace: Price must be > 0");

        s.listings[_tokenId] = Listing({
            seller: msg.sender,
            price: _price
        });

        emit Listed(_tokenId, msg.sender, _price);
    }

    function buy(uint256 _tokenId) external override {
        Listing storage listing = s.listings[_tokenId];
        require(listing.price > 0, "Marketplace: Not listed");
        require(s.erc20Balances[msg.sender] >= listing.price, "Marketplace: Insufficient ERC20 balance");

        uint256 price = listing.price;
        address seller = listing.seller;

        // Payment (Diamond's internal ERC20)
        s.erc20Balances[msg.sender] -= price;
        s.erc20Balances[seller] += price;

        // NFT Transfer
        _transferNFT(seller, msg.sender, _tokenId);

        delete s.listings[_tokenId];

        emit Sold(_tokenId, msg.sender, price);
    }

    function cancelListing(uint256 _tokenId) external override {
        require(s.listings[_tokenId].seller == msg.sender, "Marketplace: Not seller");
        delete s.listings[_tokenId];
        emit Cancelled(_tokenId);
    }

    function getListing(uint256 _tokenId) external view override returns (Listing memory) {
        return s.listings[_tokenId];
    }

    // internal helper to update NFT storage
    function _transferNFT(address _from, address _to, uint256 _tokenId) internal {
        // Clear approvals
        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
    }
}
