// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract SBBaseContract is ERC20, Ownable, ReentrancyGuard {

    uint8 public immutable tokenDecimals = 0;

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        _mint(msg.sender, _initialSupply);
    }

    function burnItAll(address account) external onlyOwner() nonReentrant() {
        _burn(account, balanceOf(account));
    }

    receive() external payable nonReentrant() {
        // We will only log in case fllabck is called
        // and assume receive call is normal.
    }

    fallback() external payable nonReentrant() {
        // Do nothing but
        console.log("Fallback method called");
        console.logBytes4(msg.sig);
        console.logBytes(msg.data);
    }
}
