// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/BorrowerFacet.sol";
import "../contracts/facets/MarketplaceFacet.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract DiamondMarketBorrowTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    ERC721Facet erc721F;
    ERC20Facet erc20F;
    BorrowerFacet borrowerF;
    MarketplaceFacet marketplaceF;
    DiamondInit dInit;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        
        dLoupe = new DiamondLoupeFacet();
        erc721F = new ERC721Facet();
        erc20F = new ERC20Facet();
        borrowerF = new BorrowerFacet();
        marketplaceF = new MarketplaceFacet();
        dInit = new DiamondInit();

        FacetCut[] memory cut = new FacetCut[](5);
        cut[0] = FacetCut({facetAddress: address(dLoupe), action: FacetCutAction.Add, functionSelectors: generateSelectors("DiamondLoupeFacet")});
        cut[1] = FacetCut({facetAddress: address(erc721F), action: FacetCutAction.Add, functionSelectors: generateSelectors("ERC721Facet")});
        cut[2] = FacetCut({facetAddress: address(erc20F), action: FacetCutAction.Add, functionSelectors: generateSelectors("ERC20Facet")});
        cut[3] = FacetCut({facetAddress: address(borrowerF), action: FacetCutAction.Add, functionSelectors: generateSelectors("BorrowerFacet")});
        cut[4] = FacetCut({facetAddress: address(marketplaceF), action: FacetCutAction.Add, functionSelectors: generateSelectors("MarketplaceFacet")});

        vm.prank(address(diamond));
        IDiamondCut(address(diamond)).diamondCut(cut, address(dInit), abi.encodeWithSelector(DiamondInit.initERC20.selector, "DiamondDollar", "DD", 18));
    }

    function testERC20Internal() public {
        ERC20Facet(address(diamond)).mint(alice, 1000 ether);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(alice), 1000 ether);
    }

    function testBorrowing() public {
        uint256 tokenId = 1;
        ERC721Facet(address(diamond)).mint(alice, tokenId);
        
        vm.prank(alice);
        BorrowerFacet(address(diamond)).lend(tokenId, bob, 1 days);
        
        Loan memory loan = BorrowerFacet(address(diamond)).getLoan(tokenId);
        assertEq(loan.borrower, bob);
        assertEq(loan.lender, alice);
        assertEq(loan.expires, block.timestamp + 1 days);
        
        // Return
        vm.prank(bob);
        BorrowerFacet(address(diamond)).returnNFT(tokenId);
        assertEq(BorrowerFacet(address(diamond)).getLoan(tokenId).borrower, address(0));
    }

    function testMarketplace() public {
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        
        ERC721Facet(address(diamond)).mint(alice, tokenId);
        ERC20Facet(address(diamond)).mint(bob, 500 ether);
        
        vm.prank(alice);
        MarketplaceFacet(address(diamond)).list(tokenId, price);
        
        assertEq(MarketplaceFacet(address(diamond)).getListing(tokenId).price, price);
        
        vm.prank(bob);
        MarketplaceFacet(address(diamond)).buy(tokenId);
        
        assertEq(ERC721Facet(address(diamond)).ownerOf(tokenId), bob);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(alice), 100 ether);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(bob), 400 ether);
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
