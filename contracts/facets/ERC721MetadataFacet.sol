// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage} from "../libraries/LibAppStorage.sol";
import {IERC721Metadata} from "../interfaces/IERC721.sol";

contract ERC721MetadataFacet is IERC721Metadata {
    AppStorage internal s;

    function name() external view override returns (string memory) {
        return s.name;
    }

    function symbol() external view override returns (string memory) {
        return s.symbol;
    }

    function tokenURI(uint256 _tokenId) external view override returns (string memory) {
        require(s.owners[_tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");
        return ""; // Base URI implementation can be added to AppStorage
    }
}
