// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract Lottery is Ownable, ReentrancyGuard, VRFConsumerBaseV2{
    uint256 public ticketPrice;
    uint256 public creatorFeeBase;
    uint256 public currentRoundId;

    VRFCoordinatorV2Interface public coordinator;
    bytes32 public keyHash;
    uint64 public subId;
    uint32 public callbackGasLimit = 250_000;
    uint16 public reqConfirmations = 3;

    mapping(uint256 => uint256) public requestToRound;

    struct Round{
        uint256 pot;
        uint256 ticketsSold;
        address winner;
        uint256 randomWord;
        RoundStatus status;
        uint256 startedAt;
        uint256 finishedAt;
    }

    enum RoundStatus{
        Open,
        Awaiting,
        Finished
    }

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => address[]) public ticketsByRound;

    event RoundStarted(uint256 indexed roundId);
    event TicketsBought(uint256 indexed roundId, address indexed player, uint256 amount, uint256 value);
    event RoundClosed(uint256 indexed roundId, uint256 requestId);
    event WinnerSelected(uint256 indexed roundId, address indexed winner, uint256 prize, uint256 creatorFee, uint256 randomWord);
    event TicketPriceUpdated(uint256 newPrice);
    event HouseFeeUpdated(uint256 newFeeBase);

    error RoundNotOpen();
    error NoTicketsInRound();
    error RoundNotAwaitingVRF();
    error InvalidPayment();

    constructor(
        uint256 _ticketPrice,
        uint256 _creatorFeeBase,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    )
        Ownable(msg.sender)
        VRFConsumerBaseV2(_vrfCoordinator)
    {
        require(_creatorFeeBase <= 2000, "creator fee too high");
        ticketPrice = _ticketPrice;
        creatorFeeBase = _creatorFeeBase;

        coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subId = _subscriptionId;

        _startNewRound();
    }

    function buyTickets(uint256 ticketAmount) external payable nonReentrant{
        if(ticketAmount == 0) revert NoTicketsInRound();
        Round storage r = rounds[currentRoundId];
        if(r.status != RoundStatus.Open) revert RoundNotOpen();

        uint256 cost = ticketPrice * ticketAmount;
        if(msg.value != cost) revert InvalidPayment();

        address[] storage tickets = ticketsByRound[currentRoundId];
        for(uint256 i = 0; i < ticketAmount; i++){
            tickets.push(msg.sender);
        }

        r.pot += msg.value;
        r.ticketsSold += ticketAmount;

        emit TicketsBought(currentRoundId, msg.sender, ticketAmount, msg.value);
    }

    function closeRound() external onlyOwner returns (uint256 requestId) {
        Round storage r = rounds[currentRoundId];
        if (r.status != RoundStatus.Open) revert RoundNotOpen();
        if (r.ticketsSold == 0) revert NoTicketsInRound();

        r.status = RoundStatus.Awaiting;

        requestId = coordinator.requestRandomWords(
            keyHash,
            subId,
            reqConfirmations,
            callbackGasLimit,
            1
        );

        requestToRound[requestId] = currentRoundId;

        emit RoundClosed(currentRoundId, requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 roundId = requestToRound[requestId];
        Round storage r = rounds[roundId];
        if (r.status != RoundStatus.Awaiting) revert RoundNotAwaitingVRF();

        uint256 randomWord = randomWords[0];
        r.randomWord = randomWord;

        address[] storage tickets = ticketsByRound[roundId];
        uint256 winnerIndex = randomWord % tickets.length;
        address winner = tickets[winnerIndex];
        r.winner = winner;

        uint256 pot = r.pot;
        r.pot = 0;

        uint256 creatorFee = (pot * creatorFeeBase) / 10_000;
        uint256 prize = pot - creatorFee;

        r.status = RoundStatus.Finished;
        r.finishedAt = block.timestamp;

        if(creatorFee > 0){
            (bool okFee, ) = owner().call{value:creatorFee}("");
            require(okFee, 'creatorFee transfer failed');
        }

        (bool okWin, ) = winner.call{value: prize}("");
        require(okWin, 'winner transfer failed');

        emit WinnerSelected(roundId, winner, prize, creatorFee, randomWord);
        _startNewRound();
    }

    function _startNewRound() internal{
        currentRoundId += 1;

        Round storage r = rounds[currentRoundId];
        r.status = RoundStatus.Open;
        r.startedAt = block.timestamp;

        emit RoundStarted(currentRoundId);
    }

    function setTicketPrice(uint256 _ticketPrice) external onlyOwner {
        ticketPrice = _ticketPrice;
        emit TicketPriceUpdated(_ticketPrice);
    }

    function setCreatorFee(uint256 _creatorFeeBps) external onlyOwner {
        require(_creatorFeeBps <= 2000, "house fee too high");
        Round storage r = rounds[currentRoundId];
        require(r.status == RoundStatus.Awaiting, 'Close Round before change creator fee');
        creatorFeeBase = _creatorFeeBps;
        emit HouseFeeUpdated(_creatorFeeBps);
    }

    function setVRFConfig(
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) external onlyOwner {
        keyHash            = _keyHash;
        subId     = _subscriptionId;
        callbackGasLimit   = _callbackGasLimit;
        reqConfirmations = _requestConfirmations;
    }

    function getRoundTickets(uint256 roundId) external view returns (address[] memory) {
        return ticketsByRound[roundId];
    }

    function currentRound() external view returns (Round memory) {
        return rounds[currentRoundId];
    }
}
