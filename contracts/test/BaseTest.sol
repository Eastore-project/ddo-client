// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {DDOClientTest} from "../src/DDOClientTest.sol";
import {DDOTypes} from "../src/DDOTypes.sol";
import {DDOSp} from "../src/DDOSp.sol";
import {Payments} from "../src/Payments.sol";
import {IPayments} from "../src/IPayments.sol";
import {SimpleERC20} from "../src/SimpleERC20.sol";
import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title BaseTest
 * @notice Base test contract with common setup and utilities
 */
contract BaseTest is Test {
    // Core contracts
    DDOClientTest public ddoClient;
    Payments public paymentsContract;
    SimpleERC20 public testToken;

    // Test accounts
    address public owner;
    address public client1;
    address public client2;
    address public sp1PaymentAddress;
    address public sp2PaymentAddress;

    // Test constants
    uint64 public constant SP1_ACTOR_ID = 12345;
    uint64 public constant SP2_ACTOR_ID = 67890;
    uint256 public constant INITIAL_TOKEN_BALANCE = 1000000 * 10 ** 18; // 1M tokens
    uint256 public constant PIECE_SIZE = 34359738368; // 32 GiB
    uint256 public constant PRICE_PER_BYTE_PER_EPOCH = 100; // 100 wei per byte per epoch

    function setUp() public virtual {
        // Set up test accounts
        owner = address(this);
        client1 = makeAddr("client1");
        client2 = makeAddr("client2");
        sp1PaymentAddress = makeAddr("sp1Payment");
        sp2PaymentAddress = makeAddr("sp2Payment");

        // Deploy contracts
        _deployContracts();

        // Setup storage providers
        _setupStorageProviders();

        // Setup test tokens for clients
        _setupClientTokens();

        // Setup payments contract approvals
        _setupPaymentsApprovals();

        console.log("=== Base Test Setup Complete ===");
        console.log("DDOClient deployed at:", address(ddoClient));
        console.log("Payments deployed at:", address(paymentsContract));
        console.log("TestToken deployed at:", address(testToken));
        console.log("Client1:", client1);
        console.log("Client2:", client2);
        console.log("SP1 Payment Address:", sp1PaymentAddress);
        console.log("SP2 Payment Address:", sp2PaymentAddress);
    }

    function _deployContracts() internal {
        // Deploy test token
        testToken = new SimpleERC20();

        // Deploy payments contract implementation
        Payments paymentsImpl = new Payments();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            Payments.initialize.selector
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(paymentsImpl), initData);

        // Cast proxy to Payments interface
        paymentsContract = Payments(address(proxy));

        // Deploy DDO client
        ddoClient = new DDOClientTest();

        // Connect DDO client to payments contract
        ddoClient.setPaymentsContract(address(paymentsContract));

        console.log("Contracts deployed successfully");
    }

    function _setupStorageProviders() internal {
        // Prepare token configurations for SPs
        DDOSp.TokenConfig[] memory tokenConfigs = new DDOSp.TokenConfig[](1);
        tokenConfigs[0] = DDOSp.TokenConfig({
            token: address(testToken),
            pricePerBytePerEpoch: PRICE_PER_BYTE_PER_EPOCH,
            isActive: true
        });

        // Register SP1
        ddoClient.registerSP(
            SP1_ACTOR_ID,
            sp1PaymentAddress,
            1024, // minPieceSize: 1KB
            uint64(PIECE_SIZE * 2), // maxPieceSize: 64GB
            86400, // minTermLength: 30 days
            5256000, // maxTermLength: ~1820 days
            tokenConfigs
        );

        // Register SP2 with same config
        ddoClient.registerSP(
            SP2_ACTOR_ID,
            sp2PaymentAddress,
            1024, // minPieceSize: 1KB
            uint64(PIECE_SIZE * 2), // maxPieceSize: 64GB
            86400, // minTermLength: 30 days
            5256000, // maxTermLength: ~1820 days
            tokenConfigs
        );

        console.log("Storage providers registered successfully");
    }

    function _setupClientTokens() internal {
        // Mint tokens for clients
        vm.startPrank(client1);
        for (uint i = 0; i < 10; i++) {
            testToken.mint(); // 100 tokens per mint
        }
        vm.stopPrank();

        vm.startPrank(client2);
        for (uint i = 0; i < 10; i++) {
            testToken.mint(); // 100 tokens per mint
        }
        vm.stopPrank();

        console.log("Client1 token balance:", testToken.balanceOf(client1));
        console.log("Client2 token balance:", testToken.balanceOf(client2));
    }

    function _setupPaymentsApprovals() internal {
        // Client1 approvals
        vm.startPrank(client1);

        // Approve payments contract to spend tokens
        testToken.approve(address(paymentsContract), type(uint256).max);

        // Deposit tokens to payments contract
        uint256 depositAmount = 500 * 10 ** 18; // 500 tokens
        paymentsContract.deposit(address(testToken), client1, depositAmount);

        // Set operator approval for DDO client (allow it to create rails and modify them)
        paymentsContract.setOperatorApproval(
            address(testToken),
            address(ddoClient), // operator
            true, // approved
            type(uint256).max, // rateAllowance
            type(uint256).max, // lockupAllowance
            type(uint256).max // maxLockupPeriod
        );

        vm.stopPrank();

        // Client2 approvals (same setup)
        vm.startPrank(client2);

        testToken.approve(address(paymentsContract), type(uint256).max);
        paymentsContract.deposit(address(testToken), client2, depositAmount);

        paymentsContract.setOperatorApproval(
            address(testToken),
            address(ddoClient),
            true,
            type(uint256).max,
            type(uint256).max,
            type(uint256).max
        );

        vm.stopPrank();

        console.log("Payments approvals and deposits completed");
    }

    // Helper functions
    function createBasicPieceInfo(
        uint64 providerId,
        uint64 size
    ) internal view returns (DDOTypes.PieceInfo memory) {
        return
            DDOTypes.PieceInfo({
                pieceCid: hex"0181e20392202097ac67599c3bdb554a7c6e7af107d3339346dfd53ff7ff23fa4a5d0f551e592f",
                size: size,
                provider: providerId,
                termMin: 518400, // ~180 days
                termMax: 1555200, // ~540 days
                expirationOffset: 172800, // ~60 days
                downloadURL: "https://example.com/piece1",
                paymentTokenAddress: address(testToken)
            });
    }

    function createPieceInfoArray(
        uint64 providerId,
        uint64 size,
        uint256 count
    ) internal view returns (DDOTypes.PieceInfo[] memory) {
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](
            count
        );

        for (uint256 i = 0; i < count; i++) {
            pieceInfos[i] = createBasicPieceInfo(providerId, size);
            // Modify CID slightly for each piece to make them unique
            pieceInfos[i].pieceCid[pieceInfos[i].pieceCid.length - 1] = bytes1(
                uint8(i + 1)
            );
        }

        return pieceInfos;
    }

    function bytesToHex(
        bytes memory data
    ) internal pure returns (string memory) {
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

    function logPieceInfo(
        DDOTypes.PieceInfo memory piece,
        uint256 index
    ) internal view {
        console.log("Piece", index, ":");
        console.log("  CID:", bytesToHex(piece.pieceCid));
        console.log("  Size:", piece.size);
        console.log("  Provider:", piece.provider);
        console.log("  Term Min:", uint256(uint64(piece.termMin)));
        console.log("  Term Max:", uint256(uint64(piece.termMax)));
        console.log("  Token:", piece.paymentTokenAddress);
        console.log("  Download URL:", piece.downloadURL);
    }
}
