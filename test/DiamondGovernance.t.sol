// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MultiSigFacet.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/facets/SVGFacet.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) public { balanceOf[to] += amount; }
    function approve(address, uint256) public returns (bool) { return true; }
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract DiamondGovernanceTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    MultiSigFacet multisigF;
    StakingFacet stakingF;
    SVGFacet svgF;
    DiamondInit dInit;
    MockERC20 token;

    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address nonOwner = address(0x3);

    function setUp() public {
        token = new MockERC20();
        dCutFacet = new DiamondCutFacet();
        // Diamond constructor uses LibDiamond.diamondCut which doesn't have the msg.sender == address(this) check yet
        // because it's an internal library call in the constructor context.
        diamond = new Diamond(address(this), address(dCutFacet));
        
        dLoupe = new DiamondLoupeFacet();
        multisigF = new MultiSigFacet();
        stakingF = new StakingFacet();
        svgF = new SVGFacet();
        dInit = new DiamondInit();

        FacetCut[] memory cut = new FacetCut[](4);
        cut[0] = FacetCut({facetAddress: address(dLoupe), action: FacetCutAction.Add, functionSelectors: generateSelectors("DiamondLoupeFacet")});
        cut[1] = FacetCut({facetAddress: address(multisigF), action: FacetCutAction.Add, functionSelectors: generateSelectors("MultiSigFacet")});
        cut[2] = FacetCut({facetAddress: address(stakingF), action: FacetCutAction.Add, functionSelectors: generateSelectors("StakingFacet")});
        cut[3] = FacetCut({facetAddress: address(svgF), action: FacetCutAction.Add, functionSelectors: generateSelectors("SVGFacet")});

        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        
        // We need to bypass the msg.sender == address(this) check for the initial setup
        // Actually, the current DiamondCutFacet.diamondCut HAS the check. 
        // We must call it through a multisig proposal or change how we initialize.
        // For testing setup, I'll use a trick: the Diamond constructor already added diamondCut.
        // But the DiamondCutFacet's diamondCut function now requires msg.sender == address(this).
        
        // Let's use the multisig to add the rest of the facets!
        // But wait, the multisig facet isn't added yet. Catch-22.
        // Solution: The Diamond constructor should ideally add the core facets.
        // For this test, I will temporarily "be" the diamond using prank if possible? No.
        
        // I'll modify the Diamond.sol to use LibDiamond.diamondCut directly in constructor (which it does).
        // The check is in DiamondCutFacet.sol, not LibDiamond.sol.
        // So I can still call DiamondCutFacet.diamondCut but only if msg.sender is the diamond.
        
        // Let's manually add MultiSigFacet first via a special path or just 
        // use LibDiamond directly if I were writing a migration.
        // Here, I will use a proposal to add the rest.
    }

    function testMultiSigDiamondCut() public {
        // 1. Add MultiSigFacet via Diamond Cut (Must be through Diamond itself)
        FacetCut[] memory cut = new FacetCut[](1);
        cut[0] = FacetCut({
            facetAddress: address(multisigF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("MultiSigFacet")
        });

        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        bytes memory initData = abi.encodeWithSelector(DiamondInit.initGovernance.selector, owners, 2, address(token));

        vm.prank(address(diamond));
        IDiamondCut(address(diamond)).diamondCut(cut, address(dInit), initData);

        // 2. Try to add StakingFacet without MultiSig (should fail)
        FacetCut[] memory cut2 = new FacetCut[](1);
        cut2[0] = FacetCut({
            facetAddress: address(stakingF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("StakingFacet")
        });

        vm.expectRevert("DiamondCut: Must be through multisig");
        IDiamondCut(address(diamond)).diamondCut(cut2, address(0), "");

        // 4. Add StakingFacet via MultiSig Proposal
        address[] memory targets = new address[](1);
        targets[0] = address(diamond);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cut2, address(0), "");

        vm.prank(owner1);
        uint256 pid = MultiSigFacet(address(diamond)).propose(targets, values, calldatas);

        vm.prank(owner1);
        MultiSigFacet(address(diamond)).confirm(pid);

        vm.prank(owner2);
        MultiSigFacet(address(diamond)).confirm(pid);

        MultiSigFacet(address(diamond)).execute(pid);

        // Verify StakingFacet is added
        assertEq(StakingFacet(address(diamond)).getStakedBalance(address(0x123)), 0);
    }

    function testStaking() public {
        // Setup similar to above but simplified for staking focus
        testMultiSigDiamondCut();

        token.mint(nonOwner, 1000);
        vm.startPrank(nonOwner);
        token.approve(address(diamond), 1000);
        StakingFacet(address(diamond)).stake(1000);
        assertEq(StakingFacet(address(diamond)).getStakedBalance(nonOwner), 1000);
        
        StakingFacet(address(diamond)).withdraw(400);
        assertEq(StakingFacet(address(diamond)).getStakedBalance(nonOwner), 600);
        assertEq(token.balanceOf(nonOwner), 400);
        vm.stopPrank();
    }

    function testSVG() public {
        testMultiSigDiamondCut();
        
        // Add SVGFacet via proposal
        FacetCut[] memory cut = new FacetCut[](1);
        cut[0] = FacetCut({
            facetAddress: address(svgF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("SVGFacet")
        });
        
        executeProposal(abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cut, address(0), ""));

        // Set Base SVG via proposal
        executeProposal(abi.encodeWithSelector(SVGFacet.setBaseSvg.selector, "<svg>...</svg>"));

        string memory res = SVGFacet(address(diamond)).getSvg(1);
        assertTrue(bytes(res).length > 0);
    }

    function executeProposal(bytes memory _calldata) internal {
        address[] memory targets = new address[](1);
        targets[0] = address(diamond);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = _calldata;

        vm.prank(owner1);
        uint256 pid = MultiSigFacet(address(diamond)).propose(targets, values, calldatas);
        vm.prank(owner1);
        MultiSigFacet(address(diamond)).confirm(pid);
        vm.prank(owner2);
        MultiSigFacet(address(diamond)).confirm(pid);
        MultiSigFacet(address(diamond)).execute(pid);
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
