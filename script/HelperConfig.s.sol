// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    /** @dev VRF-Mock Constants */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_LINK = 4e15;

    /** @dev Other Constants */
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants, VRFCoordinatorV2_5Mock {
    struct NetworkConfig {
        address vrfCoordinator;
        uint256 entranceFee;
        uint256 cooldownPeriod;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        uint16 requestConfirmations;
        uint256 subscriptionId;
        address ethToUsdDataFeedProxy;
    }
    mapping(uint => NetworkConfig) internal networks;
    NetworkConfig internal localNetworkConfig;

    error unsupportedChain(uint256);

    constructor()
        VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_LINK)
    {
        networks[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getSepoliaConfig() internal view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                vrfCoordinator: vm.envAddress("SEPOLIA_VRF_COORDINATOR"),
                entranceFee: 0.01 ether,
                cooldownPeriod: 24 hours,
                keyHash: vm.envBytes32("SEPOLIA_VRF_KEY_HASH"),
                callbackGasLimit: 500000,
                requestConfirmations: 3,
                subscriptionId: vm.envUint("SEPOLIA_VRF_SUBSCRIPTION_ID"),
                ethToUsdDataFeedProxy: vm.envAddress(
                    "SEPOLIA_ETH_TO_USD_DATA_FEED_PROXY"
                )
            });
    }

    function getAnvilConfig() internal returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock mock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE,
            MOCK_WEI_PER_LINK
        );
        vm.stopBroadcast();

        return
            localNetworkConfig = NetworkConfig({
                vrfCoordinator: address(mock),
                entranceFee: 0.01 ether,
                cooldownPeriod: 60,
                keyHash: vm.envBytes32("SEPOLIA_VRF_KEY_HASH"),
                callbackGasLimit: 500000,
                requestConfirmations: 3,
                subscriptionId: vm.envUint("SEPOLIA_VRF_SUBSCRIPTION_ID"),
                ethToUsdDataFeedProxy: vm.envAddress(
                    "SEPOLIA_ETH_TO_USD_DATA_FEED_PROXY"
                )
            });
    }

    function getChainConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networks[chainId].vrfCoordinator != address(0)) {
            return networks[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getAnvilConfig();
        } else revert unsupportedChain(block.chainid);
    }

    function getChainConfig() public returns (NetworkConfig memory) {
        return getChainConfigByChainId(block.chainid);
    }
}
