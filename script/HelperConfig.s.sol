// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    /** @dev VRF-Mock Constants */
    uint96 public constant MOCK_BASE_FEE = 0.025 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_LINK = 4e15;

    /** @dev Other Constants */
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        address vrfCoordinator;
        uint256 entranceFee;
        uint256 cooldownPeriod;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        uint16 requestConfirmations;
        uint256 subscriptionId;
        address ethToUsdDataFeedProxy;
        address linkMock;
        address account;
    }
    mapping(uint => NetworkConfig) internal networks;
    NetworkConfig internal localNetworkConfig;
    VRFCoordinatorV2_5Mock private vrfMock;
    LinkToken private linkMock;

    error unsupportedChain(uint256);

    constructor() {
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
                ),
                linkMock: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: vm.envAddress("SEPOLIA_ACCOUNT_ADDRESS")
            });
    }

    function getAnvilConfig() internal returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        linkMock = new LinkToken();
        vrfMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE,
            MOCK_WEI_PER_LINK
        );
        uint256 subId = vrfMock.createSubscription();
        vrfMock.fundSubscription(subId, 1000 ether);
        vm.stopBroadcast();

        return
            localNetworkConfig = NetworkConfig({
                vrfCoordinator: address(vrfMock),
                entranceFee: 0.01 ether,
                cooldownPeriod: 60,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                requestConfirmations: 3,
                subscriptionId: subId,
                ethToUsdDataFeedProxy: address(0),
                linkMock: address(linkMock),
                account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
            });
    }

    function getChainConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networks[chainId].vrfCoordinator != address(0)) {
            return networks[chainId];
        }

        if (chainId == LOCAL_CHAIN_ID) {
            return getAnvilConfig();
        }

        if (chainId == SEPOLIA_CHAIN_ID) {
            return networks[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
        }

        revert unsupportedChain(chainId);
    }

    function getChainConfig() public returns (NetworkConfig memory) {
        return getChainConfigByChainId(block.chainid);
    }
}
