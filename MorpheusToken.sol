pragma solidity ^0.5.0;

//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC20/ERC20.sol";
import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Mintable.sol";

contract MorpheusToken is ERC20, ERC20Detailed, ERC20Mintable {
    
    address public deployerAddress;
    address public gameControllerAddress;
    
    constructor(address _deployer) public ERC20Detailed("MorpheusGameToken", "MGT", 18) {
              deployerAddress =_deployer;
    }

    modifier onlyGameController() {
        require(msg.sender == gameControllerAddress);
        _;
    }
    
    modifier onlyDeployer() {
        require(msg.sender == deployerAddress);
        _;
    }
    
    function eraseDeployerAddress() public onlyDeployer(){
        deployerAddress = address(0x0);
    }

    function setGameControllerAddress(address _gameAddress) public onlyDeployer {
        gameControllerAddress = _gameAddress;
    }

    function burnTokens(uint256 _amount) public  {
        _burn(msg.sender, _amount);
    }

    function mintTokensForWinner(uint256 _amount) public onlyGameController() {
        _mint(gameControllerAddress, _amount);
    }
}
