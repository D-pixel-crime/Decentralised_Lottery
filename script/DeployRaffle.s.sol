// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract DeployRaffle is Script, CodeConstants {
    function run()
        external
        returns (Raffle, HelperConfig.NetworkConfig memory)
    {
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory config = hc.getChainConfig();
        uint256 FUND_AMOUNT = 4 ether;

        if (config.subscriptionId == 0) {
            vm.startBroadcast();
            config.subscriptionId = VRFCoordinatorV2_5Mock(
                config.vrfCoordinator
            ).createSubscription();
            vm.stopBroadcast();

            if (block.chainid == LOCAL_CHAIN_ID) {
                vm.startBroadcast();
                VRFCoordinatorV2_5Mock(config.vrfCoordinator).fundSubscription(
                    config.subscriptionId,
                    FUND_AMOUNT
                );
                vm.stopBroadcast();
            } else {
                vm.startBroadcast();
                LinkToken(config.linkMock).transferAndCall(
                    config.vrfCoordinator,
                    FUND_AMOUNT,
                    abi.encode(config.subscriptionId)
                );
                vm.stopBroadcast();
            }
        }

        vm.startBroadcast();
        Raffle raffleContract = new Raffle(
            config.vrfCoordinator,
            config.entranceFee,
            config.cooldownPeriod,
            config.keyHash,
            config.callbackGasLimit,
            config.requestConfirmations,
            config.subscriptionId,
            config.ethToUsdDataFeedProxy
        );
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).addConsumer(
            config.subscriptionId,
            address(raffleContract)
        );
        vm.stopBroadcast();

        return (raffleContract, config);
    }
}
