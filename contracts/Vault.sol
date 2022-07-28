// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IYugaStaking.sol";
// TODO: support fine-grained access control for different operators
contract Vault is IVault, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    address public BAYC;
    address public MAYC;
    address public BAKC;
    address public APECOIN;
    EnumerableSetUpgradeable.AddressSet private nftAddress;
    // nft address => token ids[]
    mapping(address => uint[]) allTokens;
    mapping(address => bool) paused;
    address yugaStaking;

    event Paused(address tokenAddress);
    event Unpaused(address tokenAddress);
    event ClaimedReward(address tokenAddress);

    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize() initializer public {
        __Ownable_init();

        BAYC = address(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
        MAYC = address(0x60E4d786628Fea6478F785A6d7e704777c86a7c6);
        BAKC = address(0xba30E5F9Bb24caa003E9f2f0497Ad287FDF95623);
        APECOIN = address(0x4d224452801ACEd8B2F0aebE155379bb5D594381);

        nftAddress.add(BAYC);
        nftAddress.add(MAYC);
        nftAddress.add(BAKC);
    }

    function harvestReward(address tokenAddress) external onlyOwner returns (uint value) {
        require(tokenAddress != address(0), "must be a valid address");
        value = 0;
        if (nftAddress.contains(tokenAddress)) {
            if (allTokens[tokenAddress].length > 0 && ! paused[tokenAddress]) {
                uint[] memory tokenIds = allTokens[tokenAddress];
                value = IYugaStaking(yugaStaking).claimNftReward(tokenAddress, tokenIds);
            }
        } else if (tokenAddress == APECOIN) {
            if (! paused[tokenAddress]) {
                value = IYugaStaking(yugaStaking).claimApeCoinReward();
            }
        } else {
            revert("invalid token address");
        }
        emit ClaimedReward(tokenAddress);
    }

    function pause(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0));
        require(nftAddress.contains(tokenAddress) || APECOIN == tokenAddress);
        paused[tokenAddress] = true;
        emit Paused(tokenAddress);
    }

    function unpause(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0));
        require(nftAddress.contains(tokenAddress) || APECOIN == tokenAddress);
        paused[tokenAddress] = false;
        emit Unpaused(tokenAddress);
    }
}
