// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IVault.sol";

contract AutoCompounder is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    struct HarvestRecord {
        uint totalReward;
        uint timestamp;
        uint nonce;
    }

    // nonce => HarvestRecord
    mapping (uint => HarvestRecord) public harvestHistory;
    uint public currentNonce;
    address public vaultAddress;
    mapping (address => uint) public harvestInterval;
    mapping (address => uint) public lastHarvest;
    uint public nextHarvestTime;
    EnumerableSetUpgradeable.AddressSet private _tokenAddresses;

    event RegisteredTokenAddress(address tokenAddress, uint interval);
    event DeregisteredTokenAddress(address tokenAddress);
    event TriggeredHarvest(address tokenAddress);
    event HarvestFailed(address tokenAddress, string reason);
    event PausedHarvest(address tokenAddress);
    event PausedAll();
    event UnpausedHarvest(address tokenAddress);

    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(address vaultAddress_) initializer public {
        __Ownable_init();
        vaultAddress = vaultAddress_;
    }

    function register(address[] calldata tokenAddress_,  uint[] calldata interval_) external onlyOwner {
        require(tokenAddress_.length == interval_.length, "Value lengths do not match.");
        require(tokenAddress_.length > 0, "The length is 0");
        for(uint i = 0; i < tokenAddress_.length; i++) {
            require(tokenAddress_[i] != address(0));
            harvestInterval[tokenAddress_[i]] = interval_[i];
            _tokenAddresses.add(tokenAddress_[i]);
            emit RegisteredTokenAddress(tokenAddress_[i], interval_[i]);
            _setNextHarvestTime(block.timestamp + harvestInterval[tokenAddress_[i]]);
        }
    }

    function harvest() external onlyOwner returns (bool) {
        require(_tokenAddresses.length() > 0, "No harvest contract is registered.");
        uint length = _tokenAddresses.length();
        bool success = true;
        // reset nextHarvestTime
        _setNextHarvestTime(0);
        currentNonce += 1;
        HarvestRecord memory record = HarvestRecord({
            totalReward: 0,
            timestamp: block.timestamp,
            nonce: currentNonce
        });
        harvestHistory[currentNonce] =  record;
        for (uint i = 0; i < length; i++) {
            address tokenAddr = _tokenAddresses.at(i);
            // no need to do harvest this time.
            if (block.timestamp < harvestInterval[tokenAddr] + lastHarvest[tokenAddr]) {
                _setNextHarvestTime(harvestInterval[tokenAddr] + lastHarvest[tokenAddr]);
                continue;
            }
            IVault vault = IVault(vaultAddress);
            try vault.harvestReward(tokenAddr) returns (uint rewards) {
                harvestHistory[currentNonce].totalReward += rewards;
                emit TriggeredHarvest(tokenAddr);
            } catch Error(string memory reason) {
                emit HarvestFailed(tokenAddr, reason);
                success = false;
            } catch {
                emit HarvestFailed(tokenAddr, "harvest contract encountered internal error.");
                success = false;
            }
            lastHarvest[tokenAddr] = block.timestamp;
            _setNextHarvestTime(harvestInterval[tokenAddr] + lastHarvest[tokenAddr]);
        }
        return success;
    }

    function pause(address[] calldata tokenAddress_) external onlyOwner {
        require(tokenAddress_.length > 0, "length is 0.");
        for (uint i = 0; i < tokenAddress_.length; i++) {
            _pause(tokenAddress_[i]);
        }
    }

    function pauseAll() external onlyOwner {
        uint length = _tokenAddresses.length();
        require(length > 0, "No harvest contract is registered.");
        for (uint i = 0; i < length; i++) {
            _pause(_tokenAddresses.at(i));
        }
        emit PausedAll();
    }

    function unpause(address[] calldata tokenAddress_) external onlyOwner {
        require(tokenAddress_.length > 0, "length is 0.");
        for (uint i = 0; i < tokenAddress_.length; i++) {
            require(tokenAddress_[i] != address(0));
            IVault vault = IVault(vaultAddress);
            vault.unpause(tokenAddress_[i]);
            emit UnpausedHarvest(tokenAddress_[i]);
        }
    }

    function deregister(address[] calldata tokenAddress_) external onlyOwner {
        require(tokenAddress_.length > 0, "The length is 0");
        for(uint i = 0; i < tokenAddress_.length; i++){
            require(tokenAddress_[i] != address(0));

            require(_tokenAddresses.remove(tokenAddress_[i]), "AutoCompounder:: contract not registered");
            delete harvestInterval[tokenAddress_[i]];
            delete lastHarvest[tokenAddress_[i]];

            emit DeregisteredTokenAddress(tokenAddress_[i]);
        }
    }

    function harvestCount() public view returns (uint) {
        return _tokenAddresses.length();
    }

    function harvestAtIndex(uint index) public view returns (address) {
        require(index < _tokenAddresses.length(), "AutoCompounder:: index out of bounds");
        return _tokenAddresses.at(index);
    }

    function _pause(address tokenAddr) internal {
        require(tokenAddr != address(0));
        IVault vault = IVault(vaultAddress);
        vault.pause(tokenAddr);
        emit PausedHarvest(tokenAddr);
    }

    function _setNextHarvestTime(uint nextHarvestTime_) internal {
        if (nextHarvestTime == 0 || nextHarvestTime > nextHarvestTime_)
            nextHarvestTime = nextHarvestTime_;
    }
}