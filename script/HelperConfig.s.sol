// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Script} from "forge-std/Script.sol";
import {LinkToken} from "../test/Mocks/LInkToken.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 enteranceFee;
        uint256 interval;
        bytes32 gaslane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        address link;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetwork();
        } else {
            activeNetworkConfig = getOrCreateAnvilNetwork();
        }
    }

    function getSepoliaNetwork() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                enteranceFee: 0.01 ether,
                interval: 30,
                gaslane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0,
                callbackGasLimit: 50000,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilNetwork() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        uint96 BASE_FEE = 0.25 ether;
        uint96 GAS_PRICE_LINK = 1e9;
        vm.startBroadcast();
        VRFCoordinatorV2Mock coordinator = new VRFCoordinatorV2Mock(
            BASE_FEE,
            GAS_PRICE_LINK
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();
        return
            NetworkConfig({
                enteranceFee: 0.01 ether,
                interval: 30,
                gaslane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0,
                callbackGasLimit: 50000,
                vrfCoordinator: address(coordinator),
                link: address(link)
            });
    }
}
