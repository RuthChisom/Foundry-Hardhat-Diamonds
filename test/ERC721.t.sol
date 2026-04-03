// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/ERC721MetadataFacet.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract ERC721Test is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721F;
    ERC721MetadataFacet erc721MetadataF;
    DiamondInit dInit;

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721F = new ERC721Facet();
        erc721MetadataF = new ERC721MetadataFacet();
        dInit = new DiamondInit();

        // Build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = FacetCut({
            facetAddress: address(dLoupe),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        cut[1] = FacetCut({
            facetAddress: address(ownerF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });

        cut[2] = FacetCut({
            facetAddress: address(erc721F),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });

        cut[3] = FacetCut({
            facetAddress: address(erc721MetadataF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721MetadataFacet")
        });

        // Upgrade diamond and initialize ERC721
        bytes memory initData = abi.encodeWithSelector(DiamondInit.initERC721.selector, "TestNFT", "TNFT");
        IDiamondCut(address(diamond)).diamondCut(cut, address(dInit), initData);
    }

    function testERC721Metadata() public {
        assertEq(ERC721MetadataFacet(address(diamond)).name(), "TestNFT");
        assertEq(ERC721MetadataFacet(address(diamond)).symbol(), "TNFT");
    }

    function testMintAndTransfer() public {
        address user1 = address(0x1);
        address user2 = address(0x2);
        uint256 tokenId = 1;

        ERC721Facet(address(diamond)).mint(user1, tokenId);
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), user1);
        assertEq(ERC721Facet(address(diamond)).erc721BalanceOf(user1), 1);

        vm.prank(user1);
        ERC721Facet(address(diamond)).erc721TransferFrom(user1, user2, tokenId);
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), user2);
        assertEq(ERC721Facet(address(diamond)).erc721BalanceOf(user1), 0);
        assertEq(ERC721Facet(address(diamond)).erc721BalanceOf(user2), 1);
    }

    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
