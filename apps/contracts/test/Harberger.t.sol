// SPDX-License-Identifier: GPL-v3
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { Deploy } from "script/Deploy.s.sol";
import { Auction } from "src/Initial Distribution/Auction.sol";
import { Harberger } from "src/Harberger.sol";
import { SBT } from "src/SBT.sol";
import { MockUsdc } from "test/mocks/MockUsdc.sol";
import "src/utils/Errors.sol";

contract HarbergerTest is Test {
    Auction auction;
    Harberger harberger;
    SBT sbt;
    uint256 tokenId = 1;

    MockUsdc USDC;

    uint256 constant HUNDRED_USDC = 100_000_000; // 10 USDC in 6 decimals
    uint256 constant TEN_USDC = 10_000_000; // 10 USDC in 6 decimals
    uint256 constant TWENTY_USDC = 20_000_000;
    uint256 constant ONE_USDC = 1_000_000;
    uint256 constant ONE_TENTH_USDC = 100_000; // 1/10 of USDC for Tax Rate
    address auctioner;

    address user1 = makeAddr("USER_1");
    address user2 = makeAddr("USER_2");
    address user3 = makeAddr("USER_3");

    uint256 constant ASSET_VALIDITY = 10 days;
    uint256 constant QUARTER_ASSET_VALIDITY = 2.5 days;
    uint256 constant HALF_ASSET_VALIDITY = 5 days;
    uint256 constant AUCTION_DURATION = 1 hours;
    uint256 constant ONE_DAY = 1 days;

    function setUp() external {
        Deploy deploy = new Deploy();
        (address _auction, address _harberger, address _sbt,, address _USDC, Deploy.Config memory config) =
            deploy.deploy();

        auction = Auction(_auction);
        harberger = Harberger(_harberger);
        sbt = SBT(_sbt);

        USDC = MockUsdc(_USDC);

        auctioner = config.auctioner;

        USDC.mint(user1, HUNDRED_USDC);
        USDC.mint(user2, HUNDRED_USDC);
        USDC.mint(user3, HUNDRED_USDC);

        hoax(auctioner, 10 ether);
        auction.setHarberger(address(harberger));

        hoax(config.admin, 10 ether);
        harberger.setTaxRate(ONE_TENTH_USDC);
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

    function test_InitialMint() public setAsset startAuctionAndValidity(tokenId, AUCTION_DURATION, ASSET_VALIDITY) {
        uint256 auctionStartedTime = uint64(block.timestamp);

        hoax(user1, 100 ether);
        USDC.approve(address(auction), TEN_USDC + (2 * ONE_USDC)); // 10 USDC is amount. 2 USDC is Tax for 20 USDC
            // initial Value

        // Make bid of 10 USDC
        hoax(user1);
        auction.bid(address(sbt), tokenId, TEN_USDC, TWENTY_USDC); // Auction bid is 10 USDC and initial Value to set is
            // 20 USDC

        // Wait for Auction to end
        skip(AUCTION_DURATION);
        uint256 expectedValidFrom = uint64(block.timestamp);

        // Claim Asset
        hoax(user1);
        auction.claim(address(sbt), tokenId, user1);

        Harberger.HarbergerDetails memory harbergerDetails = harberger.getHarbegerDetails(address(sbt), tokenId);
        assertEq(harbergerDetails.validFrom, expectedValidFrom);
        assertEq(harbergerDetails.updatedAt, expectedValidFrom);
        assertEq(harbergerDetails.validTill, auctionStartedTime + ASSET_VALIDITY + AUCTION_DURATION);
        assertEq(harbergerDetails.value, TWENTY_USDC);

        assertEq(USDC.balanceOf(address(harberger)), TEN_USDC + (2 * ONE_USDC));
        assertEq(sbt.ownerOf(tokenId), user1);
    }

    function initialMint() internal setAsset startAuctionAndValidity(tokenId, AUCTION_DURATION, ASSET_VALIDITY) {
        hoax(user1, 100 ether);
        USDC.approve(address(auction), TEN_USDC + (2 * ONE_USDC)); // 10 USDC is amount. 2 USDC is Tax for 20 USDC
            // initial Value

        // Make bid of 10 USDC
        hoax(user1);
        auction.bid(address(sbt), tokenId, TEN_USDC, TWENTY_USDC); // Auction bid is 10 USDC and initial Value to set is
            // 20 USDC

        // Wait for Auction to end
        skip(AUCTION_DURATION);

        // Claim Asset
        hoax(user1);
        auction.claim(address(sbt), tokenId, user1);
    }

    function test_curretAssetValue() external {
        initialMint();

        skip(QUARTER_ASSET_VALIDITY);
        uint256 quarterValue = harberger.getCurrentValueOfAsset(address(sbt), tokenId);

        uint256 expectedQuarterValue = (TWENTY_USDC * (ASSET_VALIDITY - QUARTER_ASSET_VALIDITY)) / (ASSET_VALIDITY); // value
            // = initialValue * (remainingTime / totalTime)
        assertEq(quarterValue, expectedQuarterValue);

        skip(HALF_ASSET_VALIDITY);
        uint256 threeQuaterValue = harberger.getCurrentValueOfAsset(address(sbt), tokenId);

        uint256 expectedThreeQuarterValue =
            (TWENTY_USDC * (ASSET_VALIDITY - (QUARTER_ASSET_VALIDITY + HALF_ASSET_VALIDITY))) / (ASSET_VALIDITY); // value =
            // initialValue * (remainingTime / totalTime)
        assertEq(threeQuaterValue, expectedThreeQuarterValue);

        skip(QUARTER_ASSET_VALIDITY);
        uint256 finalValue = harberger.getCurrentValueOfAsset(address(sbt), tokenId);

        uint256 expectedFinalValue = 0; // value = initialValue * (remainingTime / totalTime)
        assertEq(finalValue, expectedFinalValue);
    }

    function test_startBuyout() external { 
        initialMint();

        skip(QUARTER_ASSET_VALIDITY);

        uint256 quarterAssetValue = harberger.getCurrentValueOfAsset(address(sbt), tokenId);
        
        uint256 newValue = quarterAssetValue + TEN_USDC;
        uint256 newTax = harberger.getTotalTaxForValue(newValue);
        
        hoax(user2, 10 ether);
        USDC.approve(address(harberger), newValue + newTax);

        uint256 priorBalance = USDC.balanceOf(address(harberger));

        hoax(user2);
        harberger.startBuyout(address(sbt), tokenId, quarterAssetValue, newValue);

        uint256  postBalance = USDC.balanceOf(address(harberger));

        Harberger.HarbergerDetails memory harbergerDetails = harberger.getHarbegerDetails(address(sbt), tokenId);

        assertEq(harbergerDetails.buyoutAmount, quarterAssetValue);
        assertEq(harbergerDetails.buyoutBidder, user2);
        assertEq(harbergerDetails.buyoutInitiationTime, uint64(block.timestamp));
        assertEq(harbergerDetails.buyoutAssetValue, newValue);
        assertEq(postBalance, priorBalance + quarterAssetValue + newTax);

    }


    function test_multipleStartBuyout() external {
        initialMint();

        skip(QUARTER_ASSET_VALIDITY);

        uint256 quarterAssetValue = harberger.getCurrentValueOfAsset(address(sbt), tokenId);
        
        uint256 newValue = quarterAssetValue + TEN_USDC;
        uint256 newTax = harberger.getTotalTaxForValue(newValue);
        
        // User 2 starts buyout
        hoax(user2, 10 ether);
        USDC.approve(address(harberger), newValue + newTax);

        uint256 user2Buyout = quarterAssetValue;

        hoax(user2);
        harberger.startBuyout(address(sbt), tokenId, user2Buyout, newValue);


        // User 3 outbids User2 with same value
        hoax(user3, 10 ether);
        USDC.approve(address(harberger), newValue + newTax);

        uint256 priorBalance = USDC.balanceOf(address(harberger));
        
        uint256 user3Buyout = quarterAssetValue + ONE_USDC;
        hoax(user3);
        harberger.startBuyout(address(sbt), tokenId, user3Buyout, newValue);

        uint256  postBalance = USDC.balanceOf(address(harberger));
        
        Harberger.HarbergerDetails memory harbergerDetails = harberger.getHarbegerDetails(address(sbt), tokenId);

        assertEq(harbergerDetails.buyoutAmount, user3Buyout);
        assertEq(harbergerDetails.buyoutBidder, user3);
        assertEq(harbergerDetails.buyoutInitiationTime, uint64(block.timestamp));
        assertEq(harbergerDetails.buyoutAssetValue, newValue);
        // Since User3's buyoutAmount is higher, user2's buyoutAmount and tax is sent back
        assertEq(postBalance, priorBalance + user3Buyout + newTax - (user2Buyout + newTax)); // Since newValue is the same in both the tax for both is same 
        
    }

    function startBuyout()  internal {

        
        skip(QUARTER_ASSET_VALIDITY);
        uint256 quarterAssetValue = harberger.getCurrentValueOfAsset(address(sbt), tokenId);
        
        uint256 newValue = quarterAssetValue + TEN_USDC;
        uint256 newTax = harberger.getTotalTaxForValue(newValue);
        
        hoax(user2, 10 ether);
        USDC.approve(address(harberger), newValue + newTax);

        
        hoax(user2);
        harberger.startBuyout(address(sbt), tokenId, quarterAssetValue, newValue);

        
    }

    function test_completeBuyout() external {
        initialMint();
        startBuyout();

        skip(ONE_DAY);
        uint256 user1PriorBalance = USDC.balanceOf(user1);
        Harberger.HarbergerDetails memory harbergerDetails = harberger.getHarbegerDetails(address(sbt), tokenId);

        // uint256 taxOwedTillNow = harberger.getTaxOwedTillNow(address(sbt), tokenId);
        // uint256 totalPriorTax = harberger.getTotalTaxForValue(harbergerDetails.value);


        harberger.completeBuyOut(address(sbt), tokenId);


        uint256 user1PostBalance = USDC.balanceOf(user1);

        // uint256 remainingTax = totalPriorTax - taxOwedTillNow;

        assertEq(user1PostBalance, user1PriorBalance + harbergerDetails.buyoutAmount + harbergerDetails.taxToBeReturned);
        // 109_500_000    
        // 106_500_000


        // User 1                   Harberger       Value       TAX OWED        TAX Rem
        // Mint         100
        // Auction      88          12              20          0               2
        // Quarter      88          12              20          0.5             1.5
        // comBuy       109.5       15              30          0.5             3
        // @follow-up The one day gap in the timelock to completeBuyout gives time for 
        assertEq(sbt.ownerOf(tokenId), user2);

    }
}
