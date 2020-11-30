pragma solidity 0.5.17;

// Crowdsale Contract

import "./Crowdsale.sol";
import "./CappedCrowdsale.sol";
import "./TimedCrowdsale.sol";
import "./MorpheusToken.sol";
import "./MintedCrowdsale.sol";

contract MGTCrowdsale is Crowdsale, TimedCrowdsale, CappedCrowdsale, MintedCrowdsale{
    

    constructor(address payable _deployer)
        public
        Crowdsale(
            50000,
            _deployer,
            new MorpheusToken(_deployer)
        )
        TimedCrowdsale(now, now + 7 days)
        CappedCrowdsale(600*1E18)
    {

    //mint tokens for Marketing (3M) and Liquidity Pool (7,5M)
    _deliverTokens(_deployer, 10500000*1E18);
    }
}
