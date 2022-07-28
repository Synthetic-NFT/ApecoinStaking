// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IYugaStaking {
    function claimNftReward(address tokenAddress, uint[] memory tokenIds) external returns (uint value);
    function claimApeCoinReward() external returns (uint value);
}