// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";

interface IMultiSig {
    event Proposed(uint256 indexed proposalId, address[] targets, uint256[] values, bytes[] calldatas);
    event Confirmed(uint256 indexed proposalId, address indexed owner);
    event Executed(uint256 indexed proposalId);

    function propose(address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas) external returns (uint256);
    function confirm(uint256 proposalId) external;
    function execute(uint256 proposalId) external;
    function getProposal(uint256 proposalId) external view returns (Proposal memory);
    function isOwner(address account) external view returns (bool);
}
