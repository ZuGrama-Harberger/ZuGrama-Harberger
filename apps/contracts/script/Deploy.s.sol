// SPDX-License-Identifier: GPL-v3
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { Auction } from "src/Initial Distribution/Auction.sol";
import { Harberger } from "src/Harberger.sol";
import { SBT } from "src/SBT.sol";
import { MockUsdc } from "test/mocks/MockUsdc.sol";
import { SBTFactory } from "src/SBTFactory.sol";
import "src/utils/Errors.sol";

contract Deploy is Script {
    struct Config {
        address auctioner;
        address USDC;
        address admin;
    }

    Auction auction;
    Harberger harberger;
    SBT sbt;
    SBTFactory sbtFactory;
    MockUsdc USDC;

    function run() external {
        vm.startBroadcast();
        deploy();
        vm.stopBroadcast();
    }

    function deploy()
        public
        returns (
            address _auction,
            address _harberger,
            address _sbt,
            address _sbtFactory,
            address _USDC,
            Config memory config
        )
    {
        deployMocks();
        config = getConfig();
        auction = new Auction(config.auctioner, config.USDC);
        harberger = new Harberger(config.admin, address(auction), config.USDC);
        sbt = new SBT("ZuGrama-1 Assets", "Zu1Assets", address(harberger), msg.sender);
        sbtFactory = new SBTFactory(address(harberger));

        _auction = address(auction);
        _harberger = address(harberger);
        _sbt = address(sbt);
        _sbtFactory = address(sbtFactory);
        _USDC = address(USDC);
    }

    function deployMocks() public {
        if (block.chainid == 31_337) {
            USDC = new MockUsdc();
        } else if (block.chainid == 845_32) {
            USDC = new MockUsdc();
        }
    }

    function getConfig() internal view returns (Config memory _config) {
        if (block.chainid == 31_337) {
            // if local deploy mock
            _config = Config({
                auctioner: vm.envAddress("AUCTIONER_ADDRESS"),
                USDC: address(USDC),
                admin: vm.envAddress("ADMIN_ADDRESS")
            });
        } else if (block.chainid == 845_32) {
            // if base sepolia deploy mock
            _config = Config({
                auctioner: vm.envAddress("AUCTIONER_ADDRESS"),
                USDC: address(USDC),
                admin: vm.envAddress("ADMIN_ADDRESS")
            });
        } else {
            revert Deploy_UnSupportedChain();
        }
    }
}
