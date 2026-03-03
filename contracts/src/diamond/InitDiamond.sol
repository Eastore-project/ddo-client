// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDDOStorage} from "./libraries/LibDDOStorage.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "./interfaces/IDiamondLoupe.sol";
import {IERC165} from "./interfaces/IERC165.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";

contract InitDiamond {
    function init(address _paymentsContract, uint256 _commissionRateBps, uint256 _allocationLockupAmount) external {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        require(address(s.paymentsContract) == address(0), "Already initialized");
        s.paymentsContract = FilecoinPayV1(_paymentsContract);
        s.commissionRateBps = _commissionRateBps;
        s.allocationLockupAmount = _allocationLockupAmount;
        s.reentrancyStatus = LibDDOStorage.NOT_ENTERED;

        // Initialize ERC-165 interface support
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
    }
}
