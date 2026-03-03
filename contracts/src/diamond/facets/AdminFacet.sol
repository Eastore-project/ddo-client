// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDDOStorage} from "../libraries/LibDDOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";

contract AdminFacet {
    function setPaymentsContract(address _paymentsContract) external {
        LibDiamond.enforceIsContractOwner();
        if (_paymentsContract == address(0)) {
            revert LibDDOStorage.DDOTypes__InvalidPaymentsContract();
        }
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        address oldContract = address(s.paymentsContract);
        s.paymentsContract = FilecoinPayV1(_paymentsContract);
        emit LibDDOStorage.PaymentsContractUpdated(oldContract, _paymentsContract);
    }

    function setCommissionRate(uint256 _commissionRateBps) external {
        LibDiamond.enforceIsContractOwner();
        if (_commissionRateBps > LibDDOStorage.MAX_COMMISSION_RATE_BPS) {
            revert LibDDOStorage.DDOTypes__CommissionRateExceedsMaximum();
        }
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        uint256 oldRate = s.commissionRateBps;
        s.commissionRateBps = _commissionRateBps;
        emit LibDDOStorage.CommissionRateUpdated(oldRate, _commissionRateBps);
    }

    function setAllocationLockupAmount(uint256 _amount) external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        uint256 oldAmount = s.allocationLockupAmount;
        s.allocationLockupAmount = _amount;
        emit LibDDOStorage.AllocationLockupAmountUpdated(oldAmount, _amount);
    }

    function pause() external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        if (s.paused) revert LibDDOStorage.EnforcedPause();
        s.paused = true;
        emit LibDDOStorage.Paused(msg.sender);
    }

    function unpause() external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        if (!s.paused) revert LibDDOStorage.ExpectedPause();
        s.paused = false;
        emit LibDDOStorage.Unpaused(msg.sender);
    }

    function paused() external view returns (bool) {
        return LibDDOStorage.getStorage().paused;
    }

    function blacklistSector(uint64 providerId, uint64 sectorNumber, bool blacklisted) external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        s.blacklistedSectors[providerId][sectorNumber] = blacklisted;
        emit LibDDOStorage.SectorBlacklisted(providerId, sectorNumber, blacklisted);
    }

    function isSectorBlacklisted(uint64 providerId, uint64 sectorNumber) external view returns (bool) {
        return LibDDOStorage.getStorage().blacklistedSectors[providerId][sectorNumber];
    }

    function rescueFIL(address payable to) external {
        LibDiamond.enforceIsContractOwner();
        require(to != address(0), "Zero address");
        (bool success,) = to.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    function paymentsContract() external view returns (FilecoinPayV1) {
        return LibDDOStorage.getStorage().paymentsContract;
    }

    function commissionRateBps() external view returns (uint256) {
        return LibDDOStorage.getStorage().commissionRateBps;
    }

    function allocationLockupAmount() external view returns (uint256) {
        return LibDDOStorage.getStorage().allocationLockupAmount;
    }

    function MAX_COMMISSION_RATE_BPS() external pure returns (uint256) {
        return LibDDOStorage.MAX_COMMISSION_RATE_BPS;
    }

    function EPOCHS_PER_MONTH() external pure returns (uint256) {
        return LibDDOStorage.EPOCHS_PER_MONTH;
    }

    function EPOCHS_PER_DAY() external pure returns (uint256) {
        return LibDDOStorage.EPOCHS_PER_DAY;
    }

    function DATACAP_RECEIVER_HOOK_METHOD_NUM() external pure returns (uint64) {
        return LibDDOStorage.DATACAP_RECEIVER_HOOK_METHOD_NUM;
    }

    function SECTOR_CONTENT_CHANGED_METHOD_NUM() external pure returns (uint64) {
        return LibDDOStorage.SECTOR_CONTENT_CHANGED_METHOD_NUM;
    }

    function DATACAP_ACTOR_ETH_ADDRESS() external pure returns (address) {
        return LibDDOStorage.DATACAP_ACTOR_ETH_ADDRESS;
    }
}
