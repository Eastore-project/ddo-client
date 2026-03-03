// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";

import {Diamond} from "src/diamond/Diamond.sol";
import {DiamondCutFacet} from "src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/diamond/facets/OwnershipFacet.sol";
import {IDiamondCut} from "src/diamond/interfaces/IDiamondCut.sol";
import {InitDiamond} from "src/diamond/InitDiamond.sol";

import {AdminFacet} from "src/diamond/facets/AdminFacet.sol";
import {SPFacet} from "src/diamond/facets/SPFacet.sol";
import {AllocationFacet} from "src/diamond/facets/AllocationFacet.sol";
import {ViewFacet} from "src/diamond/facets/ViewFacet.sol";
import {ValidatorFacet} from "src/diamond/facets/ValidatorFacet.sol";

contract DeployDiamond is Script {
    function run() external {
        address paymentsContract = vm.envAddress("PAYMENTS_CONTRACT_ADDRESS");
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        console.log("Deployer:", deployer);
        console.log("Payments contract:", paymentsContract);

        // Auth is handled entirely via CLI flags: --account, --private-key, or --keystore
        vm.startBroadcast();

        // 1. Deploy DiamondCutFacet
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet deployed at:", address(diamondCutFacet));

        // 2. Deploy Diamond with DiamondCutFacet + owner
        Diamond diamond = new Diamond(deployer, address(diamondCutFacet));
        console.log("Diamond deployed at:", address(diamond));

        // 3. Deploy remaining facets
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        AdminFacet adminFacet = new AdminFacet();
        SPFacet spFacet = new SPFacet();
        AllocationFacet allocationFacet = new AllocationFacet();
        ViewFacet viewFacet = new ViewFacet();
        ValidatorFacet validatorFacet = new ValidatorFacet();

        console.log("DiamondLoupeFacet:", address(diamondLoupeFacet));
        console.log("OwnershipFacet:", address(ownershipFacet));
        console.log("AdminFacet:", address(adminFacet));
        console.log("SPFacet:", address(spFacet));
        console.log("AllocationFacet:", address(allocationFacet));
        console.log("ViewFacet:", address(viewFacet));
        console.log("ValidatorFacet:", address(validatorFacet));

        // 4. Deploy InitDiamond
        InitDiamond initDiamond = new InitDiamond();
        console.log("InitDiamond:", address(initDiamond));

        // 5. Build FacetCut array
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](7);

        // DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // OwnershipFacet
        bytes4[] memory ownerSelectors = new bytes4[](2);
        ownerSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownerSelectors[1] = OwnershipFacet.owner.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownerSelectors
        });

        // AdminFacet
        bytes4[] memory adminSelectors = new bytes4[](18);
        adminSelectors[0] = AdminFacet.setPaymentsContract.selector;
        adminSelectors[1] = AdminFacet.setCommissionRate.selector;
        adminSelectors[2] = AdminFacet.setAllocationLockupAmount.selector;
        adminSelectors[3] = AdminFacet.paymentsContract.selector;
        adminSelectors[4] = AdminFacet.commissionRateBps.selector;
        adminSelectors[5] = AdminFacet.allocationLockupAmount.selector;
        adminSelectors[6] = AdminFacet.MAX_COMMISSION_RATE_BPS.selector;
        adminSelectors[7] = AdminFacet.EPOCHS_PER_MONTH.selector;
        adminSelectors[8] = AdminFacet.EPOCHS_PER_DAY.selector;
        adminSelectors[9] = AdminFacet.DATACAP_RECEIVER_HOOK_METHOD_NUM.selector;
        adminSelectors[10] = AdminFacet.SECTOR_CONTENT_CHANGED_METHOD_NUM.selector;
        adminSelectors[11] = AdminFacet.DATACAP_ACTOR_ETH_ADDRESS.selector;
        adminSelectors[12] = AdminFacet.pause.selector;
        adminSelectors[13] = AdminFacet.unpause.selector;
        adminSelectors[14] = AdminFacet.paused.selector;
        adminSelectors[15] = AdminFacet.rescueFIL.selector;
        adminSelectors[16] = AdminFacet.blacklistSector.selector;
        adminSelectors[17] = AdminFacet.isSectorBlacklisted.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // SPFacet
        bytes4[] memory spSelectors = new bytes4[](17);
        spSelectors[0] = SPFacet.registerSP.selector;
        spSelectors[1] = SPFacet.updateSPConfig.selector;
        spSelectors[2] = SPFacet.addSPToken.selector;
        spSelectors[3] = SPFacet.updateSPToken.selector;
        spSelectors[4] = SPFacet.removeSPToken.selector;
        spSelectors[5] = SPFacet.deactivateSP.selector;
        spSelectors[6] = SPFacet.spConfigs.selector;
        spSelectors[7] = SPFacet.getSPTokenPrice.selector;
        spSelectors[8] = SPFacet.getSPActivePricePerBytePerEpoch.selector;
        spSelectors[9] = SPFacet.getSPTokenPricePerTBPerMonth.selector;
        spSelectors[10] = SPFacet.getSPAllTokenPricesPerMonth.selector;
        spSelectors[11] = SPFacet.calculateStorageCost.selector;
        spSelectors[12] = SPFacet.isSPTokenSupported.selector;
        spSelectors[13] = SPFacet.isSPActive.selector;
        spSelectors[14] = SPFacet.getSPBasicInfo.selector;
        spSelectors[15] = SPFacet.getAndValidateSPPrice.selector;
        spSelectors[16] = SPFacet.getSPSupportedTokens.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(spFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: spSelectors
        });

        // AllocationFacet
        bytes4[] memory allocSelectors = new bytes4[](4);
        allocSelectors[0] = AllocationFacet.createAllocationRequests.selector;
        allocSelectors[1] = AllocationFacet.settleSpPayment.selector;
        allocSelectors[2] = AllocationFacet.settleSpTotalPayment.selector;
        allocSelectors[3] = AllocationFacet.handle_filecoin_method.selector;
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(allocationFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: allocSelectors
        });

        // ViewFacet
        bytes4[] memory viewSelectors = new bytes4[](9);
        viewSelectors[0] = ViewFacet.getAllSPIds.selector;
        viewSelectors[1] = ViewFacet.getAllocationIdsForClient.selector;
        viewSelectors[2] = ViewFacet.getAllocationIdsForProvider.selector;
        viewSelectors[3] = ViewFacet.allocationInfos.selector;
        viewSelectors[4] = ViewFacet.getAllocationRailInfo.selector;
        viewSelectors[5] = ViewFacet.getClaimInfo.selector;
        viewSelectors[6] = ViewFacet.getClaimInfoForClient.selector;
        viewSelectors[7] = ViewFacet.getDealId.selector;
        viewSelectors[8] = ViewFacet.getVersion.selector;
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(viewFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: viewSelectors
        });

        // ValidatorFacet
        bytes4[] memory validatorSelectors = new bytes4[](2);
        validatorSelectors[0] = ValidatorFacet.validatePayment.selector;
        validatorSelectors[1] = ValidatorFacet.railTerminated.selector;
        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: address(validatorFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: validatorSelectors
        });

        // 6. Perform diamond cut with initialization
        bytes memory initCalldata = abi.encodeWithSelector(
            InitDiamond.init.selector,
            paymentsContract,
            50, // commissionRateBps (0.5%)
            1 * 10 ** 15 // allocationLockupAmount (0.001 token)
        );

        IDiamondCut(address(diamond)).diamondCut(cuts, address(initDiamond), initCalldata);
        console.log("Diamond cut complete - all facets registered");

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("Diamond (DDOClient):", address(diamond));
    }
}
