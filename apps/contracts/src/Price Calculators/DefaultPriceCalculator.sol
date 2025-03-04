// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPriceCalculator } from "src/interface/IPriceCalculator.sol";

contract DefaultPriceCalculator is IPriceCalculator {

    function getPrice() external override returns (uint256 price) {}

    function getCurrentPrice(
        uint256 startingPrice,
        uint256 duration,
        uint256 deploymentTime
    )
        external
        override
        returns (uint256 currentPrice)
    {}
}