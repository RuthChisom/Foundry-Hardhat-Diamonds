// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, Loan} from "../libraries/LibAppStorage.sol";

interface IBorrower {
    event NFTLent(uint256 indexed tokenId, address indexed lender, address indexed borrower, uint256 expires);
    event NFTReturned(uint256 indexed tokenId);

    function lend(uint256 tokenId, address borrower, uint256 duration) external;
    function returnNFT(uint256 tokenId) external;
    function getLoan(uint256 tokenId) external view returns (Loan memory);
}

contract BorrowerFacet is IBorrower {
    AppStorage internal s;

    function lend(uint256 _tokenId, address _borrower, uint256 _duration) external override {
        require(s.owners[_tokenId] == msg.sender, "Borrower: Not owner");
        require(s.loans[_tokenId].expires <= block.timestamp, "Borrower: Already lent");
        require(_borrower != address(0), "Borrower: Invalid borrower");

        uint256 expires = block.timestamp + _duration;
        s.loans[_tokenId] = Loan({
            lender: msg.sender,
            borrower: _borrower,
            expires: expires
        });

        // Effect: Transfer "control" logic would usually be here, 
        // but for a simple borrower facet we just track the state.
        // In a real implementation, we might restrict the owner from transferring while lent.

        emit NFTLent(_tokenId, msg.sender, _borrower, expires);
    }

    function returnNFT(uint256 _tokenId) external override {
        Loan storage loan = s.loans[_tokenId];
        require(msg.sender == loan.borrower || block.timestamp >= loan.expires, "Borrower: Cannot return yet");
        
        delete s.loans[_tokenId];
        emit NFTReturned(_tokenId);
    }

    function getLoan(uint256 _tokenId) external view override returns (Loan memory) {
        return s.loans[_tokenId];
    }
}
