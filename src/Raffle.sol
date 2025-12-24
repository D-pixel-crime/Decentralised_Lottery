// LPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {VRFConsumerBaseV2Plus} from "chainlink-vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-vrf/dev/libraries/VRFV2PlusClient.sol";
import {ReentrancyGuard} from "reentrancy-gaurd/ReentrancyGuard.sol";

/**
 * @title Decentralized Randomiser
 * @author Deepak Kumar Pal
 * @notice This contract randomly selects participants of a lottery.
 * @dev Implements Chainlink VRF@2.5
 */
contract Raffle is VRFConsumerBaseV2Plus, ReentrancyGuard {
    enum RaffleState {
        IDLE,
        BUSY
    }

    uint32 private constant NUM_WORDS = 1;
    address private immutable i_vrfCoordinator;
    uint256 private immutable i_entranceFee;
    address private immutable i_owner;
    uint256 private immutable i_cooldownPeriod;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    uint256 private s_subscriptionId;
    RaffleState private s_currRaffleState;
    bytes32 public s_keyHash;
    uint32 public s_callbackGasLimit;
    uint16 public s_requestConfirmations;
    AggregatorV3Interface public s_ethToUsdDataFeedProxy;

    // Errors
    /**
     * @dev Each error's first field signifies the contract from which error is coming
     */
    error rewardCriteriasNotSatisfied(address, uint256, uint256, RaffleState);
    error rewardErrorForWinner(address, address);
    error notEnoughEntranceFee(address, uint256, uint256);
    error lotterySystemBusy(address, uint256);
    error notInAllowedConfirmationsLimitsOf_3_and_200(address, uint16);
    error aboveAllowedGasLimitOf_2_500_000(address, uint32);

    // Events
    event newPlayerAdded(address, address);
    event newWinnerRewarded(address, address, uint256, uint256);

    constructor(
        address vrfCoordinator,
        uint256 entranceFee,
        uint256 cooldownPeriod,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint256 subscriptionId,
        address ethToUsdDataFeedProxy
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_vrfCoordinator = vrfCoordinator;
        i_owner = msg.sender;
        i_entranceFee = entranceFee;
        i_cooldownPeriod = cooldownPeriod;
        s_keyHash = keyHash;
        s_callbackGasLimit = callbackGasLimit;
        s_requestConfirmations = requestConfirmations;
        s_subscriptionId = subscriptionId;
        s_lastTimestamp = block.timestamp;
        s_currRaffleState = RaffleState.IDLE;
        s_ethToUsdDataFeedProxy = AggregatorV3Interface(ethToUsdDataFeedProxy);
    }

    function performUpkeep(
        bytes calldata /*performData*/
    ) external returns (uint256 requestId) {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert rewardCriteriasNotSatisfied(
                address(this),
                s_players.length,
                block.timestamp - s_lastTimestamp,
                s_currRaffleState
            );
        }

        s_currRaffleState = RaffleState.BUSY;

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: s_requestConfirmations,
                callbackGasLimit: s_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function enterRaffle() public payable {
        if (s_currRaffleState != RaffleState.IDLE) {
            revert lotterySystemBusy(address(this), block.timestamp);
        }
        if (msg.value < i_entranceFee) {
            revert notEnoughEntranceFee(
                address(this),
                msg.value,
                i_entranceFee
            );
        }
        s_players.push(payable(msg.sender));
        emit newPlayerAdded(address(this), msg.sender);
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool playersPresent = s_players.length > 0;
        bool hasCooldownTimePassed = block.timestamp - s_lastTimestamp >
            i_cooldownPeriod;
        bool isRaffleIdle = s_currRaffleState == RaffleState.IDLE;

        upkeepNeeded = playersPresent && hasCooldownTimePassed && isRaffleIdle;
        return (upkeepNeeded, "");
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override nonReentrant {
        uint256 len = s_players.length;
        if (s_currRaffleState == RaffleState.BUSY) {
            revert lotterySystemBusy(address(this), block.timestamp);
        }

        address payable winner = s_players[randomWords[0] % len];
        uint256 winningAmount = address(this).balance;

        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert rewardErrorForWinner(address(this), address(winner));
        }

        emit newWinnerRewarded(
            address(this),
            address(winner),
            winningAmount,
            s_lastTimestamp
        );

        s_currRaffleState = RaffleState.IDLE;
    }

    /**
     * @dev State-Variables updation functions
     */

    function updateEthToUsdDataFeedProxy(
        AggregatorV3Interface newProxy
    ) public {
        s_ethToUsdDataFeedProxy = newProxy;
    }

    function updateSubscriptionId(uint256 newSubscriptionId) public {
        s_subscriptionId = newSubscriptionId;
    }

    function updateCallbackGasLimit(uint32 newCallbackGasLimit) public {
        if (newCallbackGasLimit > 2500000) {
            revert aboveAllowedGasLimitOf_2_500_000(
                address(this),
                newCallbackGasLimit
            );
        }
        s_callbackGasLimit = newCallbackGasLimit;
    }

    function updateRequestConfirmations(uint16 newRequestConfirmations) public {
        if (newRequestConfirmations < 3 || newRequestConfirmations > 200) {
            revert notInAllowedConfirmationsLimitsOf_3_and_200(
                address(this),
                newRequestConfirmations
            );
        }
        s_requestConfirmations = newRequestConfirmations;
    }

    function updateKeyHash(bytes32 newKeyHash) public {
        s_keyHash = newKeyHash;
    }

    /**
     * @dev Getter functions for private state variables
     */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getCooldownPeriod() public view returns (uint256) {
        return i_cooldownPeriod;
    }

    function getTotalPlayersAndRewardMoney()
        public
        view
        returns (uint256, uint256)
    {
        return (s_players.length, address(this).balance);
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_currRaffleState;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
}
