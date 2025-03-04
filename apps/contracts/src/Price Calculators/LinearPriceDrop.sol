// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPriceCalculator } from "src/interface/IPriceCalculator.sol";

contract LinearPriceDrop is IPriceCalculator {

    function getPrice() external override returns (uint256 price) {}

    function getCurrentPrice(
        uint256 startingPrice,
        uint256 duration,
        uint256 deploymentTime
    )
        external
        override
        returns (uint256 currentPrice)
    {
        // Calculate the current price based on time.
        // Example: Starting price is 1 ether, decreasing linearly over 1 year.

        // 1. Get the current timestamp in seconds
        uint256 currentTime = block.timestamp;

        // 2. Calculate how much time has passed since the contract was deployed
        uint256 timeElapsed = currentTime - deploymentTime;

        // 3. Calculate the price decrease per second
        uint256 priceDecreasePerSecond = startingPrice / duration;

        // 4. Calculate the current price by subtracting the decrease over time
        currentPrice = startingPrice - (priceDecreasePerSecond * timeElapsed);

        // 5. Ensure the price doesn't go below zero
        if (currentPrice < 0) {
            currentPrice = 0;
        }

        return currentPrice;
    }
}