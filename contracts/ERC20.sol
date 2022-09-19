// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor(
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) {}

    function mint(uint256 amount, address to) public {
        _mint(to, amount);
    }

}
