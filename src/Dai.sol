pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDai {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
}

contract Dai is ERC20, Ownable {
    constructor() ERC20("Dai", "DAI") Ownable(msg.sender) {}

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }
}