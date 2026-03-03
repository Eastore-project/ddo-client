// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";

// Diamond infrastructure
import {Diamond} from "src/diamond/Diamond.sol";
import {DiamondCutFacet} from "src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/diamond/facets/OwnershipFacet.sol";
import {IDiamondCut} from "src/diamond/interfaces/IDiamondCut.sol";
import {InitDiamond} from "src/diamond/InitDiamond.sol";

// DDO facets
import {AdminFacet} from "src/diamond/facets/AdminFacet.sol";
import {SPFacet} from "src/diamond/facets/SPFacet.sol";
import {MockAllocationFacet} from "src/diamond/facets/mock/MockAllocationFacet.sol";
import {ViewFacet} from "src/diamond/facets/ViewFacet.sol";
import {ValidatorFacet} from "src/diamond/facets/ValidatorFacet.sol";

// External dependencies
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SimpleERC20} from "src/SimpleERC20.sol";
import {LibDDOStorage} from "src/diamond/libraries/LibDDOStorage.sol";

contract DiamondBaseTest is Test {
    // Diamond and facet instances
    Diamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    AdminFacet public adminFacet;
    SPFacet public spFacet;
    MockAllocationFacet public mockAllocationFacet;
    ViewFacet public viewFacet;
    ValidatorFacet public validatorFacet;
    InitDiamond public initDiamond;

    // Typed interfaces pointing at diamond address
    AdminFacet public adminDiamond;
    SPFacet public spDiamond;
    MockAllocationFacet public ddoClient; // Main test interface (replaces DDOClientTest)
    ViewFacet public viewDiamond;

    // External contracts
    FilecoinPayV1 public paymentsContract;
    SimpleERC20 public testToken;

    // Test accounts
    address public owner;
    address public client1;
    address public client2;
    address public sp1PaymentAddress;
    address public sp2PaymentAddress;
    address public sp1MinerAddress;
    address public sp2MinerAddress;

    // Test constants
    uint64 public constant SP1_ACTOR_ID = 12345;
    uint64 public constant SP2_ACTOR_ID = 67890;
    uint256 public constant INITIAL_TOKEN_BALANCE = 1000000 * 10 ** 18;
    uint256 public constant PIECE_SIZE = 34359738368; // 32 GiB
    uint256 public constant PRICE_PER_BYTE_PER_EPOCH = 100;

    function setUp() public virtual {
        owner = address(this);
        client1 = makeAddr("client1");
        client2 = makeAddr("client2");
        sp1PaymentAddress = makeAddr("sp1Payment");
        sp2PaymentAddress = makeAddr("sp2Payment");

        // Compute ID addresses for miner actors
        sp1MinerAddress = address(uint160(uint256(0xff) << 152 | uint256(SP1_ACTOR_ID)));
        sp2MinerAddress = address(uint160(uint256(0xff) << 152 | uint256(SP2_ACTOR_ID)));

        _deployContracts();
        _setupStorageProviders();
        _setupClientTokens();
        _setupPaymentsApprovals();

        console.log("=== Diamond Base Test Setup Complete ===");
        console.log("Diamond deployed at:", address(diamond));
        console.log("Payments deployed at:", address(paymentsContract));
        console.log("TestToken deployed at:", address(testToken));
    }

    function _deployContracts() internal {
        // Deploy external contracts
        testToken = new SimpleERC20();
        paymentsContract = new FilecoinPayV1();

        // Deploy diamond infrastructure
        diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(diamondCutFacet));

        // Deploy facets
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        adminFacet = new AdminFacet();
        spFacet = new SPFacet();
        mockAllocationFacet = new MockAllocationFacet();
        viewFacet = new ViewFacet();
        validatorFacet = new ValidatorFacet();
        initDiamond = new InitDiamond();

        // Build FacetCut array
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

        // MockAllocationFacet (includes mock + real settlement + handle_filecoin_method)
        bytes4[] memory mockAllocSelectors = new bytes4[](15);
        mockAllocSelectors[0] = MockAllocationFacet.setMockMiner.selector;
        mockAllocSelectors[1] = MockAllocationFacet.mockMinerActorIds.selector;
        mockAllocSelectors[2] = MockAllocationFacet.mockCreateAllocationRequests.selector;
        mockAllocSelectors[3] = MockAllocationFacet.mockCreateRawAllocationRequests.selector;
        mockAllocSelectors[4] = MockAllocationFacet.mockActivateAllocation.selector;
        mockAllocSelectors[5] = MockAllocationFacet.mockSettleSpPayment.selector;
        mockAllocSelectors[6] = MockAllocationFacet.handle_filecoin_method.selector;
        mockAllocSelectors[7] = MockAllocationFacet.settleSpPayment.selector;
        mockAllocSelectors[8] = MockAllocationFacet.settleSpTotalPayment.selector;
        mockAllocSelectors[9] = MockAllocationFacet.deserializeVerifregOperatorData.selector;
        mockAllocSelectors[10] = MockAllocationFacet.serializeVerifregOperatorData.selector;
        mockAllocSelectors[11] = MockAllocationFacet.deserializeVerifregResponse.selector;
        mockAllocSelectors[12] = MockAllocationFacet.calculateTotalDataCap.selector;
        mockAllocSelectors[13] = MockAllocationFacet.mockAuthenticateCurioProposal.selector;
        mockAllocSelectors[14] = MockAllocationFacet.mockActivateAllocationWithSector.selector;
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(mockAllocationFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: mockAllocSelectors
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

        // Perform diamond cut with initialization
        bytes memory initCalldata = abi.encodeWithSelector(
            InitDiamond.init.selector,
            address(paymentsContract),
            50, // commissionRateBps (0.5%)
            1 * 10 ** 15 // allocationLockupAmount (0.001 token)
        );

        IDiamondCut(address(diamond)).diamondCut(cuts, address(initDiamond), initCalldata);

        // Create typed interfaces pointing at diamond
        adminDiamond = AdminFacet(address(diamond));
        spDiamond = SPFacet(address(diamond));
        ddoClient = MockAllocationFacet(address(diamond));
        viewDiamond = ViewFacet(address(diamond));

        // Register mock miners
        ddoClient.setMockMiner(sp1MinerAddress, SP1_ACTOR_ID);
        ddoClient.setMockMiner(sp2MinerAddress, SP2_ACTOR_ID);
    }

    function _setupStorageProviders() internal {
        LibDDOStorage.TokenConfig[] memory tokenConfigs = new LibDDOStorage.TokenConfig[](1);
        tokenConfigs[0] = LibDDOStorage.TokenConfig({
            token: address(testToken),
            pricePerBytePerEpoch: PRICE_PER_BYTE_PER_EPOCH,
            isActive: true
        });

        spDiamond.registerSP(
            SP1_ACTOR_ID,
            sp1PaymentAddress,
            1024,
            uint64(PIECE_SIZE * 2),
            86400,
            5256000,
            tokenConfigs
        );

        spDiamond.registerSP(
            SP2_ACTOR_ID,
            sp2PaymentAddress,
            1024,
            uint64(PIECE_SIZE * 2),
            86400,
            5256000,
            tokenConfigs
        );
    }

    function _setupClientTokens() internal {
        vm.startPrank(client1);
        for (uint i = 0; i < 10; i++) {
            testToken.mint();
        }
        vm.stopPrank();

        vm.startPrank(client2);
        for (uint i = 0; i < 10; i++) {
            testToken.mint();
        }
        vm.stopPrank();
    }

    function _setupPaymentsApprovals() internal {
        uint256 depositAmount = 500 * 10 ** 18;

        vm.startPrank(client1);
        testToken.approve(address(paymentsContract), type(uint256).max);
        paymentsContract.deposit(IERC20(address(testToken)), client1, depositAmount);
        paymentsContract.setOperatorApproval(
            IERC20(address(testToken)),
            address(diamond),
            true,
            type(uint256).max,
            type(uint256).max,
            type(uint256).max
        );
        vm.stopPrank();

        vm.startPrank(client2);
        testToken.approve(address(paymentsContract), type(uint256).max);
        paymentsContract.deposit(IERC20(address(testToken)), client2, depositAmount);
        paymentsContract.setOperatorApproval(
            IERC20(address(testToken)),
            address(diamond),
            true,
            type(uint256).max,
            type(uint256).max,
            type(uint256).max
        );
        vm.stopPrank();
    }

    // Helper functions
    function createBasicPieceInfo(uint64 providerId, uint64 size)
        internal
        view
        returns (LibDDOStorage.PieceInfo memory)
    {
        return LibDDOStorage.PieceInfo({
            pieceCid: hex"0181e20392202097ac67599c3bdb554a7c6e7af107d3339346dfd53ff7ff23fa4a5d0f551e592f",
            size: size,
            provider: providerId,
            termMin: 518400,
            termMax: 1555200,
            expirationOffset: 172800,
            downloadURL: "https://example.com/piece1",
            paymentTokenAddress: address(testToken)
        });
    }

    function createPieceInfoArray(uint64 providerId, uint64 size, uint256 count)
        internal
        view
        returns (LibDDOStorage.PieceInfo[] memory)
    {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](count);

        for (uint256 i = 0; i < count; i++) {
            pieceInfos[i] = createBasicPieceInfo(providerId, size);
            pieceInfos[i].pieceCid[pieceInfos[i].pieceCid.length - 1] = bytes1(uint8(i + 1));
        }

        return pieceInfos;
    }

    function bytesToHex(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";

        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
        }

        return string(str);
    }

    function logPieceInfo(LibDDOStorage.PieceInfo memory piece, uint256 index) internal view {
        console.log("Piece", index, ":");
        console.log("  CID:", bytesToHex(piece.pieceCid));
        console.log("  Size:", piece.size);
        console.log("  Provider:", piece.provider);
        console.log("  Token:", piece.paymentTokenAddress);
    }
}
