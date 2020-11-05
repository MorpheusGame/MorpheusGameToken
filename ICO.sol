pragma solidity 0.5.17;

import "@openzeppelin/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/distribution/RefundableCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/emission/MintedCrowdsale.sol";
import "./MorpheusToken.sol";

contract ICO is
    TimedCrowdsale,
    CappedCrowdsale,
    RefundableCrowdsale,
    MintedCrowdsale
{
    uint256 startingTimeCrowdsale;

    constructor(address payable _wallet)
        public
        Crowdsale(10, _wallet, new MorpheusToken())
        TimedCrowdsale(now, now + 14 days)
        CappedCrowdsale(1000 * 10e18)
        RefundableCrowdsale(10 * 10e18)
    {
        // Init timing of starting crowdsale
        startingTimeCrowdsale = now;
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        returns (uint256)
    {
        // After 7 days, reducting by 1 the number of distributed tokens
        if (now > startingTimeCrowdsale + 7 days) {
            return super._getTokenAmount(weiAmount).sub(1);
        } else {
            return super._getTokenAmount(weiAmount);
        }
    }
}
