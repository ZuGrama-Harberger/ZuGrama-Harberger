// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPriceCalculator } from "src/interface/IPriceCalculator.sol";

contract LinearPriceDrop is IPriceCalculator {

    function getPrice() external override returns (uint256 price) {}

    function getCurrentPrice()
        external
        override
        returns (uint256 currentPrice)
    {}
}