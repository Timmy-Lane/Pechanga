// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Chip is ERC20, Ownable, Pausable {
    mapping(address => bool) blacklist;

    event Blacklisted(address indexed account, bool isBlacklisted);
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    modifier notBlacklisted(address account) {
        require(!blacklist[account], "CHIP: address is blacklisted");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address initialOwner
    ) ERC20(_name, _symbol) Ownable(initialOwner) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
        emit Burned(from, amount);
    }

    function _update(
        address to,
        address from,
        uint256 value
    ) internal override whenNotPaused notBlacklisted(from) notBlacklisted(to) {
        super._update(from, to, value);
    }

    function setBlacklist(address account, bool value) external onlyOwner {
        blacklist[account] = value;
        emit Blacklisted(account, value);
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function pause() external onlyOwner {
        _pause();
    }

    receive() external payable {
        revert("No ether accepted");
    }

    fallback() external payable {
        revert("No ether accepted");
    }
}
