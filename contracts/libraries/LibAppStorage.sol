// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Proposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    bool executed;
    uint256 confirmations;
}

struct AppStorage {
    // ERC721
    string name;
    string symbol;
    mapping(uint256 => address) owners;
    mapping(address => uint256) balances;
    mapping(uint256 => address) tokenApprovals;
    mapping(address => mapping(address => bool)) operatorApprovals;
    uint256 totalSupply;

    // ERC20 & Staking
    address stakingToken;
    mapping(address => uint256) stakedBalance;
    mapping(address => uint256) lastStakeTime;
    uint256 totalStaked;

    // MultiSig
    address[] multisigOwners;
    mapping(address => bool) isMultisigOwner;
    uint256 requiredConfirmations;
    mapping(uint256 => Proposal) proposals;
    mapping(uint256 => mapping(address => bool)) isConfirmed;
    uint256 proposalCount;

    // SVG
    string baseSvg;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}
