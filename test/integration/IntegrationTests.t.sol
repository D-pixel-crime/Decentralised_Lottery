// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract IntegrationTests is Test {
    Raffle raffleContract;
    HelperConfig.NetworkConfig config;

    function setUp() external {
        (raffleContract, config) = (new DeployRaffle()).run();
    }
}
