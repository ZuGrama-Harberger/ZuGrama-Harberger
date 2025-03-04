// SPDX-License-Identifier: GPL-v3
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { Deploy } from "script/Deploy.s.sol";
import { Auction } from "src/Initial Distribution/Auction.sol";
import { Harberger } from "src/Harberger.sol";
import { SBT } from "src/SBT.sol";
import "src/utils/Errors.sol";

contract SBTTest is Test {
    Auction auction;
    Harberger harberger;
    SBT sbt;

    function setUp() external {
        Deploy deploy = new Deploy();
        (address _auction, address _harberger, address _sbt,,,) = deploy.deploy();
        auction = Auction(_auction);
        harberger = Harberger(_harberger);
        sbt = SBT(_sbt);
    }

    function test_ApproveRevertsIfNotHarberger() external {
        vm.expectRevert(SBT_Only_Harberger.selector);
        sbt.approve(address(25), 1);
    }

    function test_MintRevertsIfNotHarberger() external {
        vm.expectRevert(SBT_Only_Harberger.selector);
        sbt.mint(address(25), 1);
    }

    function test_TransferFromRevertsIfHarberger() external {
        vm.expectRevert(SBT_Only_Harberger.selector);
        sbt.transferFrom(address(25), address(26), 1);
    }

    function test_ApproveAllReverts() external {
        vm.expectRevert(SBT_Function_Disabled.selector);
        sbt.setApprovalForAll(address(25), true);
    }
}
