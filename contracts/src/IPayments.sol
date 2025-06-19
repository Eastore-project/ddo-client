// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IPayments {
    // Structs
    struct Account {
        uint256 funds;
        uint256 lockupCurrent;
        uint256 lockupRate;
        uint256 lockupLastSettledAt;
    }

    struct RailView {
        address token;
        address from;
        address to;
        address operator;
        address arbiter;
        uint256 paymentRate;
        uint256 lockupPeriod;
        uint256 lockupFixed;
        uint256 settledUpTo;
        uint256 endEpoch;
        uint256 commissionRateBps;
    }

    struct OperatorApproval {
        bool isApproved;
        uint256 rateAllowance;
        uint256 lockupAllowance;
        uint256 rateUsage;
        uint256 lockupUsage;
        uint256 maxLockupPeriod;
    }

    struct RailInfo {
        uint256 railId;
        bool isTerminated;
        uint256 endEpoch;
    }

    // Public state variables (automatically create getters)
    function COMMISSION_MAX_BPS() external view returns (uint256);

    function PAYMENT_FEE_BPS() external view returns (uint256);

    function accumulatedFees(address token) external view returns (uint256);

    function hasCollectedFees(address token) external view returns (bool);

    // Core functions
    function initialize() external;

    function getRail(uint256 railId) external view returns (RailView memory);

    function setOperatorApproval(
        address token,
        address operator,
        bool approved,
        uint256 rateAllowance,
        uint256 lockupAllowance,
        uint256 maxLockupPeriod
    ) external;

    function terminateRail(uint256 railId) external;

    function deposit(
        address token,
        address to,
        uint256 amount
    ) external payable;

    function withdraw(address token, uint256 amount) external;

    function withdrawTo(address token, address to, uint256 amount) external;

    function createRail(
        address token,
        address from,
        address to,
        address arbiter,
        uint256 commissionRateBps
    ) external returns (uint256);

    function modifyRailLockup(
        uint256 railId,
        uint256 period,
        uint256 lockupFixed
    ) external;

    function modifyRailPayment(
        uint256 railId,
        uint256 newRate,
        uint256 oneTimePayment
    ) external;

    function settleTerminatedRailWithoutArbitration(
        uint256 railId
    )
        external
        returns (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalPaymentFee,
            uint256 totalOperatorCommission,
            uint256 finalSettledEpoch,
            string memory note
        );

    function settleRail(
        uint256 railId,
        uint256 untilEpoch
    )
        external
        returns (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalPaymentFee,
            uint256 totalOperatorCommission,
            uint256 finalSettledEpoch,
            string memory note
        );

    function withdrawFees(address token, address to, uint256 amount) external;

    function getAllAccumulatedFees()
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 count
        );

    function getRailsForPayerAndToken(
        address payer,
        address token
    ) external view returns (RailInfo[] memory);

    function getRailsForPayeeAndToken(
        address payee,
        address token
    ) external view returns (RailInfo[] memory);
}
