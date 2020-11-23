pragma solidity 0.5.17;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./provableAPI.sol";
import "./MorpheusToken.sol";
import "./Rabbits.sol";

// GameController Contract

contract MorpheusGameController is Ownable, usingProvable {
    using SafeMath for uint256;
    
        constructor(MorpheusToken _morpheusToken)
        public
    {
        //init matrix holder 1 
        setMatrix(msg.sender);
        //init Morpheus token address
        setMorpheusToken(_morpheusToken);
        // init first instance of game
        _lastRewardTime = now;
        beginningTime = now;
        provable_setProof(proofType_Ledger);
    }

    // Tokens used in game
    MorpheusToken public morpheus;
    Rabbits public rabbits;
    
    // Beginning game time
    uint256 public beginningTime;

    // Rewards
    uint256 private _lastRewardTime;
    // Total quantity of tokens in the reward pool
    uint256 private _rewardPool;
    // Total reward part, used for calculate proportion reward for users
    uint256 private _totalRewardPart;

    // number of period / claim
    uint256 private _numberOfPeriod = 1;

    // Total value played
    uint256 private _totalValuePlayed;
    // Total value burned
    uint256 private _totalValueBurned;
    
    // Total period value played
    uint256 private _totalValuePlayedOnPeriod;
    
    //Minimum balance you need to activate claim function
    uint256 public minimumBalanceForClaim = 10000*1E18;

    // All players from a period between 2 claims
    // Reload each time globalClaim is activated
    address[] public _playersFromPeriod;

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

    // alert event needed for alert of any provableAPI problem
    event alertEvent(string alert);
    
    
    event winAlert(address winner, uint256 amount);
    event lostAlert(address looser, uint256 amount);
    event rewardClaimed(
        address claimer,
        uint256 claimerGain,
        uint256 burntValue
    );
    event newKingOfTheMountain(address king);
    event gotAPlayer(address _player, bytes32 _id);
    event gotAResult(bytes32 _id, uint8 _result);
    
    
    // =========================================================================================
    // TESTS Functions
    // =========================================================================================
 
   // Play function without random for testing contract
 /*   function play(uint256 amount, uint8 _choice) public {
        uint256 _amount = amount * 1E18;
        require(morpheus.balanceOf(msg.sender) >= _amount);

        //first transfer amount of playing tokens
        morpheus.transferFrom(msg.sender, address(this), _amount);

        // Add player to list
        if (!_isPlayerInList(msg.sender)) {
            _playersFromPeriod.push(msg.sender);
        }

        // Update total value played by all players
        _totalValuePlayed = _totalValuePlayed.add(_amount);

        _totalValuePlayedOnPeriod = _totalValuePlayedOnPeriod.add(_amount);

        // Update value of total played by the player
        _myPeriodBets[msg.sender] = _myPeriodBets[msg.sender].add(_amount);

        // Update king of the mountain if needed
        if (_myPeriodBets[msg.sender] > _myPeriodBets[kingOfTheMountain]) {
            kingOfTheMountain = msg.sender;
            emit newKingOfTheMountain(msg.sender);
        }

        if ((now % 2) == _choice) {
            //Mint token in contract
            morpheus.mintTokensForWinner(_amount);
            //Then send it to player
            morpheus.transfer(msg.sender, _amount.mul(2));
            emit winAlert(msg.sender, _amount.mul(2));
        } else {
            // Update loss of player
            _myPeriodLoss[msg.sender] = _myPeriodLoss[msg.sender].add(_amount);

            // Update reward pool
            _rewardPool = _rewardPool.add(_amount);

            //Update total part
            _totalRewardPart = _totalRewardPart.add(_amount);

            // Update personnal Proportionnal reward (counter) for player
            _myRewardPart[msg.sender] = _myRewardPart[msg.sender].add(_amount);

            emit lostAlert(msg.sender, _amount);
        }
    }

    
    */
    

    

    // =========================================================================================
    // Settings Functions
    // =========================================================================================

    // set matrix Runners Addresses
    function setMatrix(address _matrixRunner) public onlyOwner() {
        _matrixRunners.push(_matrixRunner);
    }
    

    // Set the MorpheusToken address
    function setMorpheusToken(MorpheusToken _morpheusToken) public onlyOwner() {
        morpheus = _morpheusToken;
        emit alertEvent("Morpheus token has been set");
    }

    // Set the RabbitToken address
    function setRabbitsToken(Rabbits _rabbits) public onlyOwner() {
        rabbits = _rabbits;
        emit alertEvent("Rabbits token has been set");
    }
    
    // set minimum balance for claimerGain
    function setMinimumBalanceForClaim(uint256 _amount) public onlyOwner() {
        minimumBalanceForClaim = _amount * 1E18;
        emit alertEvent("Minimum balance for claim has been updated");
    }

    // =========================================================================================
    // Get Functions
    // =========================================================================================

    // Get game infos
    function getGameData()
        public
        view
        returns (
            uint256 totalPeriod,
            uint256 totalValuePlayed,
            uint256 totalValuePlayedOnPeriod,
            uint256 totalValueBurned,
            uint256 totalPart,
            uint256 lastRewardTime,
            uint256 actualPool,
            uint256 totalPlayersForThosePeriod
        )
    {
        return (
            _numberOfPeriod,
            _totalValuePlayed,
            _totalValuePlayedOnPeriod,
            _totalValueBurned,
            _totalRewardPart,
            _lastRewardTime,
            _rewardPool,
            _playersFromPeriod.length
        );
    }

    // Get personnal game infos
    function getPersonnalData(address _user)
        public
        view
        returns (
            uint256 playerRewardPart,
            uint256 playerRewardTokens,
            uint256 playerPeriodLoss,
            uint256 playerPeriodBets
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

    function choosePils(uint256 amount, uint8 _choice) public payable {
        uint256 _amount = amount*1E18;
        // We need some GAS for get a true random number provided by provable API
        require(msg.value == 4 finney);
        // Need to have found amount
        require(_amount > 0 && morpheus.balanceOf(msg.sender) > _amount);
        // 0 = Blue or 1 = Red
        require(_choice == 0 || _choice == 1 );

        // First transfer tokens played in the contract
        morpheus.transferFrom(msg.sender, address(this), _amount);
         
        // Add player to list
        if(!_isPlayerInList(msg.sender)){
          _playersFromPeriod.push(msg.sender);
        }

        // Update total value played by all players
        _totalValuePlayed = _totalValuePlayed.add(_amount);
        
        _totalValuePlayedOnPeriod = _totalValuePlayedOnPeriod.add(_amount);

        // Update value of total played by the player
        _myPeriodBets[msg.sender] = _myPeriodBets[msg.sender].add(_amount);

         // Update king of the mountain if needed
        if (_myPeriodBets[msg.sender] > _myPeriodBets[kingOfTheMountain]) {
            kingOfTheMountain = msg.sender;
            emit newKingOfTheMountain(msg.sender);
        }

        // get random with provable (arg1: delay, arg2: uintSize, arg3: GasPrice)
        bytes32 _id = provable_newRandomDSQuery(0, 8, 200000);
        gamesInstances[_id] = gameInstance(msg.sender, _choice, _amount);
        emit gotAPlayer(msg.sender,_id);
    }

    // Call back function used by proableAPI
    function __callback(
        bytes32 _id,
        string memory _result,
        bytes memory _proof
    ) public {
        // Only provable address can call this function
        require(msg.sender == provable_cbAddress());
        
        // Check if return of provable is OK
        if (
            provable_randomDS_proofVerify__returnCode(_id, _result, _proof) != 0
        ) {
            //proof is bad
            //return original payment to player and cancel the playing instance
            morpheus.transferFrom(
                address(this),
                gamesInstances[_id].player,
                gamesInstances[_id].amount
            );
            emit alertEvent("Provable Random is corrupted");
        } else {
            //proof is good
            require(gamesInstances[_id].player != address(0x0));

            // Transform _result provided by ProvableAPI in 0 or 1 to get color
            uint8 randomColor = uint8(uint256(keccak256(abi.encodePacked(_result)))) % 2;
            emit gotAResult(_id, randomColor);

            // If color is the same played by player
            if (randomColor == gamesInstances[_id].choice) {
                //Mint token in contract 
                morpheus.mintTokensForWinner(gamesInstances[_id].amount);
                //Then send it to player
                morpheus.transfer(
                    gamesInstances[_id].player,
                    gamesInstances[_id].amount.mul(2)
                );
                emit winAlert(gamesInstances[_id].player,gamesInstances[_id].amount.mul(2));
                    
            //If player loose
            } else {
                // Update loss of player
                _myPeriodLoss[gamesInstances[_id].player] = (_myPeriodLoss[gamesInstances[_id].player]).add(gamesInstances[_id].amount);
    
                // Update reward pool
                _rewardPool = _rewardPool.add(gamesInstances[_id].amount);
                
                //Update total part
                _totalRewardPart = _totalRewardPart.add(gamesInstances[_id].amount);
    
                // Update personnal Proportionnal reward (counter) for player
                _myRewardPart[gamesInstances[_id].player] = _myRewardPart[gamesInstances[_id].player].add(gamesInstances[_id].amount);
    
                emit lostAlert(gamesInstances[_id].player, gamesInstances[_id].amount);
                
            }

        }
        delete gamesInstances[_id];
    }
    

    // Checking if player is on the players list 
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

    // Providing king of loosers address
    function _getKingOfLoosers() public view returns (address) {
        address _kingOfLoosers;
        uint256 _valueLost = 0;
        for (uint256 i = 0; i < _playersFromPeriod.length; i++) {
            // If player got loss
            if (
                _myPeriodBets[_playersFromPeriod[i]].div(2) <
                _myPeriodLoss[_playersFromPeriod[i]]
            ) {
                // Calculate total loss by player
                uint256 _lostByi = _myPeriodLoss[_playersFromPeriod[i]].sub(
                    _myPeriodBets[_playersFromPeriod[i]].div(2)
                );
                // There can be only one King of loosers
                // If draw, player whos has reached the first is the king
                if (_valueLost < _lostByi) {
                    _valueLost = _lostByi;
                    _kingOfLoosers = _playersFromPeriod[i];
                }
            }
        }
        return (_kingOfLoosers);
    }

    // =========================================================================================
    // Rewards Functions
    // =========================================================================================

    function claimRewards() public {
        require(_rewardPool > 0,"Reward pool is empty !!!");
        require(morpheus.balanceOf(msg.sender)>minimumBalanceForClaim,"You don't have enough MGT for call this function");

        // Security re entry
        uint256 _tempRewardPool = _rewardPool;
        _rewardPool = 0;
        _totalValuePlayedOnPeriod = 0;
        _lastRewardTime = now;

        // update number of period 
        _numberOfPeriod = _numberOfPeriod.add(1);

        // First rewarding kings and claimer
        uint256 rewardForKings = (_tempRewardPool.mul(100)).div(10000);
        _transferToKingOfMountain(rewardForKings);
        _transferToKingOfLoosers(rewardForKings);
        
        // Because solidity don't know floating number, 0.5 % will be 50/10000
        uint256 _claimerPercentage = _getClaimerPercentage();
        uint256 rewardForClaimer = (_tempRewardPool.mul(_claimerPercentage)).div(10000);
        morpheus.transfer(msg.sender, rewardForClaimer);

        // updating reward pool
        _tempRewardPool = _tempRewardPool.sub(rewardForKings);
        _tempRewardPool = _tempRewardPool.sub(rewardForKings);
        _tempRewardPool = _tempRewardPool.sub(rewardForClaimer);

        // then Burning
        uint256 burnPercentage = _getBurnPercentage();
        uint256 totalToBurn = (_tempRewardPool.mul(burnPercentage)).div(10000);
        morpheus.burnTokens(totalToBurn);
        _totalValueBurned = _totalValueBurned.add(totalToBurn);

        // Update temp reward pool
        _tempRewardPool = _tempRewardPool.sub(totalToBurn);

        // Matrix rewards 2%
        uint256 rewardForMatrix = (_tempRewardPool.mul(200)).div(10000);
        _transferToMatrixRunners(rewardForMatrix);

        // update _rewardPool
        _tempRewardPool = _tempRewardPool.sub(rewardForMatrix);

        // Update rewards and refresh period .
        _setRewards(_tempRewardPool);

        emit rewardClaimed(msg.sender, rewardForClaimer, totalToBurn);
    }

    // After claimRewards, players can manualy claim them part of MGT
    function claimMyReward() public {
        require(_myRewardTokens[msg.sender] > 0, "You don't have any token to claim");
        // Re entry secure
        uint256 _myTempRewardTokens = _myRewardTokens[msg.sender];
        _myRewardTokens[msg.sender] = 0;
        morpheus.transfer(msg.sender, _myTempRewardTokens);
    }
    
    function _getClaimerPercentage() public view returns (uint256) {
        uint256 _timeSinceLastReward = now.sub(_lastRewardTime);
        // 50 meens 0.5% => it will be divid by 10000
        uint256 _claimPercentage = 50;

        if (_timeSinceLastReward > 1 days && _timeSinceLastReward < 2 days) {
            _claimPercentage = 100;
        }
        if (_timeSinceLastReward >= 2 days && _timeSinceLastReward < 3 days) {
            _claimPercentage = 150;
        }
        if (_timeSinceLastReward >= 3 days && _timeSinceLastReward < 4 days) {
            _claimPercentage = 200;
        }
        if (_timeSinceLastReward >= 4 days && _timeSinceLastReward < 5 days) {
            _claimPercentage = 250;
        }
        if (_timeSinceLastReward >= 5 days) {
            _claimPercentage = 300;
        }
        return _claimPercentage;
    }

    function _getBurnPercentage() public view returns (uint256) {
        uint256 _timeSinceLastReward = now.sub(_lastRewardTime);
        uint256 _burnPercentage = 8000;

        if (_timeSinceLastReward > 1 days && _timeSinceLastReward < 2 days) {
            _burnPercentage = 7000;
        }
        if (_timeSinceLastReward >= 2 days && _timeSinceLastReward < 3 days) {
            _burnPercentage = 6000;
        }
        if (_timeSinceLastReward >= 3 days && _timeSinceLastReward < 4 days) {
            _burnPercentage = 5000;
        }
        if (_timeSinceLastReward >= 4 days && _timeSinceLastReward < 5 days) {
            _burnPercentage = 4000;
        }
        if (_timeSinceLastReward >= 5 days && _timeSinceLastReward < 6 days) {
            _burnPercentage = 2500;
        }
        if (_timeSinceLastReward >= 6 days && _timeSinceLastReward < 7 days) {
            _burnPercentage = 1000;
        }
        if (_timeSinceLastReward >= 7 days) {
            _burnPercentage = 300;
        }
        return _burnPercentage;
    }

    function _setRewards(uint256 _rewardAmmount) private {
        require(_totalRewardPart > 0 && _playersFromPeriod.length > 0);
        // Reentry secure
        uint256 _tempTotalRewardPart = _totalRewardPart.mul(100);
        _totalRewardPart = 0;

        for (uint8 i = 0; i < _playersFromPeriod.length; i++) {
            // Check if player got reward part
            if (_myRewardPart[_playersFromPeriod[i]] > 0) {
                // Reentry secure
                uint256 _myTempRewardPart
                 = _myRewardPart[_playersFromPeriod[i]].mul(100);
                _myRewardPart[_playersFromPeriod[i]] = 0;

                uint256 _oldPersonnalReward
                 = _myRewardTokens[_playersFromPeriod[i]];
                _myRewardTokens[_playersFromPeriod[i]] = 0;

                // Calculate personnal reward to add
                uint256 personnalReward = (
                    _rewardAmmount.mul(_myTempRewardPart)
                )
                    .div(_tempTotalRewardPart);

                //  Add to old rewards
                _myRewardTokens[_playersFromPeriod[i]] = _oldPersonnalReward
                    .add(personnalReward);
            }
        }
        _deleteAllPlayersFromPeriod();
    }

    // update players of the period
    function _deleteAllPlayersFromPeriod() private {
        for (uint256 i = 0; i < _playersFromPeriod.length; i++) {
            _myPeriodLoss[_playersFromPeriod[i]] = 0;
            _myPeriodBets[_playersFromPeriod[i]] = 0;
        }
        address[] memory _newArray;
        _playersFromPeriod =_newArray;
    }

    function _transferToMatrixRunners(uint256 _amount) private {
        // To be sure to have a valid uint we substract modulo of matrixRunners number to amount
        uint256 amountModuloRunnersNumber = _amount.sub(_amount % _matrixRunners.length);
        uint256 _toTransfer = amountModuloRunnersNumber.div(_matrixRunners.length);
        for (uint256 i = 0; i < _matrixRunners.length; i++) {
            morpheus.transfer(
                _matrixRunners[i],
                _toTransfer
            );
        }
    }

    function _transferToKingOfMountain(uint256 _amount) private {
        require(kingOfTheMountain != address(0x0), "There is no king of the mountain ");
        // Re entry secure
        address _kingOfTheMountain = kingOfTheMountain;
        kingOfTheMountain = address(0x0);

        morpheus.transfer(_kingOfTheMountain, _amount);
    }

    function _transferToKingOfLoosers(uint256 _amount) private {
        if(_getKingOfLoosers() != address(0x0)){
            morpheus.transfer(_getKingOfLoosers(), _amount);           
        }
    }

    // =========================================================================================
    // Rabbits Functions
    // =========================================================================================

    // superclaim is the function who can only call the owner of 3 rabbits (3 different colors)
    // Those 3 rabbits will be burn and 50% of the reward pool wll be transfer to claimer
    function superClaim(
        uint256 _id1,
        uint256 _id2,
        uint256 _id3
    ) public {
        require(_rewardPool > 0, "There is no reward on pool");
        // Can't be called before 30 days 
        require(now.sub(beginningTime) >= 30 days);
        require(
            (rabbits.ownerOf(_id1) == msg.sender &&
            rabbits.ownerOf(_id2) == msg.sender &&
            rabbits.ownerOf(_id3) == msg.sender),
            "You don't have the required Rabbits !!!"
        );
        // Re entry secure
        uint256 _tempRewardPool = _rewardPool;
        _rewardPool = 0;
        
        // Update number of periods of clock
        _numberOfPeriod = _numberOfPeriod.add(1);
        _lastRewardTime = now;
        
        // Reward kings
        uint256 rewardForKings = (_tempRewardPool.mul(1)).div(100);
        _transferToKingOfMountain(rewardForKings);
        _transferToKingOfLoosers(rewardForKings);
        
        // Reward superClaimer
        uint256 rewardForClaimer = _tempRewardPool.div(2);
        morpheus.transfer(msg.sender, rewardForClaimer);
        
        // update reward to burn
        _tempRewardPool = _tempRewardPool.sub(rewardForClaimer);
        _tempRewardPool = _tempRewardPool.sub(rewardForKings.mul(2));
        
        // Burn tokens
        morpheus.burnTokens(_tempRewardPool);
        _totalValueBurned = _totalValueBurned.add(_tempRewardPool);

        // Burn Rabbits
        rabbits.burnRabbitsTrilogy(msg.sender, _id1, _id2, _id3);
        // Update players for period.
        _deleteAllPlayersFromPeriod();

    }
    
    
    // Accept payment for reload contract balance of Eth
    // needed for pay the oracle 
    function() payable external {
        
    }
    

}
