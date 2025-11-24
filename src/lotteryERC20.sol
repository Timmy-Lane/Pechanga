// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LotteryERC20 {
    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);

    constructor(string memory _name, string memory _symbol, uint initialSupply) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, initialSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function mint(address to, uint amount) external onlyOwner {
        _mint(to, amount);
    }

    function transfer(address to, uint amount) external returns (bool){
        require(balanceOf[msg.sender] >= amount, 'Not enough balance');
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint amount) external returns (bool){
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint amount) external returns (bool){
        require(balanceOf[msg.sender] >= amount, 'Not enough balance');
        require(allowance[from][msg.sender] >= amount, 'Not allowed');

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint amount) internal{
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
