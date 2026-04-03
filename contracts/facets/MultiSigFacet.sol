// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, Proposal} from "../libraries/LibAppStorage.sol";
import {IMultiSig} from "../interfaces/IMultiSig.sol";

contract MultiSigFacet is IMultiSig {
    AppStorage internal s;

    modifier onlyMultisigOwner() {
        require(s.isMultisigOwner[msg.sender], "MultiSig: Not an owner");
        _;
    }

    function isOwner(address _account) external view override returns (bool) {
        return s.isMultisigOwner[_account];
    }

    function propose(address[] calldata _targets, uint256[] calldata _values, bytes[] calldata _calldatas) external override onlyMultisigOwner returns (uint256 proposalId) {
        require(_targets.length > 0, "MultiSig: No targets");
        require(_targets.length == _values.length && _targets.length == _calldatas.length, "MultiSig: Length mismatch");

        proposalId = s.proposalCount++;
        Proposal storage p = s.proposals[proposalId];
        p.targets = _targets;
        p.values = _values;
        p.calldatas = _calldatas;
        p.executed = false;
        p.confirmations = 0;

        emit Proposed(proposalId, _targets, _values, _calldatas);
    }

    function confirm(uint256 _proposalId) external override onlyMultisigOwner {
        require(_proposalId < s.proposalCount, "MultiSig: Invalid proposal");
        require(!s.isConfirmed[_proposalId][msg.sender], "MultiSig: Already confirmed");
        require(!s.proposals[_proposalId].executed, "MultiSig: Already executed");

        s.isConfirmed[_proposalId][msg.sender] = true;
        s.proposals[_proposalId].confirmations++;

        emit Confirmed(_proposalId, msg.sender);
    }

    function execute(uint256 _proposalId) external override {
        require(_proposalId < s.proposalCount, "MultiSig: Invalid proposal");
        Proposal storage p = s.proposals[_proposalId];
        require(!p.executed, "MultiSig: Already executed");
        require(p.confirmations >= s.requiredConfirmations, "MultiSig: Not enough confirmations");

        p.executed = true;

        for (uint256 i = 0; i < p.targets.length; i++) {
            (bool success, bytes memory error) = p.targets[i].call{value: p.values[i]}(p.calldatas[i]);
            if (!success) {
                if (error.length > 0) {
                    assembly {
                        let error_size := mload(error)
                        revert(add(32, error), error_size)
                    }
                } else {
                    revert("MultiSig: Transaction execution failed");
                }
            }
        }

        emit Executed(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view override returns (Proposal memory) {
        return s.proposals[_proposalId];
    }
}
