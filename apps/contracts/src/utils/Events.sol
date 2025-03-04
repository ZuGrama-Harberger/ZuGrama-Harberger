// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Auction Event
event Auction_AssetSet(address indexed assetAddress, uint256 indexed assetId, uint256 indexed minBid);

event Auction_Started(address indexed assetAddress, uint256 indexed assetId, uint256 indexed auctionEndTime);

event Auction_NewBid(address indexed bidder, uint256 indexed amount);

event Harberger_Buyout_Initiated(
    address indexed assetAddress, uint256 indexed assetId, address indexed bidder, uint256 bidAmount
);

event SBTFactory_New_Asset(
    address indexed assetAddress, address indexed initialOwner, string indexed name, string symbol
);

event SBTRegistered(address indexed assetAddress);