pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract MorpheusToken is ERC20Detailed, ERC20Mintable, Ownable {
    constructor() public ERC20Detailed("MorpheusGameToken", "MGT", 18) {}

    address gameControllerAddress;

    modifier onlyGameController() {
        require(msg.sender == gameControllerAddress);
        _;
    }

    function setGameControllerAddress(address _gameAddress) public onlyOwner() {
        gameControllerAddress = _gameAddress;
    }

    function burnTokens(uint256 _amount) public onlyGameController() {
        _burn(address(this), _amount);
    }

    function mintTokensForWinner(uint256 _amount) public onlyGameController() {
        _mint(address(this), _amount);
    }
}
