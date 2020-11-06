pragma solidity 0.5.17;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./provableAPI.sol";
import "./MorpheusToken.sol";
import "./Rabbits.sol";

contract MorpheusGameController is Ownable, usingProvable {
    using SafeMath for uint256;

    // Tokens used in game
    MorpheusToken public morpheus;
    Rabbits public rabbits;

    // Rewards
    uint256 private _lastRewardTime;
    // Total quantity of tokens in the reward pool
    uint256 private _rewardPool;
    // Total reward part, used for calculate proportion reward for users
    uint256 private _totalRewardPart;

    // number of period / claim
    uint256 private _numberOfPeriod;

    // Total valuePlayed
    uint256 private _totalValuePlayed;

    // All players from a period between 2 claims
    // Reload each time globalClaim is activated
    address[] private _playersFromPeriod;

    // Addresses of MatrixRunners
    address[] private _matrixRunners;

    // Reward part for each players, used for calculate proportion reward
    mapping(address => uint256) private _myRewardPart;
    // Reward that player can claim
    mapping(address => uint256) private _myRewardTokens;

    // Values used for calculate who are Kings
    mapping(address => uint256) private _myPeriodLoss;
    mapping(address => uint256) private _myPeriodBets;

    // King ot the mountain is the player who have done the most bets value in a period
    // There is only one King of the mountain, if someone got the same bets value,
    // he can't dethrone the king, only a bigger bets value can dethrone the actual king
    address public kingOfTheMountain;
    // Same logic for King of Loosers who is the player who lost the most value
    address public kingOfLoosers;
    uint256 public valueLostByKingOfLoosers;

    event alertEvent(string alert);
    event winAlert(address winner, uint256 amount);
    event lostAlert(address looser, uint256 amount);
    event rewardClaimed(
        address claimer,
        uint256 claimerGain,
        uint256 burntValue
    );

    // =========================================================================================
    // Settings Functions
    // =========================================================================================

    function setMatrix(
        address _matrix1,
        address _matrix2,
        address _matrix3
    ) public onlyOwner() {
        _matrixRunners.push(_matrix1);
        _matrixRunners.push(_matrix2);
        _matrixRunners.push(_matrix3);
    }

    function setMorpheusToken(MorpheusToken _morpheusToken) public onlyOwner() {
        morpheus = _morpheusToken;
    }

    function setRabbitsToken(Rabbits _rabbits) public onlyOwner() {
        rabbits = _rabbits;
    }

    // =========================================================================================
    // Get Functions
    // =========================================================================================

    function getGameData()
        public
        view
        returns (
            uint256 totalPeriod,
            uint256 totalValuePlayed,
            uint256 totalPart,
            uint256 lastRewardTime,
            uint256 actualPool,
            uint256 totalPlayersForThosePeriod
        )
    {
        return (
            _numberOfPeriod,
            _totalValuePlayed,
            _totalRewardPart,
            _lastRewardTime,
            _rewardPool,
            _playersFromPeriod.length
        );
    }

    function getPersonnalData(address _user)
        public
        view
        returns (
            uint256 myRewardPart,
            uint256 myRewardTokens,
            uint256 myPeriodLoss,
            uint256 myPeriodBets
        )
    {
        return (
            _myRewardPart[_user],
            _myRewardTokens[_user],
            _myPeriodLoss[_user],
            _myPeriodBets[_user]
        );
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
        // We need some GAS for get a true random number giving by provable API
        require(
            _amount > 0 &&
                morpheus.balanceOf(msg.sender) > _amount &&
                msg.value > 10 finney
        );
        morpheus.transferFrom(msg.sender, address(this), _amount);
        _addPlayerToList(msg.sender);
        _totalValuePlayed = _totalValuePlayed.add(_amount);

        _myPeriodBets[msg.sender] = _myPeriodBets[msg.sender].add(_amount);

        if (_myPeriodBets[msg.sender] > _myPeriodBets[kingOfTheMountain]) {
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
                _myPeriodLoss[GameInstance.player] = _myPeriodLoss[GameInstance
                    .player]
                    .add(GameInstance.amount);

                if (_myPeriodLoss[msg.sender] > _myPeriodLoss[kingOfLoosers]) {
                    kingOfLoosers = msg.sender;
                }

                uint256 _totalRewards = _rewardPool;
                _rewardPool = _totalRewards.add(GameInstance.amount);


                    uint256 _tempPersonnalProportionnalReward
                 = _myRewardPart[GameInstance.player];

                _myRewardPart[GameInstance
                    .player] = _tempPersonnalProportionnalReward.add(
                    _myRewardPart[GameInstance.player]
                );

                emit lostAlert(GameInstance.player, GameInstance.amount);
                _setKingOfLoosers();
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

    function _setKingOfLoosers() internal {
        address _kingOfLoosers;
        uint256 _valueLost = 0;
        for (uint256 i = 0; i < _playersFromPeriod.length; i++) {
            if (
                _myPeriodBets[_playersFromPeriod[i]].div(2) <
                _myPeriodLoss[_playersFromPeriod[i]]
            ) {
                uint256 _lostByi = _myPeriodLoss[_playersFromPeriod[i]].sub(
                    _myPeriodBets[_playersFromPeriod[i]].div(2)
                );
                if (_valueLost < _lostByi) {
                    _valueLost = _lostByi;
                    _kingOfLoosers = _playersFromPeriod[i];
                }
            }
        }
        kingOfLoosers = _kingOfLoosers;
        valueLostByKingOfLoosers = _valueLost;
    }

    // =========================================================================================
    // Rewards Functions
    // =========================================================================================

    function claimRewards() public {
        require(_rewardPool > 0);

        // Security re entry
        uint256 _tempRewardPool = _rewardPool;
        _rewardPool = 0;
        _lastRewardTime = now;

        _numberOfPeriod = _numberOfPeriod.add(1);

        // First rewarding kings
        uint256 rewardForKings = (_tempRewardPool.mul(1)).div(100);
        _transferToKingOfMountain(rewardForKings);
        _transferToKingOfLoosers(rewardForKings);

        // updating reward pool
        _tempRewardPool = _tempRewardPool.sub(rewardForKings);
        _tempRewardPool = _tempRewardPool.sub(rewardForKings);

        // then Burning
        uint8 burnPercentage = _getBurnPercentage();
        uint256 totalToBurn = (_tempRewardPool.mul(burnPercentage)).div(100);
        morpheus.burnTokens(totalToBurn);

        // Update temp reward pool
        _tempRewardPool = _tempRewardPool.sub(totalToBurn);

        // Matrix rewards 4%
        uint256 rewardForMatrix = (
            (_tempRewardPool.mul(4)).div(100).sub(
                (_tempRewardPool.mul(4)).div(100) % 3
            )
        );
        _transferToMatrixRunners(rewardForMatrix);

        // rewarding claimer 5%
        uint256 rewardForClaimer = (_tempRewardPool.mul(5)).div(100);
        morpheus.transfer(msg.sender, rewardForClaimer);

        // update _rewardPool
        _tempRewardPool = _tempRewardPool.sub(rewardForClaimer);
        _tempRewardPool = _tempRewardPool.sub(rewardForMatrix);

        // Update rewards and refresh period .
        _setRewards(_tempRewardPool);
        _deleteAllPlayersFromPeriod();

        emit rewardClaimed(msg.sender, rewardForClaimer, totalToBurn);
    }

    function claimMyReward() public {
        require(_myRewardTokens[msg.sender] > 0);
        uint256 _myTempRewardTokens = _myRewardTokens[msg.sender];
        _myRewardTokens[msg.sender] = 0;
        morpheus.transferFrom(address(this), msg.sender, _myTempRewardTokens);
    }

    function _getBurnPercentage() internal view returns (uint8) {
        uint256 _timeSinceLastReward = now.sub(_lastRewardTime);
        uint8 _burnPercentage = 80;

        if (_timeSinceLastReward > 1 days && _timeSinceLastReward < 2 days) {
            _burnPercentage = 70;
        }
        if (_timeSinceLastReward >= 2 days && _timeSinceLastReward < 3 days) {
            _burnPercentage = 60;
        }
        if (_timeSinceLastReward >= 3 days && _timeSinceLastReward < 4 days) {
            _burnPercentage = 50;
        }
        if (_timeSinceLastReward >= 4 days && _timeSinceLastReward < 5 days) {
            _burnPercentage = 40;
        }
        if (_timeSinceLastReward >= 5 days && _timeSinceLastReward < 6 days) {
            _burnPercentage = 25;
        }
        if (_timeSinceLastReward >= 6 days && _timeSinceLastReward < 7 days) {
            _burnPercentage = 10;
        }
        if (_timeSinceLastReward >= 7 days) {
            _burnPercentage = 3;
        }
        return _burnPercentage;
    }

    function _setRewards(uint256 _rewardAmmount) internal {
        require(_totalRewardPart > 0 && _playersFromPeriod.length > 0);
        // Reentry secure
        uint256 _tempTotalRewardPart = _totalRewardPart;
        _totalRewardPart = 0;

        for (uint8 i = 0; i < _playersFromPeriod.length; i++) {
            if (_myRewardPart[_playersFromPeriod[i]] > 0) {
                // Reentry secure


                    uint256 _myTempRewardPart
                 = _myRewardPart[_playersFromPeriod[i]];
                _myRewardPart[_playersFromPeriod[i]] = 0;


                    uint256 _oldPersonnalReward
                 = _myRewardTokens[_playersFromPeriod[i]];
                _myRewardTokens[_playersFromPeriod[i]] = 0;

                // Calculate personnal reward to add
                uint256 personnalReward = (
                    _rewardAmmount.mul(_myTempRewardPart)
                )
                    .div(_tempTotalRewardPart);

                // Calculate personnal reward to add
                _myRewardTokens[_playersFromPeriod[i]] = _oldPersonnalReward
                    .add(personnalReward);
            }
        }
    }

    function _deleteAllPlayersFromPeriod() internal {
        for (uint256 i = _playersFromPeriod.length - 1; i > 0; i--) {
            _myPeriodLoss[_playersFromPeriod[i]];
            _myPeriodBets[_playersFromPeriod[i]];
            delete _playersFromPeriod[i];
        }
    }

    function _transferToMatrixRunners(uint256 _amount) internal {
        uint256 _toTransfer = _amount.div(3);
        morpheus.transferFrom(address(this), _matrixRunners[0], _toTransfer);
        morpheus.transferFrom(address(this), _matrixRunners[1], _toTransfer);
        morpheus.transferFrom(address(this), _matrixRunners[2], _toTransfer);
    }

    function _transferToKingOfMountain(uint256 _amount) internal {
        require(kingOfTheMountain != address(0x0));
        // Re entry secure
        address _kingOfTheMountain = kingOfTheMountain;
        kingOfTheMountain = address(0x0);

        morpheus.transferFrom(address(this), _kingOfTheMountain, _amount);
    }

    function _transferToKingOfLoosers(uint256 _amount) internal {
        require(kingOfLoosers != address(0x0));
        // Re entry secure
        address _kingOfLoosers = kingOfLoosers;
        kingOfTheMountain = address(0x0);

        morpheus.transferFrom(address(this), _kingOfLoosers, _amount);
    }

    // =========================================================================================
    // Rabbits Functions
    // =========================================================================================

    function superClaim(
        uint256 _id1,
        uint256 _id2,
        uint256 _id3
    ) public {
        require(_rewardPool > 0);
        require(
            rabbits.ownerOf(_id1) == msg.sender &&
                rabbits.ownerOf(_id2) == msg.sender &&
                rabbits.ownerOf(_id2) == msg.sender
        );
        uint256 _tempRewardPool = _rewardPool;
        _rewardPool = 0;
        _numberOfPeriod = _numberOfPeriod.add(1);
        _lastRewardTime = now;
        morpheus.burnTokens(_tempRewardPool.div(2));
        morpheus.transfer(msg.sender, _tempRewardPool.div(2));
        rabbits.burnRabbitsTrilogy(msg.sender, _id1, _id2, _id3);
        _setRewards(0);
        _deleteAllPlayersFromPeriod();
    }

    //function claimMyRabbit()
}
