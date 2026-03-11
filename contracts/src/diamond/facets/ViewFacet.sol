// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDDOStorage} from "../libraries/LibDDOStorage.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {VerifRegTypes} from "lib/filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {VerifRegAPI} from "lib/filecoin-solidity/contracts/v0.8/VerifRegAPI.sol";
import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";

contract ViewFacet {
    function getAllSPIds() external view returns (uint64[] memory) {
        return LibDDOStorage.getStorage().registeredSPIds;
    }

    function getAllocationIdsForClient(address clientAddress) external view returns (uint64[] memory) {
        return LibDDOStorage.getStorage().allocationIdsByClient[clientAddress];
    }

    function getAllocationIdsForProvider(uint64 providerId) external view returns (uint64[] memory) {
        return LibDDOStorage.getStorage().allocationIdsByProvider[providerId];
    }

    function allocationInfos(uint64 allocationId)
        external
        view
        returns (
            address client,
            uint64 provider,
            bool activated,
            bytes32 pieceCidHash,
            address paymentToken,
            uint64 pieceSize,
            uint256 railId,
            uint256 pricePerBytePerEpoch,
            uint64 sectorNumber
        )
    {
        LibDDOStorage.AllocationInfo storage info = LibDDOStorage.getStorage().allocationInfos[allocationId];
        return (
            info.client,
            info.provider,
            info.activated,
            info.pieceCidHash,
            info.paymentToken,
            info.pieceSize,
            info.railId,
            info.pricePerBytePerEpoch,
            info.sectorNumber
        );
    }

    function getAllocationRailInfo(uint64 allocationId)
        external
        view
        returns (uint256 railId, uint64 providerId, FilecoinPayV1.RailView memory railView)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        LibDDOStorage.AllocationInfo memory info = s.allocationInfos[allocationId];
        railId = info.railId;
        providerId = info.provider;

        if (railId > 0 && address(s.paymentsContract) != address(0)) {
            railView = s.paymentsContract.getRail(railId);
        }
    }

    function getClaimInfo(uint64 providerActorId, uint64 claimId)
        public
        view
        returns (VerifRegTypes.GetClaimsReturn memory)
    {
        CommonTypes.FilActorId[] memory claimIdsToFetch = new CommonTypes.FilActorId[](1);
        claimIdsToFetch[0] = CommonTypes.FilActorId.wrap(claimId);

        VerifRegTypes.GetClaimsParams memory claimParams = VerifRegTypes.GetClaimsParams({
            provider: CommonTypes.FilActorId.wrap(providerActorId),
            claim_ids: claimIdsToFetch
        });

        (int256 exitCode, VerifRegTypes.GetClaimsReturn memory getClaimsReturnData) = VerifRegAPI.getClaims(claimParams);

        if (exitCode != 0) revert LibDDOStorage.DDOTypes__GetClaimsFailed(exitCode);

        return getClaimsReturnData;
    }

    /// @notice Verifies an allocation exists, was issued by this contract, and is not yet claimed.
    /// @dev Called by Curio via eth_call. Takes ABI-encoded uint64 allocationId.
    /// @param params ABI-encoded (uint64 allocationId)
    /// @return The allocation ID as int64, or reverts if not found or already claimed
    function getDealId(bytes calldata params) external view returns (int64) {
        uint64 allocationId = abi.decode(params, (uint64));
        LibDDOStorage.AllocationInfo storage info = LibDDOStorage.getStorage().allocationInfos[allocationId];
        require(info.client != address(0), "allocation not found");
        require(!info.activated, "allocation already claimed");
        return int64(uint64(allocationId));
    }

    /// @notice Returns the version of this facet
    /// @return The version string
    function getVersion() external pure returns (string memory) {
        return "v1";
    }

    function getClaimInfoForClient(address clientAddress, uint64 claimId)
        external
        view
        returns (VerifRegTypes.Claim[] memory claims)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();

        // Validate claim belongs to client
        bool claimFoundLocally;
        uint64[] memory clientAllocations = s.allocationIdsByClient[clientAddress];
        for (uint256 i; i < clientAllocations.length; i++) {
            if (clientAllocations[i] == claimId) {
                claimFoundLocally = true;
                break;
            }
        }
        if (!claimFoundLocally) revert LibDDOStorage.DDOTypes__InvalidClaimIdForClient();

        uint64 providerActorId = s.allocationInfos[claimId].provider;
        if (providerActorId == 0) revert LibDDOStorage.DDOTypes__InvalidProvider();

        CommonTypes.FilActorId[] memory claimIdsToFetch = new CommonTypes.FilActorId[](1);
        claimIdsToFetch[0] = CommonTypes.FilActorId.wrap(claimId);

        VerifRegTypes.GetClaimsParams memory claimParams = VerifRegTypes.GetClaimsParams({
            provider: CommonTypes.FilActorId.wrap(providerActorId),
            claim_ids: claimIdsToFetch
        });

        (int256 exitCode, VerifRegTypes.GetClaimsReturn memory getClaimsReturn) = VerifRegAPI.getClaims(claimParams);

        if (exitCode != 0) revert LibDDOStorage.DDOTypes__GetClaimsFailed(exitCode);

        if (getClaimsReturn.batch_info.success_count == 0 || getClaimsReturn.claims.length == 0) {
            revert LibDDOStorage.DDOTypes__NoClaimsFound();
        }

        return getClaimsReturn.claims;
    }
}
