// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/ERC721MetadataFacet.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "../contracts/Diamond.sol";

contract DeployERC721Diamond is Script, IDiamondCut {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Facets
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        OwnershipFacet ownerF = new OwnershipFacet();
        ERC721Facet erc721F = new ERC721Facet();
        ERC721MetadataFacet erc721MetadataF = new ERC721MetadataFacet();
        DiamondInit dInit = new DiamondInit();

        // 2. Deploy Diamond
        Diamond diamond = new Diamond(vm.addr(deployerPrivateKey), address(dCutFacet));

        // 3. Prepare Cut Struct
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

        // 4. Upgrade Diamond and Initialize ERC721
        bytes memory initData = abi.encodeWithSelector(
            DiamondInit.initERC721.selector, 
            "MyDiamondNFT", 
            "DNFT"
        );
        
        IDiamondCut(address(diamond)).diamondCut(cut, address(dInit), initData);

        vm.stopBroadcast();

        console.log("Diamond deployed at:", address(diamond));
    }

    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    // Required by IDiamondCut interface but not used in the script itself
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
