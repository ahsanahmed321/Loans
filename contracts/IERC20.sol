//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";


interface IERC20 {

    function mint(uint256 _value, address _beneficiary) external;

    function burnFrom(uint256 _value, address _beneficiary) external;
    
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function totalSupply() external returns (uint256);
    function balanceOf(address account) external returns (uint256);
}