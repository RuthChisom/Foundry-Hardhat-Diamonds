// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage} from "../libraries/LibAppStorage.sol";
import {IStaking} from "../interfaces/IStaking.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StakingFacet is IStaking {
    AppStorage internal s;

    function stake(uint256 _amount) external override {
        require(_amount > 0, "Staking: Amount must be > 0");
        require(s.stakingToken != address(0), "Staking: Token not set");

        IERC20(s.stakingToken).transferFrom(msg.sender, address(this), _amount);

        s.stakedBalance[msg.sender] += _amount;
        s.totalStaked += _amount;
        s.lastStakeTime[msg.sender] = block.timestamp;

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external override {
        require(_amount > 0, "Staking: Amount must be > 0");
        require(s.stakedBalance[msg.sender] >= _amount, "Staking: Insufficient balance");

        s.stakedBalance[msg.sender] -= _amount;
        s.totalStaked -= _amount;

        IERC20(s.stakingToken).transfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    function getStakedBalance(address _user) external view override returns (uint256) {
        return s.stakedBalance[_user];
    }
}
