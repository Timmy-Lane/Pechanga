// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bank is Ownable, ReentrancyGuard {
    mapping(address => uint256) public balances;
    address public gameManager;

    constructor() Ownable(msg.sender) {}

    modifier onlyGameManager() {
        require(msg.sender == gameManager, "You're not a Game Manager");
        _;
    }

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Debited(address indexed player, uint256 amount);
    event Credited(address indexed player, uint256 amount);
    event GameManagerUpdated(address indexed gm);

    function setGameManager(address gm) external onlyOwner {
        require(gm != address(0), "0 address");
        gameManager = gm;
        emit GameManagerUpdated(gm);
    }

    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Zero deposit");
        balances[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero withdraw");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw fail!");

        emit Withdrawn(msg.sender, amount);
    }

    function debit(address player, uint256 amount) external onlyGameManager {
        require(balances[player] >= amount, "Insufficient balance");
        balances[player] -= amount;
        emit Debited(player, amount);
    }

    function credit(address player, uint256 amount) external onlyGameManager {
        balances[player] += amount;
        emit Credited(player, amount);
    }

    function balanceOf(address player) external view returns (uint256) {
        return balances[player];
    }

    receive() external payable {
        revert("Use deposit()");
    }

    fallback() external payable {
        revert("Invalid call");
    }
}
