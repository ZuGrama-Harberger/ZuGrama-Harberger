// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Script Errors
error Deploy_UnSupportedChain();

// SBT Errors
error SBT_Function_Disabled();
error SBT_Only_Harberger();

// Auction Errors
error Auction_NotAsset();
error Auction_TimeNotValid();
error Auction_NotStarted();
error Auction_Ended();
error Auction_LessThanMinBid();
error Auction_BidTooLess();
error Auction_NotAuctioner();
error Auction_HasntEnded();
error Auction_NotWinningBidder();
error Auction_SenderNotOwner();
error Auction_AssetDetailsCantBeChangedTillValidEnd();

// Harberger Errors
error Harberger_NotAuction();
error Harberger_NotAdmin();
error Harberger_AssetAlreadyExists();
error Harberger_CantExceed100Percent();
error Harberger_AssetDoesntExists();
error Harberger_BuyoutBidTooLow();
error Harberger_TimelockNotEnded();
error Harberger_AssetAlreadyExpired();
error Harberger_NotSbt();
error Harberger_NoZeroAddress();
error Harberger_AssetAlreadyRegistered();
