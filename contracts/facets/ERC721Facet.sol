// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {IERC721, IERC721TokenReceiver} from "../interfaces/IERC721.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract ERC721Facet is IERC721 {
    AppStorage internal s;

    function balanceOf(address _owner) external view override returns (uint256) {
        require(_owner != address(0), "ERC721: balance query for the zero address");
        return s.balances[_owner];
    }

    function ownerOf(uint256 _tokenId) external view override returns (address) {
        address owner = s.owners[_tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function approve(address _to, uint256 _tokenId) external override {
        address owner = s.owners[_tokenId];
        require(msg.sender == owner || s.operatorApprovals[owner][msg.sender], "ERC721: approve caller is not owner nor approved for all");
        s.tokenApprovals[_tokenId] = _to;
        emit Approval(owner, _to, _tokenId);
    }

    function getApproved(uint256 _tokenId) external view override returns (address) {
        require(s.owners[_tokenId] != address(0), "ERC721: approved query for nonexistent token");
        return s.tokenApprovals[_tokenId];
    }

    function setApprovalForAll(address _operator, bool _approved) external override {
        require(_operator != msg.sender, "ERC721: approve to caller");
        s.operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) external view override returns (bool) {
        return s.operatorApprovals[_owner][_operator];
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public override {
        address owner = s.owners[_tokenId];
        require(_isApprovedOrOwner(msg.sender, _tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(_from, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external override {
        this.safeTransferFrom(_from, _to, _tokenId, "");
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) public override {
        transferFrom(_from, _to, _tokenId);
        require(_checkOnERC721Received(_from, _to, _tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    // Mint function for testing (restricted to owner)
    function mint(address _to, uint256 _tokenId) external {
        LibDiamond.enforceIsContractOwner();
        require(_to != address(0), "ERC721: mint to the zero address");
        require(s.owners[_tokenId] == address(0), "ERC721: token already minted");

        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
        s.totalSupply += 1;

        emit Transfer(address(0), _to, _tokenId);
    }

    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        require(s.owners[_tokenId] == _from, "ERC721: transfer from incorrect owner");
        require(_to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals
        delete s.tokenApprovals[_tokenId];

        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;

        emit Transfer(_from, _to, _tokenId);
    }

    function _isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
        address owner = s.owners[_tokenId];
        return (_spender == owner || s.tokenApprovals[_tokenId] == _spender || s.operatorApprovals[owner][_spender]);
    }

    function _checkOnERC721Received(address _from, address _to, uint256 _tokenId, bytes memory _data) internal returns (bool) {
        if (_to.code.length > 0) {
            try IERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721TokenReceiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}
