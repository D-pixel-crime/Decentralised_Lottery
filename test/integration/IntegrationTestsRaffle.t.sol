// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract IntegrationTestsRaffle is Test {
    Raffle raffleContract;
    HelperConfig.NetworkConfig config;
    address payable[] allPlayers;
    uint256 startingAmount = 10 ether;

    function setUp() external {
        (raffleContract, config) = (new DeployRaffle()).run();
    }

    function test_fullRaffleCycleFuzzyTesting(uint8 totalPlayers) public {
        totalPlayers = uint8(bound(totalPlayers, 1, 2 ** 8 - 1));
        uint256 fundAmount = 2 ether;
        for (uint16 i = 0; i <= totalPlayers; i++) {
            address p = makeAddr(string.concat("Player", vm.toString(i)));
            vm.prank(p);
            vm.deal(p, startingAmount);
            vm.expectEmit();
            emit Raffle.newPlayerAdded(address(raffleContract), p);
            raffleContract.enterRaffle{value: fundAmount}();
            allPlayers.push(payable(p));
        }

        (, uint256 beforeBal) = raffleContract.getTotalPlayersAndRewardMoney();

        vm.warp(block.timestamp + config.cooldownPeriod + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffleContract.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 reqId = entries[1].topics[1];
        uint256 predictableRandomWord = uint256(
            keccak256(abi.encode(uint256(reqId), uint256(0)))
        );
        address expectedWinner = address(
            allPlayers[predictableRandomWord % allPlayers.length]
        );

        vm.expectEmit();
        emit Raffle.newWinnerRewarded(
            address(raffleContract),
            expectedWinner,
            beforeBal,
            block.timestamp
        );
        vm.expectEmit(false, false, false, false);
        emit VRFCoordinatorV2_5Mock.RandomWordsFulfilled(
            0,
            0,
            0,
            0,
            false,
            false,
            false
        );
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(
            uint256(reqId),
            address(raffleContract)
        );

        (uint256 afterPlayers, uint256 afterBal) = raffleContract
            .getTotalPlayersAndRewardMoney();

        vm.assertTrue(afterPlayers == 0 && afterBal == 0);
        assert(raffleContract.getRaffleState() == Raffle.RaffleState.IDLE);
    }
}
