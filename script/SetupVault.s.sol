// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/destination/LendingVault.sol";

/**
 * @title SetupVault
 * @notice Sets the authorized ReactVM on the LendingVault after Reactive deployment
 * @dev Run with: forge script script/SetupVault.s.sol:SetupVault --rpc-url $SEPOLIA_RPC_URL --broadcast
 */
contract SetupVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address vaultAddress = vm.envAddress("LENDING_VAULT_ADDRESS");
        address reactVMId = vm.envAddress("REACTVM_ID"); // Deployer address on Reactive Network

        console.log("Setting up LendingVault");
        console.log("Vault:", vaultAddress);
        console.log("ReactVM ID:", reactVMId);

        vm.startBroadcast(deployerPrivateKey);

        LendingVault vault = LendingVault(vaultAddress);
        vault.setAuthorizedReactVM(reactVMId);
        
        console.log("Authorized ReactVM set successfully!");

        vm.stopBroadcast();
    }
}
