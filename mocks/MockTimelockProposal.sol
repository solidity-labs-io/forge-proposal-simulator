// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Addresses} from "@addresses/Addresses.sol";

import {TimelockProposal} from "@proposals/TimelockProposal.sol";

import {IProxy} from "@interface/IProxy.sol";
import {IProxyAdmin} from "@interface/IProxyAdmin.sol";

import {MockUpgrade} from "@mocks/MockUpgrade.sol";

interface IUpgradeExecutor {
    function execute(address upgrader, bytes memory upgradeCalldata)
        external
        payable;
}

// Arbitrum upgrades must be done through a delegate call to a GAC deployed contract
contract GovernanceActionUpgradeWethGateway {
    function upgradeWethGateway(
        address proxyAdmin,
        address wethGatewayProxy,
        address wethGatewayImpl
    ) public {
        IProxyAdmin proxy = IProxyAdmin(proxyAdmin);
        proxy.upgrade(wethGatewayProxy, wethGatewayImpl);
    }
}

// Mock arbitrum outbox to return L2 timelock on l2ToL1Sender call
// otherwise L1 timelock reverts on onlyCounterpartTimelock modifier
contract MockOutbox {
    function l2ToL1Sender() external pure returns (address) {
        return 0x34d45e99f7D8c45ed05B5cA72D54bbD1fb3F98f0;
    }
}

contract MockTimelockProposal is TimelockProposal {
    function name() public pure override returns (string memory) {
        return "ARBITRUM_L1_TIMELOCK_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Mock proposal that upgrades the weth gateway";
    }

    function run() public override {
        setPrimaryForkId(vm.createSelectFork("mainnet"));

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        addresses = new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
        );

        setTimelock(addresses.getAddress("ARBITRUM_L1_TIMELOCK"));

        super.run();
    }

    function deploy() public override {
        if (!addresses.isAddressSet("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION"))
        {
            address mockUpgrade = address(new MockUpgrade());

            addresses.addAddress(
                "ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION", mockUpgrade, true
            );
        }

        if (!addresses.isAddressSet("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY")) {
            address gac = address(new GovernanceActionUpgradeWethGateway());
            addresses.addAddress("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY", gac, true);
        }
    }

    function preBuildMock() public override {
        address mockOutbox = address(new MockOutbox());

        vm.store(
            addresses.getAddress("ARBITRUM_BRIDGE"),
            bytes32(uint256(5)),
            bytes32(uint256(uint160(mockOutbox)))
        );
    }

    function build() public override buildModifier(address(timelock)) {
        IUpgradeExecutor upgradeExecutor = IUpgradeExecutor(
            addresses.getAddress("ARBITRUM_L1_UPGRADE_EXECUTOR")
        );

        upgradeExecutor.execute(
            addresses.getAddress("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY"),
            abi.encodeWithSelector(
                GovernanceActionUpgradeWethGateway.upgradeWethGateway.selector,
                addresses.getAddress("ARBITRUM_L1_PROXY_ADMIN"),
                addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY"),
                addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION")
            )
        );
    }

    function simulate() public override {
        // Proposer must be arbitrum bridge
        address proposer = addresses.getAddress("ARBITRUM_BRIDGE");

        // Executor can be anyone
        address executor = address(1);

        _simulateActions(proposer, executor);
    }

    function validate() public override {
        IProxy proxy =
            IProxy(addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY"));

        // implementation() caller must be the owner
        vm.startPrank(addresses.getAddress("ARBITRUM_L1_PROXY_ADMIN"));
        require(
            proxy.implementation()
                == addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION"),
            "Proxy implementation not set"
        );
        vm.stopPrank();
    }
}
