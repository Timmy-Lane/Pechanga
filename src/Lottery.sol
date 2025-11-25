// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

abstract contract Lottery is ERC721Enumerable, Ownable, ReentrancyGuard, VRFConsumerBaseV2{
    using Strings for uint256;

    uint256 public ticketPrice;

    uint256 public roundId;
    bool public roundOpen;

    uint256 public creatorFeeBase;
    uint256 public platformFeeBase;
    address public platformTreasury;

    VRFCoordinatorV2Interface public coordinator;
    bytes32 public keyHash;
    uint64 public subId;
    uint32 public callbackGasLimit = 250_000;
    uint16 public reqConfirmations = 3;

    uint256 public lastRequestId;
    mapping(uint256 => uint256) public requestToRound;

    struct RoundInfo{
        uint256 startTokenId;
        uint256 endTokenId;
        uint256 pot;
        address winner;
        uint256 randomWord;
        bool settled;
        uint256 ticketsSold;
        uint256 timestamp;
    }

    mapping(uint256 => RoundInfo) public rounds;

    event RoundStarted(uint256 indexed roundId, uint256 startTokenId);
    event TicketsBought(address indexed buyer, uint256 indexed roundId, uint256 amount, uint256 paid);
    event RoundClosed(uint256 indexed roundId, uint256 requestId);
    event WinnerSettled(uint256 indexed roundId, address indexed winner, uint256 prize, uint256 randomWord);
    event FeesUpdated(uint256 creatorFeeBase, uint256 platformFeeBase);
    event TicketPriceUpdated(uint256 ticketPrice);

    error RoundNotOpen();
    error InvalidPayment();
    error NoTickets();
    error RoundAlreadySettled();
    error NotVRFCoordinator();

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _ticketPrice,
        uint256 _creatorFeeBase,

        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    )
        ERC721(_name, _symbol)
        VRFConsumerBaseV2(_vrfCoordinator)
    {
        ticketPrice = _ticketPrice;

        require(_creatorFeeBase <= 2000, "creator fee too high");
        creatorFeeBase = _creatorFeeBase;

        coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subId = _subscriptionId;

        _startNewRound();
    }

    function buyTickets(uint256 amount) external payable nonReentrant{
        if(!roundOpen) revert RoundNotOpen();
        if(amount == 0) revert NoTickets();

        uint256 cost = ticketPrice * amount;
        if(msg.value != cost) revert InvalidPayment();

        RoundInfo storage r = rounds[roundId];

        for(uint256 i = 0; i < amount; i++){
            uint256 tokenId = totalSupply() + 1;
            _safeMint(msg.sender, tokenId);
        }

        r.pot += msg.value;
        r.ticketsSold += amount;

        emit TicketsBought(msg.sender, roundId, amount, msg.value);
    }

    function closeRound() external onlyOwner returns (uint256 requestId) {
        RoundInfo storage r = rounds[roundId];

        require(roundOpen, "round already closed");
        require(r.ticketsSold > 0, "no tickets sold");

        roundOpen = false;

        requestId = coordinator.requestRandomWords(
            keyHash,
            subId,
            reqConfirmations,
            callbackGasLimit,
            1
        );

        lastRequestId = requestId;
        requestToRound[requestId] = roundId;

        emit RoundClosed(roundId, requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 rid = requestToRound[requestId];
        RoundInfo storage r = rounds[rid];

        if (r.settled) revert RoundAlreadySettled();

        uint256 randomWord = randomWords[0];
        r.randomWord = randomWord;

        uint256 startId = r.startTokenId;
        uint256 winnerOffset = randomWord % r.ticketsSold;
        uint256 winnerTokenId = startId + winnerOffset;

        address winner = ownerOf(winnerTokenId);
        r.winner = winner;
        r.settled = true;
        r.endTokenId = startId + r.ticketsSold - 1;
        r.timestamp = block.timestamp;

        uint256 pot = r.pot;
        uint256 creatorFee = (pot * creatorFeeBase) / 10_000;
        uint256 platformFee = (pot * platformFeeBase) / 10_000;
        uint256 prize = pot - creatorFee - platformFee;

        if (platformFee > 0 && platformTreasury != address(0)) {
            (bool okP, ) = platformTreasury.call{value: platformFee}("");
            require(okP, "platform fee transfer failed");
        }

        if (creatorFee > 0) {
            (bool okC, ) = owner().call{value: creatorFee}("");
            require(okC, "creator fee transfer failed");
        }

        (bool okW, ) = winner.call{value: prize}("");
        require(okW, 'Winner transfer failed');

        emit WinnerSettled(rid, winner, prize, randomWord);
        _startNewRound();
    }

    function _startNewRound() internal{
        roundId += 1;
        roundOpen = true;

        uint256 startTokenId = totalSupply() + 1;

        rounds[roundId] = RoundInfo({
            startTokenId: startTokenId,
            endTokenId: 0,
            pot: 0,
            winner: address(0),
            randomWord: 0,
            settled: false,
            ticketsSold: 0,
            timestamp: block.timestamp
        });

        emit RoundStarted(roundId, startTokenId);
    }

    function setTicketPrice(uint256 _ticketPrice) external onlyOwner {
        ticketPrice = _ticketPrice;
        emit TicketPriceUpdated(_ticketPrice);
    }

    function pauseRound(bool open) external onlyOwner {
        roundOpen = open;
    }

    
}
