// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract Lottery{
    address[] public players;
    uint256 public roundId;
    address public owner;

    IERC20 public ticketToken;
    uint256 public ticketPrice;

    uint256 public constant TICKET_PRICE = 0.01 ether;
    uint256 public fee = 500;

    struct Round {
        address winner;
        uint256 potTokens;
        uint256 playersCount;
        uint256 timestamtp;
    }

    mapping(uint256 => Round) public rounds;

    event Enter(address indexed player, uint256 tickets, uint256 value, uint256 roundId);
    event WinnerPicked(address indexed winner, uint256 prize, uint256 roundId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _token, uint256 _ticketPrice){
        owner = msg.sender;
        roundId = 1;
        ticketToken = IERC20(_token);
        ticketPrice = _ticketPrice;
    }

    function enter() external payable{
        require(msg.value >= TICKET_PRICE, 'not enough eth, pay 0.01 eth');
        require(msg.value % TICKET_PRICE == 0, 'Send multiple of ticket price');

        uint256 tickets = msg.value / TICKET_PRICE;
        for(uint256 i = 0; i < tickets; i++){
            players.push(msg.sender);
        }

        emit Enter(msg.sender, tickets, msg.value, roundId);
    }

    function pickWinner() external onlyOwner returns(address winner){
        require(players.length > 0, 'Not enough players');

        uint256 pot = address(this).balance;
        uint256 newFee = (pot * fee) / 10_000;
        uint256 prize = pot - newFee;

        uint256 randomIndex = _random() % players.length;
        winner = players[randomIndex];

        

        delete players;
        roundId++;

        if(newFee > 0){
            (bool feeSent, ) = owner.call{value: newFee}("");
            require(feeSent, 'Fee transfer failed');
        }

        (bool prizeSent, ) = winner.call{value: prize}("");
        require(prizeSent, 'Prize transfer fail');

        emit WinnerPicked(winner, prize, roundId - 1);
    }

    function _random() private view returns (uint256){
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, players.length, address(this).balance)));
    }

    function playersCount() external view returns (uint256){
        return players.length;
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}