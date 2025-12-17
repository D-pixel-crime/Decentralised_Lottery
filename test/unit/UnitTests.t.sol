// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract UnitTests is Test {
    Raffle raffleContract;
    HelperConfig.NetworkConfig config;
    address player = makeAddr("user");
    uint256 startFund = 10 ether;

    /**  @dev Raffle Errors */
    error notEnoughEntranceFee(address, uint256, uint256);

    /**  @dev Raffle Events */
    event newPlayerAdded(address, address);

    function setUp() external {
        (raffleContract, config) = (new DeployRaffle()).run();
        startHoax(player, startFund);
    }

    /** @dev Testing two variables is enough */
    function test_stateVariablesAreSetOrNot() public view {
        vm.assertEq(raffleContract.getEntranceFee(), config.entranceFee);
        vm.assertEq(raffleContract.getCooldownPeriod(), config.cooldownPeriod);
    }

    function test_raffleEntry() public {
        uint256 fundVal = 0.0001 ether;

        vm.expectRevert(
            abi.encodeWithSelector(
                notEnoughEntranceFee.selector,
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

        vm.assertTrue(beforePlayer + 1 == afterPlayer);
        vm.assertTrue(beforeReward + fundVal == afterReward);
    }
}
