// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IVault {
    function harvestReward(address tokenAddress) external returns (uint value);
    function pause(address tokenAddress) external;
    function unpause(address tokenAddress) external;
}
