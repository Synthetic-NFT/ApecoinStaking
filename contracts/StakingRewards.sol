pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Inheritance
import "./interfaces/IStakingRewards.sol";

// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
contract StakingRewards is IStakingRewards, ReentrancyGuard, Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    /* ========== STATE VARIABLES ========== */

    ERC721 public BAYC;
    ERC721 public MAYC;
    ERC721 public BAKC;

    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    address public vault;

    uint256 public lastUpdateTime;
    uint256 public rewardsDuration;
    uint256 public periodFinish;

    mapping(address => uint256) public claimableRewards;
    mapping(address => uint256) public claimableRewardsRemaining;
    mapping(address => uint256) public rewardPerTokenStored;
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;
    mapping(address => uint256) private _totalSupply;
    mapping(address => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => EnumerableSet.UintSet)) private _userNFTDeposits;

    /* ========== CONSTRUCTOR ========== */

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _rewardsToken,
        address _stakingToken,
        address _BAYC,
        address _MAYC,
        address _BAKC,
        address _vault
    ) initializer public {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        BAYC = ERC721(_BAYC);
        MAYC = ERC721(_MAYC);
        BAKC = ERC721(_BAKC);
        vault = _vault;

        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}


    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256[] memory supplies) {
        address[] memory assetAddress = new address[](4);
        assetAddress[0] = address(stakingToken);
        assetAddress[1] = address(BAYC);
        assetAddress[2] = address(MAYC);
        assetAddress[3] = address(BAKC);

        supplies = new uint[](assetAddress.length);
        for (uint i = 0; i < assetAddress.length; i ++) {
            supplies[i] = _totalSupply[assetAddress[i]];
        }
        return supplies;
    }

    function balanceOf(address account) external view returns (uint256[] memory balances) {
        address[] memory assetAddress = new address[](4);
        assetAddress[0] = address(stakingToken);
        assetAddress[1] = address(BAYC);
        assetAddress[2] = address(MAYC);
        assetAddress[3] = address(BAKC);

        balances = new uint[](assetAddress.length);
        for (uint i = 0; i < assetAddress.length; i ++) {
            balances[i] = _balances[account][assetAddress[i]];
        }
        return balances;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }


    function earned(address account, address asset) public view returns (uint256) {
        return _balances[asset][account] * (rewardPerTokenStored[asset] - (userRewardPerTokenPaid[asset][account])) + (rewards[asset][account]);
    }


    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount, address asset) external nonReentrant whenNotPaused erc20Supported(asset) updateReward(msg.sender, asset) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply[asset] = _totalSupply[asset] + (amount);
        _balances[asset][msg.sender] = _balances[asset][msg.sender] + (amount);
        stakingToken.safeTransferFrom(msg.sender, address(vault), amount);
        emit Staked(msg.sender, amount);
    }

    function stakeNFT(uint[] calldata tokenIDs, address asset) external nonReentrant whenNotPaused erc721Supported(asset) updateReward(msg.sender, asset) {
        require(tokenIDs.length > 0, "Cannot stake 0");
        _totalSupply[asset] = _totalSupply[asset] + (tokenIDs.length);
        _balances[asset][msg.sender] = _balances[asset][msg.sender] + (tokenIDs.length);

        for (uint i = 0; i < tokenIDs.length; i ++) {
            ERC721(asset).safeTransferFrom(msg.sender, address(vault), tokenIDs[i]);
            _userNFTDeposits[asset][msg.sender].add(tokenIDs[i]);
        }
        emit NFTStaked(msg.sender, asset, tokenIDs);
    }

    function withdraw(uint256 amount, address asset) public nonReentrant whenNotPaused erc20Supported(asset) updateReward(msg.sender, asset) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply[asset] = _totalSupply[asset] - (amount);
        _balances[asset][msg.sender] = _balances[asset][msg.sender] - (amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function withdrawNFT(uint[] calldata tokenIDs, address asset) public nonReentrant whenNotPaused erc721Supported(asset) updateReward(msg.sender, asset) {
        require(tokenIDs.length > 0, "Cannot withdraw 0");
        _totalSupply[asset] = _totalSupply[asset] - (tokenIDs.length);
        _balances[asset][msg.sender] = _balances[asset][msg.sender] - (tokenIDs.length);
        for (uint i = 0; i < tokenIDs.length; i ++) {
            if (_userNFTDeposits[asset][msg.sender].contains(tokenIDs[i])) {
                ERC721(asset).safeTransferFrom(address(vault), msg.sender, tokenIDs[i]);
                _userNFTDeposits[asset][msg.sender].remove(tokenIDs[i]);
            }
        }
        emit NFTWithdrawn(msg.sender, asset, tokenIDs);
    }

    function getReward(address asset) public nonReentrant whenNotPaused assetSupported(asset) updateReward(msg.sender, asset) {
        uint256 reward = rewards[asset][msg.sender];
        require(reward<claimableRewardsRemaining[asset], "Not enough reward to be claimed");
        if (reward > 0) {
            rewards[asset][msg.sender] = 0;
            claimableRewardsRemaining[asset] = claimableRewardsRemaining[asset] - (reward);

            // Claim tokens from Yuga lab

            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, asset, reward);
        }
    }

    function exit(address asset) external {
        withdraw(_balances[asset][msg.sender], asset);
        getReward(asset);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */


    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    function updateClaimableRewards() private {
        // Need to communicate with Yuga's contract
        // update claimableRewards() by first calling Yuga lab's contract to get the total claimable rewards.
        // Then use a predetermined percentage to allocate reward to each pool

        // Need to communicate with Yuga's contract
        // update claimableRewards() by first calling Yuga lab's contract to get the total claimable rewards.
        // Then use a predetermined percentage to allocate reward to each pool


        //        address[] memory assetAddress = [address(stakingToken), address(BAYC), address(MAYC), address(BAKC)];
        //        for (uint i = 0; i < assetAddress.length; i++) {
        //            if (_totalSupply[assetAddress[i]] == 0) {
        //                rewardPerTokenStored[assetAddress[i]] = 0;
        //            } else {
        //                rewardPerTokenStored[assetAddress[i]] + (
        //                    lastClaimableRewards[assetAddress[i]] / (_totalSupply)
        //                );
        //            }
        //        }
//        address[] memory assetAddress = [address(stakingToken), address(BAYC), address(MAYC), address(BAKC)];
//        for (uint i = 0; i < assetAddress.length; i++) {
//            if (_totalSupply[assetAddress[i]] == 0) {
//                rewardPerTokenStored[assetAddress[i]] = 0;
//            } else {
//                rewardPerTokenStored[assetAddress[i]] + (
//                    lastClaimableRewards[assetAddress[i]] / (_totalSupply)
//                );
//            }
//        }
    }

    function updateRewardPerToken() private {
        address[] memory assetAddress = new address[](4);
        assetAddress[0] = address(stakingToken);
        assetAddress[1] = address(BAYC);
        assetAddress[2] = address(MAYC);
        assetAddress[3] = address(BAKC);

        for (uint i = 0; i < assetAddress.length; i++) {
            if (_totalSupply[assetAddress[i]] == 0) {
                rewardPerTokenStored[assetAddress[i]] = 0;
            } else {
                rewardPerTokenStored[assetAddress[i]] = rewardPerTokenStored[assetAddress[i]] + (
                    (claimableRewards[assetAddress[i]] - (claimableRewardsRemaining[assetAddress[i]])) / (_totalSupply[assetAddress[i]])
                );
                claimableRewardsRemaining[assetAddress[i]] = claimableRewards[assetAddress[i]];
            }
        }
    }


    /* ========== MODIFIERS ========== */

    modifier updateReward(address account, address asset) {
        updateClaimableRewards();
        updateRewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[asset][account] = earned(account, asset);
            userRewardPerTokenPaid[asset][account] = rewardPerTokenStored[asset];
        }
        _;
    }

    modifier erc20Supported(address asset) {
        require(
            asset == address(stakingToken),
            "ERC20 not supported"
        );
        _;
    }

    modifier assetSupported(address asset) {
        require(
            asset == address(stakingToken) ||
            asset == address(BAYC) ||
            asset == address(MAYC) ||
            asset == address(BAKC),
            "ERC20 not supported"
        );
        _;
    }

    modifier erc721Supported(address asset) {
        require(
            asset == address(BAYC) ||
            asset == address(MAYC) ||
            asset == address(BAKC),
            "ERC721 not supported"
        );
        _;
    }


    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event NFTStaked(address indexed user, address asset, uint[] tokenIDs);
    event NFTWithdrawn(address indexed user, address asset, uint[] tokenIDs);
    event RewardPaid(address indexed user, address asset, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
}