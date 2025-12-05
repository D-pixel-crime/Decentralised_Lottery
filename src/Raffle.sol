// LPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {VRFConsumerBaseV2Plus} from "chainlink-vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-vrf/dev/libraries/VRFV2PlusClient.sol";

library math {
    function convertEthToDollars(
        uint256 funds,
        AggregatorV3Interface proxy
    ) internal view returns (uint256) {
        uint8 dec = proxy.decimals();
        (, int256 ans, , , ) = proxy.latestRoundData();
        uint256 rate = uint256(ans) * (10 ** (18 - dec));

        return (rate * funds) / 1e18;
    }
}

/**
 * @title Decentralized Randomiser
 * @author Deepak Kumar Pal
 * @notice This contract randomly selects participants of a lottery.
 * @dev Implements Chainlink VRF@2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    using math for uint256;

    address private constant VRF_COORDINATOR =
        0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    address private immutable i_owner;
    uint256 private immutable i_cooldownPeriod;
    bytes32 public s_keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 public s_callbackGasLimit = 40_000;
    uint16 public s_requestConfirmations = 3;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    uint256 private s_subscriptionId;
    AggregatorV3Interface private s_proxy;

    // Events
    event newPlayerAdded(address, address);
    event newWinnerRewarded(address, address, uint256, uint256);

    // Errors
    /**
     * @dev Each error's first field signifies the contract from which error is coming
     */
    error noPlayers(address);
    error rewardErrorForWinner(address, address);
    error notEnoughEntranceFee(address, uint256, uint256);
    error cooldownInEffect(address, uint256, uint256);
    error notInAllowedConfirmationsLimitsOf_3_and_200(address, uint256);
    error aboveAllowedGasLimitOf_2_500_000(address, uint256);

    constructor(
        uint256 entranceFee,
        uint256 cooldownPeriod,
        AggregatorV3Interface proxy
    ) VRFConsumerBaseV2Plus(VRF_COORDINATOR) {
        i_owner = msg.sender;
        i_entranceFee = entranceFee;
        i_cooldownPeriod = cooldownPeriod;
        s_proxy = proxy;
        s_lastTimestamp = block.timestamp;
    }

    function enterRaffle() public payable {
        uint256 convertedVal = msg.value.convertEthToDollars(s_proxy);
        if (convertedVal < i_entranceFee) {
            revert notEnoughEntranceFee(
                address(this),
                convertedVal,
                i_entranceFee
            );
        }
        s_players.push(payable(msg.sender));
        emit newPlayerAdded(address(this), msg.sender);
    }

    function pickWinner() public returns (uint256 requestId) {
        if (block.timestamp - s_lastTimestamp < i_cooldownPeriod) {
            revert cooldownInEffect(
                address(this),
                block.timestamp,
                s_lastTimestamp
            );
        }
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

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 len = s_players.length;
        if (len == 0) {
            revert noPlayers(address(this));
        }

        address payable winner = s_players[randomWords[0] % len];
        uint256 winningAmount = address(this).balance;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert rewardErrorForWinner(address(this), address(winner));
        }

        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit newWinnerRewarded(
            address(this),
            address(winner),
            winningAmount,
            s_lastTimestamp
        );
    }

    /**
     * @dev State-Variables updation functions
     */

    function updateEthToUsdProxy(AggregatorV3Interface newProxy) public {
        s_proxy = newProxy;
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
}
