pragma solidity 0.5.17;

// ICO Contract

import "./Crowdsale.sol";
import "./CappedCrowdsale.sol";
import "./TimedCrowdsale.sol";
import "./MorpheusToken.sol";
import "./MintedCrowdsale.sol";

contract ICO is Crowdsale, TimedCrowdsale, CappedCrowdsale, MintedCrowdsale{
    

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

    //mint tokens for Marketing (3M) / Team (3M) and Liquidity Pool (10M)
    _deliverTokens(msg.sender, 16000000*1E18);
    }
}
