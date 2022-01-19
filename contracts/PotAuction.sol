//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract PotAuction is ReentrancyGuard{
    using SafeERC20 for IERC20;

    /// @dev Keep bidders' detail
    struct Bidder {
        address bidderAddr;
        uint256 totalBidPrice;
        uint256 pricePerToken;
        uint256 requiredTokens;
    }
    
    /// @dev bidder id => Bidder
    mapping(uint256 => Bidder) public bidders;

    /// @dev bidder id
    uint256 public bidderIdTracker;

    /// @dev address of ERC20 token
    address public token;

    /// @dev The initial price
    uint256 startPrice;

    /// @dev The reserve price
    uint256 reservePrice;

    /// @dev The reserve asset
    uint256 reserveAmount;

    /// @dev The block number when this contract is deployed
    uint256 startDate;

    /// @dev The number of blocks after startDate for which this auction will be open
    uint256 endDate;

    /// @dev Indicate if this auction has been closed by the seller
    bool isClosedBySeller;

    /// @dev The owner of this auction
    address owner;

    /// @dev The seller of this auction
    address payable public seller;

    /// @dev The total size of lots that we are selling
    uint256 public totalAmount;
    
    /// @dev flag that represents the status of auction
    bool public isOver;

    /// @dev end price: last bidder's current price
    uint256 endPrice;

    event BidPlaced(address, uint, uint);

    event AcutionOpened(uint256);

    event AuctionClosed(string);

    event TokenTransferredAndRefunded();

    /**
     * @dev constructor
     * @param _token address of ERC20 token(asset)
     * @param _seller address of seller
     * @param _totalAmount total number of tokens to be sold
     * @param _startPrice start price
     * @param _reservePrice reserve price
     * @param _startDate auction start date
     * @param _endDate auction end date
     */    
    constructor(
        address _token,
        address payable _seller,
        uint256 _totalAmount,
        uint256 _reservePrice,
        uint256 _startPrice,
        uint256 _startDate,
        uint256 _endDate
    ) ReentrancyGuard() {
        startPrice = _startPrice;
        reservePrice = _reservePrice;
        startDate = _startDate;
        totalAmount = _totalAmount ;
        endDate = _endDate;
        token = _token;
        seller = _seller;
        owner = msg.sender;
        
        require(endDate > startDate, "POT: invalid endDate");
        require(reservePrice > 0, "POT: invalid reserve price");
        require(startPrice > reservePrice, "POT: invalid start price");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), totalAmount);

        emit AcutionOpened(startDate);
    }

    /// @dev Indicate if this auction is still open or not
    function isClosed() public view returns(bool) {
        if (isOver)
            return true;

        if (block.number >= endDate)
            return true;

        return false;
    }

    /**
     * @dev return the current price of the goods
     * @param _startPrice start price
     * @param _reservePrice reserve price
     * @param _startDate auction start date
     * @param _endDate auction end date
     * @param currentBlockNumber current time
     */
    function getPrice(
        uint256 _startPrice,
        uint256 _reservePrice,
        uint256 _startDate,
        uint256 _endDate,
        uint256 currentBlockNumber
    ) public pure returns(uint256) {
        require(currentBlockNumber <= _endDate, "POT: You are out of end date");

        uint256 blocks = _endDate - _startDate;
        uint256 elapsedBlocks = currentBlockNumber - _startDate;

        return _startPrice - elapsedBlocks * (_startPrice - _reservePrice) / blocks;
    }

    /**
     * @dev Return the current price of the good
     * @param currentBlock current time
     */
    function getCurrentPrice(uint256 currentBlock) public view returns(uint256){
        return getPrice(startPrice, reservePrice, startDate, endDate, currentBlock);
    }

    /**
     * @dev Make a bid request
     * @param bid number of required assets(tokens)
     */
    function makeBid(uint256 bid) payable external {
        uint256 actualBid;
        uint256 currentBlock = block.number;
        uint256 currentPrice = getCurrentPrice(currentBlock);

        require(!isClosed(), "POT: auction is closed.");
        require(bid > 0, "POT: zero amount");
        require(msg.value == currentPrice * bid, "POT: invalid payment for the bid");

        if (currentPrice < reservePrice) {
            revert("POT: current price is reached to reserve price.");
        } else {
            if (reserveAmount + bid >= totalAmount) {
                actualBid = totalAmount - reserveAmount;
                endPrice = currentPrice;
                isOver = true;
                emit AuctionClosed("POT: all tokens are sold out.");
            } else {
                reserveAmount += bid;
                actualBid = bid;
            }
            bidders[bidderIdTracker] = Bidder(
                msg.sender,
                msg.value,
                currentPrice,
                actualBid
            );
            bidderIdTracker += 1;

            emit BidPlaced(msg.sender, currentPrice, msg.value);
        }
    }
}