// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "src/utils/Errors.sol";
import "src/utils/Events.sol";
import { SBT } from "src/SBT.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Harberger {
    using SafeERC20 for IERC20;

    struct HarbergerDetails {
        uint256 value;
        uint64 validFrom;
        uint64 validTill;
        uint64 updatedAt;
        uint64 buyoutInitiationTime;
        address buyoutBidder;
        uint256 buyoutAmount;
        uint256 buyoutAssetValue;
        uint256 taxToBeReturned;
    }

    address public immutable admin;
    address public immutable sbtFactory;
    IERC20 immutable USDC;

    uint256 public taxRate; //Tax Rate. Is in 6 decimals. Where 100% = 1000000
    uint256 public excessEarnings;

    mapping(address asset => mapping(uint256 assetId => HarbergerDetails)) private assetToHarberger;
    mapping(address asset => address idc) private assetToIdc;

    constructor(address _admin, address _sbtFactory, address _usdc) {
        sbtFactory = _sbtFactory;
        admin = _admin;
        USDC = IERC20(_usdc);
    }

    
    modifier onlyIdc(address _asset) {
        address idc = getAssetToIdc(_asset);
        if (msg.sender != idc) {
            revert Harberger_NotAuction();
        }
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert Harberger_NotAdmin();
        }
        _;
    }

    modifier onlySbtFactory() {
        if (msg.sender != sbtFactory) {
            revert Harberger_NotSbt();
        }
        _;
    }

    /**
     * @dev Registers asset from SBT Factory
     * @param _asset Address of the SBT asset
     */
    function registerSBT(address _asset, address _idc) external onlySbtFactory() {
        // Check if the asset is already registered for the given assetId
        if (assetToIdc[_asset] != address(0)) { // which mean IDC is already set for this asset
            revert Harberger_AssetAlreadyRegistered();
        }

        if (_asset == address(0) || _idc == address(0)) {
            revert Harberger_NoZeroAddress();
        }
        // Update the mapping with the new details
        assetToIdc[_asset] = _idc;

        // Emit an event to confirm registration
        emit SBTRegistered(_asset);
    }
    

    function initialMint(
        address _asset,
        uint256 _assetId,
        uint64 _validFrom,
        uint64 _validTill,
        address _bidder,
        uint256 _winningBidAmout,
        uint256 _initialValue
    )
        external
        onlyIdc(_asset)
    {
        HarbergerDetails memory harbergerDetails = getHarbegerDetails(_asset, _assetId);

        if (harbergerDetails.validFrom != 0) {
            revert Harberger_AssetAlreadyExists();
        }

        harbergerDetails.validFrom = _validFrom;
        harbergerDetails.updatedAt = _validFrom;
        harbergerDetails.validTill = _validTill;
        harbergerDetails.value = _initialValue;
        assetToHarberger[_asset][_assetId] = harbergerDetails;

        uint256 tax = getTotalTaxForValue(_initialValue);

        address idc = getAssetToIdc(_asset);
        USDC.safeTransferFrom(idc, address(this), tax + _winningBidAmout);

        SBT(_asset).mint(_bidder, _assetId);
    }

    function startBuyout(address _asset, uint256 _assetId, uint256 _buyoutAmount, uint256 _assetValue) external {
        HarbergerDetails memory harbergerDetails = getHarbegerDetails(_asset, _assetId);

        if (harbergerDetails.validFrom == 0) {
            revert Harberger_AssetDoesntExists();
        }

        // If the buyoutAmount is less than or equal to an existing bid then revert
        if (harbergerDetails.buyoutAmount > 0 && _buyoutAmount < harbergerDetails.buyoutAmount) {
            revert Harberger_BuyoutBidTooLow();
        }

        uint256 currentValue = getCurrentValueOfAsset(_asset, _assetId);
        if (currentValue > _buyoutAmount) {
            revert Harberger_BuyoutBidTooLow();
        }

        if (harbergerDetails.buyoutAmount > 0 && harbergerDetails.buyoutBidder != address(0)) {
            // If There is a buyout bid already then return that

            uint256 previousBuyoutTax = getTotalTaxForValue(harbergerDetails.buyoutAssetValue);
            USDC.safeTransfer(harbergerDetails.buyoutBidder, harbergerDetails.buyoutAmount + previousBuyoutTax);
        }
        
        uint256 tax = getTotalTaxForValue(_assetValue);
        uint256 priorTax = getTotalTaxForValue(harbergerDetails.value);
        uint256 taxOwedTillNow = getTaxOwedTillNow(_asset, _assetId);
        uint256 taxToReimburse = priorTax - taxOwedTillNow;
        
        harbergerDetails.buyoutAmount = _buyoutAmount;
        harbergerDetails.buyoutBidder = msg.sender;
        harbergerDetails.buyoutInitiationTime = uint64(block.timestamp);
        harbergerDetails.buyoutAssetValue = _assetValue;
        harbergerDetails.taxToBeReturned = taxToReimburse;
        assetToHarberger[_asset][_assetId] = harbergerDetails;


        USDC.safeTransferFrom(msg.sender, address(this), tax + _buyoutAmount);

        emit Harberger_Buyout_Initiated(_asset, _assetId, msg.sender, _buyoutAmount);
    }

    function completeBuyOut(address _asset, uint256 _assetId) external {
        HarbergerDetails memory harbergerDetails = getHarbegerDetails(_asset, _assetId);

        if (harbergerDetails.validFrom == 0) {
            revert Harberger_AssetDoesntExists();
        }
        if (harbergerDetails.validTill < block.timestamp) {
            revert Harberger_AssetAlreadyExpired();
        }
        if (
            harbergerDetails.buyoutInitiationTime != 0
                && harbergerDetails.buyoutInitiationTime + 1 days > uint64(block.timestamp) // @follow-up try changing this
                // buyout time to be in sbt itself
        ) {
            revert Harberger_TimelockNotEnded();
        }

        uint256 buyoutAmount = harbergerDetails.buyoutAmount;
        address bidder = harbergerDetails.buyoutBidder;
        uint256 newAssetValue = harbergerDetails.buyoutAssetValue;
        uint256 taxToReturn = harbergerDetails.taxToBeReturned;
        address currentOwner = SBT(_asset).ownerOf(_assetId);
        

        harbergerDetails.buyoutAmount = 0;
        harbergerDetails.buyoutBidder = address(0);
        harbergerDetails.buyoutInitiationTime = 0;
        harbergerDetails.buyoutAssetValue = 0;
        harbergerDetails.value = newAssetValue;
        harbergerDetails.updatedAt = uint64(block.timestamp);
        harbergerDetails.taxToBeReturned = 0;
        assetToHarberger[_asset][_assetId] = harbergerDetails;

        USDC.safeTransfer(currentOwner, buyoutAmount + taxToReturn);
        SBT(_asset).transferFrom(currentOwner, bidder, _assetId);
    }

    // function matchBuyOut(address _asset, uint256 _assetId) external { }

    function setTaxRate(uint256 _taxRate) external onlyAdmin {
        if (_taxRate > 1_000_000) {
            revert Harberger_CantExceed100Percent();
        }
        taxRate = _taxRate;
    }

    function retrieveFunds(address _token, uint256 _amount, address _to) external onlyAdmin {
        IERC20(_token).transfer(_to, _amount);
    }

    function getTotalTaxForValue(uint256 _value) public view returns (uint256 tax) {
        tax = (_value * taxRate) / 1_000_000; // Value is USD i.e 6 decimals and taxRate is also 6 decimals
    }

    function getTaxOwedTillNow(address _asset, uint256 _assetId) public view returns (uint256 taxOwed) {
        HarbergerDetails memory harbergerDetails = getHarbegerDetails(_asset, _assetId);

        // tax Owed till now = totalTaxForPeriod * (currentTime / totalTimePeriod)
        uint256 totalTax = getTotalTaxForValue(harbergerDetails.value);
        
        uint64 timePeriod = harbergerDetails.validTill - harbergerDetails.updatedAt;
        uint64 timePassed = uint64(block.timestamp) - harbergerDetails.updatedAt;
        taxOwed = (totalTax * timePassed) / timePeriod;
    }

    function getCurrentValueOfAsset(address _asset, uint256 _assetId) public view returns (uint256 currentValue) {
        HarbergerDetails memory harbergerDetails = getHarbegerDetails(_asset, _assetId);

        // Current Value of assets is function of the time period. Value decrease linearly with time
        // Current Value of asset = (currentTime / totalTimePeriod ) * initialValue @follow-up fix it with (100 -
        // percent) * value
        uint64 timePeriod = harbergerDetails.validTill - harbergerDetails.updatedAt;
        uint64 timePassed = uint64(block.timestamp) - harbergerDetails.updatedAt;
        uint64 remainingTime = timePeriod - timePassed;
        currentValue = (remainingTime * harbergerDetails.value) / timePeriod;
    }

    function getHarbegerDetails(address _asset, uint256 _assetId) public view returns (HarbergerDetails memory) {
        return assetToHarberger[_asset][_assetId];
    }

    function getAssetToIdc(address _asset) public view  returns (address) {
        return assetToIdc[_asset];
    }
}
