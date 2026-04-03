// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getStakedBalance(address user) external view returns (uint256);
}
