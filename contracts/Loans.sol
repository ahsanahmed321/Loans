//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import {IERC20} from "./IERC20.sol";
import {ERC20Token} from "./ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Loans {
    using SafeMath for uint256;

    AggregatorV3Interface internal priceFeed;

    uint256 public baseRate = 20000000000000000;

    address public immutable lpToken;
    address public immutable usdt;

    uint256 public totalDeposits; //USDT Value
    uint256 public totalBorrows; //USDT Value
    uint256 public totalFeesEarned; //USDT Value

    mapping(address => uint256) public usersCollateral; //ETH Value
    mapping(address => uint256) public usersBorrowed; //USDT Value
    mapping(address => uint256) public usersBorrowTimeStamp; //Timestamp
    mapping(address => uint256) public usersPastBorrow; //USDT Value
    mapping(address => uint256) public usersPastInterest; //USDT Value

    constructor() {
        ERC20Token lpTokenContract = new ERC20Token("KUMAIL", "KUM");
        lpToken = address(lpTokenContract);

        ERC20Token usdtContract = new ERC20Token("TETHER", "USDT");
        usdt = address(usdtContract);

        priceFeed = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );
    }

    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function getExchangeRate() public returns (uint256) {
        uint256 totalUSDT = totalDeposits + totalFeesEarned;
        uint256 totalLP = IERC20(lpToken).totalSupply();
        return totalUSDT / totalLP;
    }

    function _utilizationRatio() public view returns (uint256) {
        return totalBorrows / totalDeposits;
    }

    function _borrowRate() public view returns (uint256) {
        uint256 uRatio = _utilizationRatio() / 100;
        return uRatio + baseRate;
    }

    function _interestPerTime(address sender) public view returns (uint256) {
        return
            ((block.timestamp - usersBorrowTimeStamp[sender]) / 3600000) / 100;
    }

    function calculateBorrowFee(uint256 _amount, address sender)
        public
        view
        returns (uint256, uint256)
    {
        uint256 borrowRate = _borrowRate();
        uint256 interestPerTime = _interestPerTime(sender);
        uint256 fee = (_amount * borrowRate) + (_amount * interestPerTime);
        uint256 paid = _amount - fee;
        return (fee, paid);
    }

    function lend(uint256 amount) external {
        IERC20(usdt).transferFrom(msg.sender, address(this), amount);
        uint256 lpTobeMinted = amount.div(getExchangeRate());
        IERC20(lpToken).mint(lpTobeMinted, msg.sender);

        totalDeposits += amount;
    }

    function unLend(uint256 amount) external {
        IERC20(lpToken).burnFrom(amount, msg.sender);
        uint256 tokensToBeTransfered = amount * getExchangeRate();
        totalDeposits -= tokensToBeTransfered;

        IERC20(usdt).transfer(msg.sender, tokensToBeTransfered);
    }

    function addCollateral() external payable {
        usersCollateral[msg.sender] += msg.value;
    }

    function removeCollateral(uint256 _amount) external {
        usersCollateral[msg.sender] -= _amount;
        payable(address(this)).transfer(_amount);
    }

    function borrow() external payable {
        int256 ethPrice = getLatestPrice();
        uint256 amountInUSDT = ((msg.value * uint256(ethPrice)) * 80) / 100;

        usersPastBorrow[msg.sender] += usersBorrowed[msg.sender];

        (uint256 fee, uint256 paid) = calculateBorrowFee(
            usersBorrowed[msg.sender],
            msg.sender
        );
        usersPastInterest[msg.sender] += fee;

        usersBorrowed[msg.sender] += amountInUSDT;
        usersCollateral[msg.sender] += msg.value;

        usersBorrowTimeStamp[msg.sender] = block.timeStamp;

        totalDeposits -= amountInUSDT;
        totalBorrows += amountInUSDT;

        IERC20(usdt).transfer(msg.sender, amountInUSDT);
    }

    function repay(uint256 _amount) external {
        IERC20(usdt).transferFrom(msg.sender, address(this), _amount);
        (uint256 fee, uint256 paid) = calculateBorrowFee(_amount, msg.sender);

        uint256 userReturnRatio = _amount / usersBorrowed[msg.sender];

        uint256 amountOut = usersCollateral[msg.sender] * userReturnRatio;

        usersCollateral[msg.sender] -= amountOut;
        usersBorrowed[msg.sender] -= paid;
        totalDeposits += paid;
        totalBorrows -= paid;
        totalFeesEarned += fee;

        payable(address(this)).transfer(amountOut);
    }
}

// borrow 100 USDT
// after 2 days
// borrow 100 USDT             past borrows = 100    past interest = 4        current borrows = 200
// after 3 days
// borrow 100 USDT             past borrows = 200    past interest = 4 + 12   current borrows = 300
// after 4 days

// Now on the 9th day user have to pay 300 USDT
// on the 1st 100 USDT interest = 18
// on the 2nd 100 USDT interest = 14
// on the 3rd 100 USDT interest = 8

// total interest 40

// past interest =  16               past borrows = 200
// current interest = 24             current borrow = 300      current day = 4

// //Test Cases 1
// user returning 100 USDT thats 1/2 of past borrows and 1/3 of current borrow so he will be paying = 8 + 8 = 16

// past interest =  8               past borrows = 100
// current interest = 16             current borrow = 200      current day = 4

// user again paying 100 USDT thats complete past borrow and half of current borrow = 8 + 8 = 16

// past interest =  0               past borrows = 0
// current interest = 8             current borrow = 100      current day = 4

// //Test Case 2
// user returning 250 USDT so the user pays past interest on 200 and current interest on 250 = 16 + 19.9

// past interest =  0               past borrows = 0
// current interest = 4.1             current borrow = 50      current day = 4
