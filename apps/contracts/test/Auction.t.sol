// SPDX-License-Identifier: GPL-v3
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { Deploy } from "script/Deploy.s.sol";
import { Auction } from "src/Initial Distribution/Auction.sol";
import { Harberger } from "src/Harberger.sol";
import { SBT } from "src/SBT.sol";
import { MockUsdc } from "test/mocks/MockUsdc.sol";
import "src/utils/Errors.sol";

contract AuctionTest is Test {
    struct AssetDetails {
        bool isAsset;
        uint64 auctionStartTime;
        uint64 auctionEndTime;
        address currentBidder;
        uint256 currentBid;
        uint256 minBid;
    }

    Auction auction;
    Harberger harberger;
    SBT sbt;

    MockUsdc USDC;
    uint256 constant HUNDRED_USDC = 100_000_000; // 10 USDC in 6 decimals
    uint256 constant TEN_USDC = 10_000_000; // 10 USDC in 6 decimals
    uint256 constant TWENTY_USDC = 20_000_000;
    uint256 constant ONE_USDC = 1_000_000;
    uint256 constant ONE_TENTH_USDC = 100_000; // 1/10 of USDC for Tax Rate

    address auctioner;

    function setUp() external {
        Deploy deploy = new Deploy();
        (address _auction, address _harberger, address _sbt,, address _USDC, Deploy.Config memory config) =
            deploy.deploy();
        auction = Auction(_auction);
        harberger = Harberger(_harberger);
        sbt = SBT(_sbt);

        USDC = MockUsdc(_USDC);

        auctioner = config.auctioner;
    }

    function test_Auction_RevertIfNotAuctioner() external {
        vm.expectRevert(Auction_NotAuctioner.selector);
        auction.setAssetDetails(address(sbt), 1, 1);
    }

    function test_Auction_AssetsSet() external {
        hoax(auctioner, 10 ether);
        auction.setAssetDetails(address(sbt), 1, 1);

        Auction.AssetDetails memory assetDetails = auction.getAssetDetails(address(sbt), 1);

        assertEq(assetDetails.isAsset, true);
        assertEq(assetDetails.minBid, 1);
    }

    function test_Auction_RevertIfNotAsset() external {
        vm.expectRevert(Auction_NotAsset.selector);
        auction.bid(address(sbt), 1, TEN_USDC, TWENTY_USDC); // Auction bid is 10 USDC and initial Value to set is 20
            // USDC
    }

    modifier setAsset() {
        hoax(auctioner, 10 ether);
        auction.setAssetDetails(address(sbt), 1, 1);
        _;
    }

    modifier startAuctionAndValidity(uint256 _tokenId, uint256 _auctionDuration, uint256 _assetValidityDuration) {
        hoax(auctioner, 10 ether);
        auction.startAuctionAndValidity(address(sbt), _tokenId, _auctionDuration, _assetValidityDuration);
        _;
    }

    function test_Auction_RevertIfInvalidTime() external setAsset {
        vm.expectRevert(Auction_TimeNotValid.selector);
        auction.bid(address(sbt), 1, TEN_USDC, TWENTY_USDC); // Auction bid is 10 USDC and initial Value to set is 20
            // USDC
    }

    // function test_Auction_()  returns () {

    // }
}
