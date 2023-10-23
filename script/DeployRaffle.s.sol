// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreatSubscription, FundSubscription, AddConsumer} from "./Interagtion.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            uint256 enteranceFee,
            uint256 interval,
            bytes32 gaslane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address vrfCoordinator,
            address link
        ) = helperConfig.activeNetworkConfig();
        if (subscriptionId == 0) {
            //创建订阅
            CreatSubscription creatVrf = new CreatSubscription();
            subscriptionId = creatVrf.createSubscription(vrfCoordinator);

            //Fund订阅
            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(subscriptionId, vrfCoordinator, link);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            enteranceFee,
            interval,
            gaslane,
            subscriptionId,
            callbackGasLimit,
            vrfCoordinator
        );

        vm.stopBroadcast();
        AddConsumer addCsm = new AddConsumer();
        addCsm.addConsumer(subscriptionId, vrfCoordinator, address(raffle));

        return (raffle, helperConfig);
    }
}
