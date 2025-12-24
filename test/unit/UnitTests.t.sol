// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract UnitTests is Test {
    Raffle raffleContract;
    HelperConfig.NetworkConfig config;
    address player = makeAddr("user");
    uint256 startFund = 10 ether;

    /**  @dev Raffle Events */
    event newPlayerAdded(address, address);

    function setUp() external {
        (raffleContract, config) = (new DeployRaffle()).run();
        startHoax(player, startFund);
    }

    /** @dev Testing some variables is enough */
    function test_stateVariablesAreSetOrNot() public view {
        vm.assertEq(raffleContract.getEntranceFee(), config.entranceFee);
        vm.assertEq(raffleContract.getCooldownPeriod(), config.cooldownPeriod);
        vm.assertTrue(
            raffleContract.getRaffleState() == Raffle.RaffleState.IDLE
        );
    }

    function test_ownerSetProperly() public view {
        vm.assertEq(raffleContract.getOwner(), msg.sender);
    }

    function test_raffleEntry() public {
        uint256 fundVal = 0.0001 ether;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.notEnoughEntranceFee.selector,
                address(raffleContract),
                fundVal,
                config.entranceFee
            )
        );
        raffleContract.enterRaffle{value: fundVal}();

        fundVal = 1 ether;

        (uint256 beforePlayer, uint256 beforeReward) = raffleContract
            .getTotalPlayersAndRewardMoney();

        vm.expectEmit();
        emit newPlayerAdded(address(raffleContract), address(player));
        raffleContract.enterRaffle{value: fundVal}();

        (uint256 afterPlayer, uint256 afterReward) = raffleContract
            .getTotalPlayersAndRewardMoney();

        assert(beforePlayer + 1 == afterPlayer);
        assert(beforeReward + fundVal == afterReward);
    }

    function test_stateVariablesUpdationReverts() public {
        uint32 newCallbackGasLimit = 3500000;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.aboveAllowedGasLimitOf_2_500_000.selector,
                address(raffleContract),
                newCallbackGasLimit
            )
        );
        raffleContract.updateCallbackGasLimit(3500000);

        uint16 newAllowedConfirmationsLimit = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.notInAllowedConfirmationsLimitsOf_3_and_200.selector,
                address(raffleContract),
                newAllowedConfirmationsLimit
            )
        );
        raffleContract.updateRequestConfirmations(newAllowedConfirmationsLimit);

        newAllowedConfirmationsLimit = 500;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.notInAllowedConfirmationsLimitsOf_3_and_200.selector,
                address(raffleContract),
                newAllowedConfirmationsLimit
            )
        );
        raffleContract.updateRequestConfirmations(newAllowedConfirmationsLimit);
    }

    function test_entranceErrorWhileRaffleBusy() public {
        raffleContract.enterRaffle{value: 2 ether}();
        vm.warp(block.timestamp + raffleContract.getCooldownPeriod() + 1);
        vm.roll(block.number + 1);

        raffleContract.performUpkeep("");

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.lotterySystemBusy.selector,
                address(raffleContract),
                block.timestamp
            )
        );
        startHoax(makeAddr("newPlayer"), startFund);
        raffleContract.enterRaffle{value: 2 ether}();
    }
}
