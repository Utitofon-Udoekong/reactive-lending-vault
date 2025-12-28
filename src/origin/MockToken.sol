// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockToken
 * @notice A mock ERC20 token for testing purposes
 * @dev Users can mint tokens for testing the lending vault
 */
contract MockToken is ERC20, Ownable {
    uint8 private _decimals;

    /**
     * @notice Constructor
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals_ Token decimals
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
    }

    /**
     * @notice Returns token decimals
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mint tokens to an address
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Anyone can mint tokens for testing (faucet function)
     * @param amount Amount to mint (max 1000 tokens per call)
     */
    function faucet(uint256 amount) external {
        require(amount <= 1000 * 10 ** _decimals, "Max 1000 tokens per faucet call");
        _mint(msg.sender, amount);
    }
}
