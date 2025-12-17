// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";

contract DeployRaffle is Script {
    function run()
        external
        returns (Raffle, HelperConfig.NetworkConfig memory)
    {
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory config = hc.getChainConfig();

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
        vm.stopBroadcast();

        return (raffleContract, config);
    }
}
