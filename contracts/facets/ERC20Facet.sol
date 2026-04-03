// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ERC20Facet {
    AppStorage internal s;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory) {
        return s.erc20Name;
    }

    function symbol() external view returns (string memory) {
        return s.erc20Symbol;
    }

    function decimals() external view returns (uint8) {
        return s.decimals;
    }

    function totalSupply() external view returns (uint256) {
        return s.erc20TotalSupply;
    }

    function erc20BalanceOf(address account) external view returns (uint256) {
        return s.erc20Balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return s.erc20Allowances[owner][spender];
    }

    function erc20Approve(address spender, uint256 amount) external returns (bool) {
        s.erc20Allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function erc20TransferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = s.erc20Allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            s.erc20Allowances[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function mint(address account, uint256 amount) external {
        LibDiamond.enforceIsContractOwner();
        _mint(account, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        s.erc20TotalSupply += amount;
        s.erc20Balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 fromBalance = s.erc20Balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            s.erc20Balances[from] = fromBalance - amount;
        }
        s.erc20Balances[to] += amount;
        emit Transfer(from, to, amount);
    }
}
