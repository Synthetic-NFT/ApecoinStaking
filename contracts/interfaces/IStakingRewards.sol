pragma solidity >=0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/istakingrewards
interface IStakingRewards {
    // Views

    function balanceOf(address account) external view returns (uint256[] memory);

    function earned(address account, address asset) external view returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);

    function totalSupply() external view returns (uint256[] memory);

    // Mutative

    function exit(address asset) external;

    function getReward(address asset) external;

    function stake(uint256 amount, address asset) external;

    function stakeNFT(uint[] calldata tokenIDs, address asset) external;

    function withdraw(uint256 amount, address asset) external;

    function withdrawNFT(uint[] calldata tokenIDs, address asset) external;
}