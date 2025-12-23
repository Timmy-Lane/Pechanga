// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IBank {
    function debit(address player, uint256 amount) external;

    function credit(address player, uint256 amount) external;
}

contract GameManager is Ownable {
    address public bank;

    mapping(address => bool) public isGameRegistered;

    event GameRegistered(address indexed game, bool enabled);
    event BankUpdated(address indexed oldBank, address indexed newBank);
    event PlayerDebited(
        address indexed game,
        address indexed player,
        uint256 amount
    );
    event PlayerCredited(
        address indexed game,
        address indexed player,
        uint256 amount
    );

    modifier onlyGame() {
        require(
            isGameRegistered[msg.sender],
            "GameManager: caller not registered game"
        );
        _;
    }

    constructor(address _bank, address _initialOwner) Ownable(_initialOwner) {
        require(_bank != address(0), "Invalid bank");
        bank = _bank;
        emit BankUpdated(address(0), _bank);
    }

    function setGame(address game, bool enabled) external onlyOwner {
        require(game != address(0), "GameManager: game address is zero");
        isGameRegistered[game] = enabled;
        emit GameRegistered(game, enabled);
    }

    function setGames(
        address[] calldata games,
        bool enabled
    ) external onlyOwner {
        uint256 len = games.length;
        for (uint256 i = 0; i < len; ++i) {
            require(
                games[i] != address(0),
                "GameManager: game address is zero"
            );
            isGameRegistered[games[i]] = enabled;
            emit GameRegistered(games[i], enabled);
        }
    }

    function setBank(address newBank) external onlyOwner {
        require(newBank != address(0), "GameManager: bank address zero");
        bank = newBank;
        emit BankUpdated(bank, newBank);
    }

    function debitPlayer(address player, uint256 amount) external onlyGame {
        require(player != address(0), "GameManager: player address zero");
        require(amount > 0, "GameManager: zero amount");
        IBank(bank).debit(player, amount);
        emit PlayerDebited(msg.sender, player, amount);
    }

    function creditPlayer(address player, uint256 amount) external onlyGame {
        require(player != address(0), "GameManager: player address zero");
        require(amount > 0, "GameManager: zero amount");
        IBank(bank).credit(player, amount);
        emit PlayerCredited(msg.sender, player, amount);
    }

    function isGame(address game) external view returns (bool) {
        return isGameRegistered[game];
    }

    function getBank() external view returns (address) {
        return bank;
    }
}
