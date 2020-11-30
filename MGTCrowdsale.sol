pragma solidity 0.5.17;

// Crowdsale Contract

import "./Crowdsale.sol";
import "./CappedCrowdsale.sol";
import "./TimedCrowdsale.sol";
import "./MorpheusToken.sol";
import "./MintedCrowdsale.sol";


contract MGTCrowdsale is Crowdsale, TimedCrowdsale, CappedCrowdsale, MintedCrowdsale{
    

    constructor()
        public
        Crowdsale(
            50000,
            msg.sender,
            new MorpheusToken(msg.sender)
        )
        TimedCrowdsale(now, now + 7 days)
        CappedCrowdsale(600*1E18)
    {

    //mint tokens for Marketing (3M) and Liquidity Pool (10M)
    _deliverTokens(msg.sender, 13000000*1E18);
    }
}
