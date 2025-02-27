// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IHook } from "src/interface/IHook.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistHook is IHook, Ownable {
    
    mapping(address => bool) public whitelist;
    
    constructor() Ownable(msg.sender) {}

    function checkAssetRegister() external override returns (bool success) {}

    function checkAssetMint() external override returns (bool success) {}

    function checkBeforeBid(
        address _bidder,
        address _asset,
        address _assetId,
        uint _bidAmount,
        bytes memory _data
    ) external override returns (bool success) {}

    function checkAfterBid(
        address _bidder,
        address _asset,
        address _assetId,
        uint _bidAmount,
        bytes memory _data
    ) external override returns (bool success) {}

    function checkBeforeClaim(
        address _bidder,
        address _asset,
        address _assetId,
        uint _bidAmount
    ) external override returns (bool success) {}

    function checkAfterClaim(
        address _bidder,
        address _asset,
        address _assetId,
        uint _bidAmount
    ) external override returns (bool success) {}
}