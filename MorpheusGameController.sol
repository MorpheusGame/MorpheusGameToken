pragma solidity 0.5.17;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./provableAPI.sol";
import "./MorpheusToken.sol";
import "./Rabbits.sol";

contract MorpheusGameController is Ownable, usingProvable {
    using SafeMath for uint256;

    MorpheusToken public morpheus;
    Rabbits public rabbits;

    constructor(MorpheusToken _morpheusToken) public {
        morpheus = _morpheusToken;
    }

    uint256 public lastRewardTime;
    uint256 public rewardPool;
    uint256 public totalRewardPart;

    address[] private _playersFromPeriod;

    address[] private _matrixHolders;

    mapping(address => uint256) public myRewardPart;
    mapping(address => uint256) public myRewardTokens;

    mapping(address => uint256) public myPeriodLoss;
    mapping(address => uint256) public myPeriodBets;

    address public kingOfTheMountain;
    address public kingOfLoosers;

    event alertEvent(string alert);
    event winAlert(address winner, uint256 amount);
    event lostAlert(address looser, uint256 amount);
    event rewardClaimed(address claimer, uint256 value);

    // =========================================================================================
    // Settings Functions
    // =========================================================================================

    function setMatrix(
        address _matrix1,
        address _matrix2,
        address _matrix3
    ) public onlyOwner() {
        _matrixHolders.push(_matrix1);
        _matrixHolders.push(_matrix2);
        _matrixHolders.push(_matrix3);
    }

    // =========================================================================================
    // Play Functions
    // =========================================================================================

    // Frontend will send the color choice of player. For code simplicity,
    // the color is hard coding by a number value
    // Blue is 0 and Red is 1

    struct gameInstance {
        address player;
        uint8 choice;
        uint256 amount;
    }

    mapping(bytes32 => gameInstance) gamesInstances;

    function choosePils(uint256 _amount, uint8 _choice) public payable {
        require(
            _amount > 0 &&
                morpheus.balanceOf(msg.sender) > _amount &&
                msg.value > 10 finney
        );
        morpheus.transferFrom(msg.sender, address(this), _amount);
        _addPlayerToList(msg.sender);
        myPeriodBets[msg.sender] = myPeriodBets[msg.sender].add(_amount);

        if (myPeriodBets[msg.sender] > myPeriodBets[kingOfTheMountain]) {
            kingOfTheMountain = msg.sender;
        }

        // get random with provable (arg1: delay, arg2: uintSize, arg3: GasPrice)
        bytes32 _id = provable_newRandomDSQuery(1, 8, 2000000);
        gamesInstances[_id] = gameInstance(msg.sender, _choice, _amount);
    }

    function __callback(
        bytes32 _id,
        string memory _result,
        bytes memory _proof
    ) public {
        require(msg.sender == provable_cbAddress());

        gameInstance storage GameInstance = gamesInstances[_id];

        if (
            provable_randomDS_proofVerify__returnCode(_id, _result, _proof) != 0
        ) {
            //proof is bad
            //return original payment to player
            morpheus.transferFrom(
                address(this),
                GameInstance.player,
                GameInstance.amount
            );
            emit alertEvent("Provable Random is corrupted");
        } else {
            //proof is good
            require(GameInstance.player != address(0x0));

            uint8 randomColor = uint8(
                uint256(keccak256(abi.encodePacked(_result)))
            ) % 2;

            if (randomColor == GameInstance.choice) {
                morpheus.mintTokensForWinner(GameInstance.amount);
                morpheus.transferFrom(
                    address(this),
                    GameInstance.player,
                    GameInstance.amount.mul(2)
                );
                emit winAlert(GameInstance.player, GameInstance.amount.mul(2));
            } else {
                myPeriodLoss[GameInstance.player] = myPeriodLoss[GameInstance
                    .player]
                    .add(GameInstance.amount);

                if (myPeriodLoss[msg.sender] > myPeriodLoss[kingOfLoosers]) {
                    kingOfLoosers = msg.sender;
                }

                uint256 _totalRewards = rewardPool;
                rewardPool = _totalRewards.add(GameInstance.amount);


                    uint256 _tempPersonnalProportionnalReward
                 = myRewardPart[GameInstance.player];

                myRewardPart[GameInstance
                    .player] = _tempPersonnalProportionnalReward.add(
                    myRewardPart[GameInstance.player]
                );

                emit lostAlert(GameInstance.player, GameInstance.amount);
            }
            delete gamesInstances[_id];
        }
    }

    function _addPlayerToList(address _player) internal {
        require(!_isPlayerInList(_player));
        _playersFromPeriod.push(_player);
    }

    function _isPlayerInList(address _player) internal view returns (bool) {
        bool exist = false;
        for (uint8 i = 0; i < _playersFromPeriod.length; i++) {
            if (_playersFromPeriod[i] == _player) {
                exist = true;
                break;
            }
        }
        return exist;
    }

    // =========================================================================================
    // Rewards Functions
    // =========================================================================================

    function claimRewards() public {
        require(rewardPool > 0);

        // Security re entry
        uint256 _rewardPool = rewardPool;
        rewardPool = 0;
        lastRewardTime = now;

        // First Burning
        uint8 burnPercentage = _getBurnPercentage();
        uint256 totalToBurn = (_rewardPool.mul(burnPercentage)).div(100);
        morpheus.burnTokens(totalToBurn);

        // Update temp reward pool
        _rewardPool = _rewardPool.sub(totalToBurn);

        // Matrix rewards 4%
        uint256 rewardForMatrix = (
            (_rewardPool.mul(4)).div(100).sub((_rewardPool.mul(4)).div(100) % 3)
        );
        _transferToMatrixHolders(rewardForMatrix);

        // rewarding claimer 5%
        uint256 rewardForClaimer = (_rewardPool.mul(5)).div(100);
        morpheus.transfer(msg.sender, rewardForClaimer);

        // rewarding kings
        uint256 rewardForKings = (_rewardPool.mul(1)).div(100);
        _transferToKingOfMountain(rewardForKings);
        _transferToKingOfLoosers(rewardForKings);

        // update _rewardPool
        _rewardPool = _rewardPool.sub(rewardForClaimer);
        _rewardPool = _rewardPool.sub(rewardForMatrix);
        _rewardPool = _rewardPool.sub(rewardForKings);
        _rewardPool = _rewardPool.sub(rewardForKings);

        // Update rewards and refresh period .
        _setRewards(_rewardPool);
        _deleteAllPlayersFromPeriod();
    }

    function claimMyReward() public {
        require(myRewardTokens[msg.sender] > 0);
        uint256 _myRewardTokens = myRewardTokens;
        myRewardTokens = 0;
        morpheus.transferFrom(
            address(this),
            msg.sender,
            myRewardTokens[msg.sender]
        );
    }

    function _getBurnPercentage() internal view returns (uint8) {
        if (now.sub(lastRewardTime) < 1 days) {
            return 80;
        }
        if (now.sub(lastRewardTime) < 2 days) {
            return 70;
        }
        if (now.sub(lastRewardTime) < 3 days) {
            return 60;
        }
        if (now.sub(lastRewardTime) < 4 days) {
            return 50;
        }
        if (now.sub(lastRewardTime) < 5 days) {
            return 30;
        }
        if (now.sub(lastRewardTime) < 6 days) {
            return 15;
        }
        if (now.sub(lastRewardTime) < 7 days) {
            return 0;
        }
    }

    function _setRewards(uint256 _rewardAmmount) internal {
        require(_playersFromPeriod.length > 0);
        for (uint8 i = 0; i < _playersFromPeriod.length; i++) {
            uint256 personnalReward = (
                _rewardAmmount.mul(myRewardPart[_playersFromPeriod[i]])
            )
                .div(totalRewardPart);
            myRewardTokens[_playersFromPeriod[i]] = personnalReward;
            myRewardPart[_playersFromPeriod[i]] = 0;
        }
        totalRewardPart = 0;
    }

    function _deleteAllPlayersFromPeriod() internal {
        for (uint256 i = _playersFromPeriod.length - 1; i > 0; i--) {
            myPeriodLoss[_playersFromPeriod[i]];
            myPeriodBets[_playersFromPeriod[i]];
            delete _playersFromPeriod[i];
        }
    }

    function _transferToMatrixHolders(uint256 _amount) internal {
        uint256 _toTransfer = _amount.div(3);
        morpheus.transferFrom(address(this), _matrixHolders[0], _toTransfer);
        morpheus.transferFrom(address(this), _matrixHolders[1], _toTransfer);
        morpheus.transferFrom(address(this), _matrixHolders[2], _toTransfer);
    }

    function _transferToKingOfMountain(uint256 _amount) internal {
        morpheus.transferFrom(address(this), kingOfTheMountain, _amount);
        kingOfTheMountain = address(0x0);
    }

    function _transferToKingOfLoosers(uint256 _amount) internal {
        morpheus.transferFrom(address(this), kingOfLoosers, _amount);
        kingOfLoosers = address(0x0);
    }

    // =========================================================================================
    // Rabbits Functions
    // =========================================================================================

    function superClaim(
        uint256 _id1,
        uint256 _id2,
        uint256 _id3
    ) public {
        require(rewardPool > 0);
        require(
            rabbits.ownerOf(_id1) == msg.sender &&
                rabbits.ownerOf(_id2) == msg.sender &&
                rabbits.ownerOf(_id2) == msg.sender
        );
        uint256 _rewardPool = rewardPool;
        rewardPool = 0;
        lastRewardTime = now;
        morpheus.burnTokens(_rewardPool.div(2));
        morpheus.transfer(msg.sender, _rewardPool.div(2));
        rabbits.burnRabbitsTrilogy(msg.sender, _id1, _id2, _id3);
        _setRewards(0);
        _deleteAllPlayersFromPeriod();
    }

    //function claimMyRabbit()
}
