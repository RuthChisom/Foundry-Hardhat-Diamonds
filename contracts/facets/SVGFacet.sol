// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage} from "../libraries/LibAppStorage.sol";

interface ISVG {
    function getSvg(uint256 tokenId) external view returns (string memory);
    function setBaseSvg(string calldata baseSvg) external;
}

contract SVGFacet is ISVG {
    AppStorage internal s;

    function getSvg(uint256 _tokenId) external view override returns (string memory) {
        // Basic example: return baseSvg wrapped in a unique ID comment
        return string(abi.encodePacked(s.baseSvg, "<!-- Token ID: ", uint2str(_tokenId), " -->"));
    }

    function setBaseSvg(string calldata _baseSvg) external override {
        // Restricted to multisig (Diamond itself)
        require(msg.sender == address(this), "SVG: Must be through multisig");
        s.baseSvg = _baseSvg;
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
