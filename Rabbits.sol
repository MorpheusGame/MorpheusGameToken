pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract Rabbits is ERC721Full, ERC721Burnable, Ownable {
    // All 160 Rabbits got color White, Blue and Red
    mapping(uint256 => string) public colorRabbit;

    // Only gameAddress can mint Rabbits
    address public gameControllerAddress;

    constructor() public ERC721Full("RabbitsToken", "RBTS") {
        // Rabbits Colors init

        // id 0 to 9 (10 Rabbits) are "White Rabbits"
        for (uint8 i = 0; i < 9; i++) {
            colorRabbit[i] = "White";
        }

        // id 10 to 59 (50 Rabbits) are "Blue Rabbits"
        for (uint8 i = 10; i < 59; i++) {
            colorRabbit[i] = "Blue";
        }

        // id 60 to 159 (100 Rabbits) are "Red Rabbits"
        for (uint8 i = 60; i < 159; i++) {
            colorRabbit[i] = "Red";
        }
    }

    modifier onlyGameController() {
        require(msg.sender == gameControllerAddress);
        _;
    }

    // events for prevent Players from any change
    event GameAddressChanged(address newGameAddress);

    // init game smart contract address
    function setGameAddress(address _gameAddress) public onlyOwner() {
        gameControllerAddress = _gameAddress;
        emit GameAddressChanged(_gameAddress);
    }

    // Function that only game smart contract address can call for mint a Rabbit
    function mintRabbit(address _to, uint256 _id) public onlyGameController() {
        _mint(_to, _id);
    }

    // Function that only game smart contract address can call for burn Rabbits trilogy
    function burnRabbitsTrilogy(
        address _ownerOfRabbit,
        uint256 _id1,
        uint256 _id2,
        uint256 _id3
    ) public onlyGameController() {
        require(
            keccak256(abi.encodePacked(colorRabbit[_id1])) ==
                keccak256(abi.encodePacked("White")) &&
                keccak256(abi.encodePacked(colorRabbit[_id2])) ==
                keccak256(abi.encodePacked("Blue")) &&
                keccak256(abi.encodePacked(colorRabbit[_id3])) ==
                keccak256(abi.encodePacked("Red"))
        );
        _burn(_ownerOfRabbit, _id1);
        _burn(_ownerOfRabbit, _id2);
        _burn(_ownerOfRabbit, _id3);
    }
}
