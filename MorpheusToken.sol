pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Capped.sol";

contract MorpheusToken is ERC20, ERC20Detailed, ERC20Capped {
    
    address public deployerAddress;
    address public gameControllerAddress;
    
    bool public locked; 
    
    constructor(address _deployer) public ERC20Detailed("MorpheusGameToken", "MGT", 18) ERC20Capped(500000000*1E18) {
              deployerAddress =_deployer;
              locked = true;
    }

    modifier onlyGameController() {
        require(msg.sender == gameControllerAddress);
        _;
    }
    
    modifier onlyDeployer() {
        require(msg.sender == deployerAddress);
        _;
    }
    
    // Function who will be called after the init of gameControllerAddress
    // After this, token won't have any other controller
    function eraseDeployerAddress() public onlyDeployer(){
        deployerAddress = address(0x0);
    }
    
    
    // Tokens will be locked untill the liquity added in uniswap
    function unlock() public onlyDeployer {
        locked = false;
    } 

    function lock() public onlyDeployer {
        locked = true;
    }
    
    function transfer(address to, uint256 amount) public returns(bool) {
        if(locked) {
            require(msg.sender == deployerAddress);
            super.transfer(to, amount);
        } else{
            super.transfer(to, amount);
        }

    }

    function transferFrom(address from, address to, uint256 amount) public returns(bool) {
        if(locked) {
            require(msg.sender == deployerAddress);
            super.transferFrom(from, to, amount);
        } else{
            super.transferFrom(from, to, amount); 
        }

    }

    function setGameControllerAddress(address _gameAddress) public onlyDeployer {
        gameControllerAddress = _gameAddress;
    }

    function burnTokens(uint256 _amount) public  {
        _burn(msg.sender, _amount);
    }

    // This is the function used by the gameController Contract for minting token who will be send to the user
    // ONLY GameController can call this function.
    // AND the gameController have only one reference to THIS function (line 288 in GameController.sol):
    // In the __callback()  (line 228 in GameController.sol) 
    // This __callback() function can only be called by provableAPI Address. This meens that only return of ORACLE can return a token minting
    function mintTokensForWinner(uint256 _amount) public onlyGameController() {
        _mint(gameControllerAddress, _amount);
    }
}
