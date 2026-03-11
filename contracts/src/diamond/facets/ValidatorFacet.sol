// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IValidator} from "filecoin-pay/FilecoinPayV1.sol";
import {LibDDOStorage} from "../libraries/LibDDOStorage.sol";

contract ValidatorFacet is IValidator {
    function validatePayment(uint256 railId, uint256 proposedAmount, uint256 fromEpoch, uint256 toEpoch, uint256)
        external
        view
        returns (ValidationResult memory result)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        uint64 allocationId = s.railIdToAllocationId[railId];

        if (allocationId != 0) {
            LibDDOStorage.AllocationInfo storage info = s.allocationInfos[allocationId];
            if (info.activated && s.blacklistedSectors[info.provider][info.sectorNumber]) {
                return ValidationResult({modifiedAmount: 0, settleUpto: fromEpoch, note: "Sector blacklisted"});
            }
        }

        result = ValidationResult({modifiedAmount: proposedAmount, settleUpto: toEpoch, note: ""});
    }

    function railTerminated(uint256, address, uint256) external {}
}
