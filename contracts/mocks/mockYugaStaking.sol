pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


contract mockYugaStaking {
    /* ========== CONSTRUCTOR ========== */
    uint numCall;

    // Creating a constructor
    // to set value of 'str'
    constructor() public {
        numCall = 0;
    }

    function getReward() public returns (uint reward) {
        reward = (numCall % 10) * 100;
        numCall += 1;
    }

}