// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {DDOClientTest} from "../src/DDOClientTest.sol";
import {DDOTypes} from "../src/DDOTypes.sol";
import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";

contract DDOClientTests is Test {
    DDOClientTest public ddoClient;

    function setUp() public {
        ddoClient = new DDOClientTest();
    }

    function testCreateSingleAllocationRequestSerialization() public {
        // Dummy piece CID (32 bytes representing a piece CID)
        bytes
            memory pieceCid = hex"0181e20392202097ac67599c3bdb554a7c6e7af107d3339346dfd53ff7ff23fa4a5d0f551e592f";

        // Dummy parameters
        uint64 size = 8388608; // 1 GiB
        uint64 provider = 17840; // Miner ID
        int64 termMin = 518400; // ~180 days in epochs (assuming 30s epochs)
        int64 termMax = 5256000; // ~540 days in epochs
        int64 expirationOffset = 172800; // ~1 day offset
        string memory downloadURL = "https://example.com/download/piece1";

        console.log("=== Testing Single Allocation Request Serialization ===");
        console.log("Piece CID (hex):");
        console.logBytes(pieceCid);
        console.log("Size:", size);
        console.log("Provider:", provider);
        console.log("Term Min:", uint256(uint64(termMin)));
        console.log("Term Max:", uint256(uint64(termMax)));
        console.log("Current Block Number:", block.number);
        console.log("Expiration Offset:", uint256(uint64(expirationOffset)));
        console.log("Download URL:", downloadURL);

        // Test just the serialization without DataCap transfer
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = DDOTypes.PieceInfo({
            pieceCid: pieceCid,
            size: size,
            provider: provider,
            termMin: termMin,
            termMax: termMax,
            expirationOffset: expirationOffset,
            downloadURL: downloadURL,
            paymentTokenAddress: address(0) // Add missing field
        });

        (uint256 totalDataCap, bytes memory receiverParams) = ddoClient
            .mockCreateRawAllocationRequests(pieceInfos);

        console.log("=== RESULT ===");
        console.log("Total DataCap:", totalDataCap);
        console.log("Receiver Params (bytes):");
        console.logBytes(receiverParams);
        console.log("Receiver Params Hex:");
        console.log(_bytesToHex(receiverParams));

        // Basic assertions
        assertTrue(
            receiverParams.length > 0,
            "Receiver params should not be empty"
        );
        assertEq(totalDataCap, size, "Total datacap should match piece size");
    }

    function testCreateMultipleAllocationRequestsWithDifferentProviders()
        public
    {
        console.log(
            "=== Testing Multiple Allocation Requests with Different Providers ==="
        );

        // Create array of piece infos with DIFFERENT providers (now supported!)
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](3);

        // First piece
        pieceInfos[0] = DDOTypes.PieceInfo({
            pieceCid: hex"0181e203922020b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9",
            size: 1073741824, // 1 GiB
            provider: 12345,
            termMin: 518400,
            termMax: 1555200,
            expirationOffset: 2880,
            downloadURL: "https://provider1.example.com/piece1",
            paymentTokenAddress: address(0)
        });

        // Second piece with different provider
        pieceInfos[1] = DDOTypes.PieceInfo({
            pieceCid: hex"0181e203922020a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a",
            size: 2147483648, // 2 GiB
            provider: 67890, // Different provider - now allowed!
            termMin: 518400,
            termMax: 1555200,
            expirationOffset: 5760, // ~2 days
            downloadURL: "https://provider2.example.com/piece2",
            paymentTokenAddress: address(0)
        });

        // Third piece with yet another provider
        pieceInfos[2] = DDOTypes.PieceInfo({
            pieceCid: hex"0181e203922020fedcba9876543210fedcba9876543210fedcba9876543210fedcba98765432",
            size: 536870912, // 512 MiB
            provider: 11111, // Another different provider
            termMin: 259200, // ~90 days
            termMax: 1036800, // ~360 days
            expirationOffset: 8640, // ~3 days
            downloadURL: "https://provider3.example.com/piece3",
            paymentTokenAddress: address(0)
        });

        console.log(
            "Creating allocation requests for",
            pieceInfos.length,
            "pieces with different providers"
        );
        for (uint i = 0; i < pieceInfos.length; i++) {
            console.log("Piece", i + 1, ":");
            console.log("  Size:", pieceInfos[i].size);
            console.log("  Provider:", pieceInfos[i].provider);
            console.log("  Download URL:", pieceInfos[i].downloadURL);
            console.log("  CID (hex):");
            console.log("  ");
            console.logBytes(pieceInfos[i].pieceCid);
        }

        (uint256 totalDataCap, bytes memory receiverParams) = ddoClient
            .mockCreateRawAllocationRequests(pieceInfos);

        console.log("=== RESULT ===");
        console.log("Total DataCap:", totalDataCap);
        console.log("Receiver Params (bytes):");
        console.logBytes(receiverParams);
        console.log("Receiver Params Hex:");
        console.log(_bytesToHex(receiverParams));

        // Assertions
        uint256 expectedTotalDataCap = 1073741824 + 2147483648 + 536870912; // Sum of all sizes
        assertEq(
            totalDataCap,
            expectedTotalDataCap,
            "Total datacap should match sum of piece sizes"
        );
        assertTrue(
            receiverParams.length > 0,
            "Receiver params should not be empty"
        );
    }

    function testCalculateTotalDataCap() public view {
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](2);

        pieceInfos[0] = DDOTypes.PieceInfo({
            pieceCid: hex"0181e203922020b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9",
            size: 1000000000,
            provider: 12345,
            termMin: 518400,
            termMax: 1555200,
            expirationOffset: 2880,
            downloadURL: "https://example.com/piece1",
            paymentTokenAddress: address(0)
        });

        pieceInfos[1] = DDOTypes.PieceInfo({
            pieceCid: hex"0181e203922020a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a",
            size: 2000000000,
            provider: 67890,
            termMin: 518400,
            termMax: 1555200,
            expirationOffset: 5760,
            downloadURL: "https://example.com/piece2",
            paymentTokenAddress: address(0)
        });

        uint256 totalDataCap = ddoClient.calculateTotalDataCap(pieceInfos);

        console.log("=== Calculate Total DataCap Test ===");
        console.log("Piece 1 size:", pieceInfos[0].size);
        console.log("Piece 2 size:", pieceInfos[1].size);
        console.log("Total DataCap:", totalDataCap);

        assertEq(
            totalDataCap,
            3000000000,
            "Total should be sum of both pieces"
        );
    }

    function testSerializationRoundTrip() public {
        console.log("=== Testing Serialization Round Trip ===");

        // More realistic Filecoin parameters
        bytes
            memory pieceCid = hex"0181e203922020abcdef1234567890abcdef1234567890abcdef1234567890abcd";
        uint64 size = 34359738368; // 32 GiB (common sector size)
        uint64 provider = 1000; // Realistic miner ID
        int64 termMin = 518400; // 180 days minimum term
        int64 termMax = 3110400; // ~3 years maximum term
        int64 expirationOffset = 5760; // 2 days expiration offset
        string memory downloadURL = "https://storage.example.com/file123";

        console.log("Realistic Parameters:");
        console.log("Sector Size (32 GiB):", size);
        console.log("Miner ID:", provider);
        console.log("Term Min (180 days):", uint256(uint64(termMin)));
        console.log("Term Max (~3 years):", uint256(uint64(termMax)));
        console.log("Current Block Number:", block.number);
        console.log("Download URL:", downloadURL);

        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = DDOTypes.PieceInfo({
            pieceCid: pieceCid,
            size: size,
            provider: provider,
            termMin: termMin,
            termMax: termMax,
            expirationOffset: expirationOffset,
            downloadURL: downloadURL,
            paymentTokenAddress: address(0)
        });

        (uint256 totalDataCap, bytes memory receiverParams) = ddoClient
            .mockCreateRawAllocationRequests(pieceInfos);

        console.log("=== SERIALIZATION RESULT ===");
        console.log("Total DataCap:", totalDataCap);
        console.log("Receiver Params (bytes):");
        console.logBytes(receiverParams);
        console.log("Receiver Params Hex:");
        console.log(_bytesToHex(receiverParams));

        assertTrue(
            receiverParams.length > 0,
            "Should generate valid receiver params"
        );

        console.log("=== ROUND-TRIP SERIALIZATION TEST ===");

        console.log("Generated CBOR data length:", receiverParams.length);
        console.log("Generated CBOR data (hex):");
        console.logBytes(receiverParams);

        // Deserialize the CBOR data
        (
            DDOTypes.ProviderClaim[] memory claimExtensions,
            DDOTypes.AllocationRequest[] memory allocationRequests
        ) = ddoClient.deserializeVerifregOperatorData(receiverParams);

        console.log("=== DESERIALIZED RESULTS ===");
        console.log("Number of claim extensions:", claimExtensions.length);
        console.log(
            "Number of allocation requests:",
            allocationRequests.length
        );

        // Verify the deserialized data matches original parameters
        assertEq(claimExtensions.length, 0, "Should have 0 claim extensions");
        assertEq(
            allocationRequests.length,
            1,
            "Should have 1 allocation request"
        );

        if (allocationRequests.length > 0) {
            console.log("Verifying deserialized allocation request:");
            console.log("  Provider:", allocationRequests[0].provider);
            console.log("  Size:", allocationRequests[0].size);
            console.log(
                "  Term Min:",
                uint256(uint64(allocationRequests[0].termMin))
            );
            console.log(
                "  Term Max:",
                uint256(uint64(allocationRequests[0].termMax))
            );
            console.log(
                "  Expiration:",
                uint256(uint64(allocationRequests[0].expiration))
            );

            // Verify values match original parameters
            assertEq(
                allocationRequests[0].provider,
                provider,
                "Provider should match"
            );
            assertEq(allocationRequests[0].size, size, "Size should match");
            assertEq(
                allocationRequests[0].termMin,
                termMin,
                "Term min should match"
            );
            assertEq(
                allocationRequests[0].termMax,
                termMax,
                "Term max should match"
            );
            assertEq(
                allocationRequests[0].expiration,
                int64(int256(block.number)) + expirationOffset,
                "Expiration should match"
            );
            assertEq(
                keccak256(allocationRequests[0].data),
                keccak256(pieceCid),
                "CID data should match"
            );
        }

        console.log("=== ROUND-TRIP TEST PASSED ===");
    }

    function testDeserializeVerifregOperatorData() public view {
        console.log("=== Testing Deserialize Verifreg Operator Data ===");

        // Provided CBOR hex data
        bytes
            memory cborData = hex"8281861945b0d82a5828000181e20392202097ac67599c3bdb554a7c6e7af107d3339346dfd53ff7ff23fa4a5d0f551e592f1a008000001a0007e9001a005033401a002bd6a080";

        console.log("Input CBOR data length:", cborData.length);
        console.log("Input CBOR data (hex):");
        console.logBytes(cborData);

        // Call the deserialize function
        (
            DDOTypes.ProviderClaim[] memory claimExtensions,
            DDOTypes.AllocationRequest[] memory allocationRequests
        ) = ddoClient.deserializeVerifregOperatorData(cborData);

        console.log("=== DESERIALIZATION RESULTS ===");

        // Log claim extensions results
        console.log("Number of claim extensions:", claimExtensions.length);
        for (uint256 i = 0; i < claimExtensions.length; i++) {
            console.log("Claim Extension", i + 1, ":");
            console.log(
                "  Provider ID:",
                uint256(
                    CommonTypes.FilActorId.unwrap(claimExtensions[i].provider)
                )
            );
            console.log(
                "  Claim ID:",
                uint256(CommonTypes.FilActorId.unwrap(claimExtensions[i].claim))
            );
        }

        // Log allocation requests results
        console.log(
            "Number of allocation requests:",
            allocationRequests.length
        );
        for (uint256 i = 0; i < allocationRequests.length; i++) {
            console.log("Allocation Request", i + 1, ":");
            console.log("  Provider:", allocationRequests[i].provider);
            console.log("  Size:", allocationRequests[i].size);
            console.log(
                "  Term Min:",
                uint256(uint64(allocationRequests[i].termMin))
            );
            console.log(
                "  Term Max:",
                uint256(uint64(allocationRequests[i].termMax))
            );
            console.log(
                "  Expiration:",
                uint256(uint64(allocationRequests[i].expiration))
            );
            console.log("  Data (CID):");
            console.logBytes(allocationRequests[i].data);
        }

        // Basic assertions
        assertEq(claimExtensions.length, 0, "Should have 0 claim extensions");
        assertEq(
            allocationRequests.length,
            1,
            "Should have 1 allocation request"
        );

        console.log("=== ROUND-TRIP SERIALIZATION TEST ===");

        // Serialize the deserialized allocation requests back to CBOR
        bytes memory reserializedData = ddoClient.serializeVerifregOperatorData(
            allocationRequests
        );

        console.log("Original CBOR data length:", cborData.length);
        console.log("Re-serialized CBOR data length:", reserializedData.length);
        console.log("Original CBOR data (hex):");
        console.logBytes(cborData);
        console.log("Re-serialized CBOR data (hex):");
        console.logBytes(reserializedData);

        // Compare the original and re-serialized data
        assertEq(
            reserializedData.length,
            cborData.length,
            "Re-serialized data length should match original"
        );
        assertEq(
            keccak256(reserializedData),
            keccak256(cborData),
            "Re-serialized data should match original exactly"
        );

        // Convert to hex and compare hex strings
        string memory originalHex = _bytesToHex(cborData);
        string memory reserializedHex = _bytesToHex(reserializedData);

        console.log("Original hex:");
        console.log(originalHex);
        console.log("Re-serialized hex:");
        console.log(reserializedHex);

        assertEq(
            keccak256(bytes(originalHex)),
            keccak256(bytes(reserializedHex)),
            "Hex strings should match"
        );

        console.log("=== TEST PASSED ===");
    }

    function testDeserializeVerifregResponse() public view {
        console.log("=== Testing Deserialize Verifreg Response ===");

        // The hex data you provided: 0x838201808200808119f535
        // This CBOR decodes to: [[1, []], [0, []], [62773]]
        // Which corresponds to:
        // VerifregResponse {
        //   allocationResults: BatchReturn { success_count: 1, fail_codes: [] },
        //   extensionResults:  BatchReturn { success_count: 0, fail_codes: [] },
        //   newAllocations:    [62773]
        // }
        bytes memory cborData = hex"838201808200808119f535";

        console.log("Input CBOR data length:", cborData.length);
        console.log("Input CBOR data (hex):");
        console.logBytes(cborData);

        // Call the deserialize function
        DDOTypes.VerifregResponse memory response = ddoClient
            .deserializeVerifregResponse(cborData);

        console.log("=== DESERIALIZATION RESULTS ===");

        // Log AllocationResults
        console.log("AllocationResults:");
        console.log(
            "  Success Count:",
            response.allocationResults.success_count // Changed to success_count
        );
        console.log(
            "  Fail Codes Length:",
            response.allocationResults.fail_codes.length // Changed to fail_codes
        );
        for (
            uint256 i = 0;
            i < response.allocationResults.fail_codes.length;
            i++
        ) {
            console.log(
                "  Fail Code Index:",
                response.allocationResults.fail_codes[i].idx // Access idx
            );
            console.log(
                "  Fail Code Code:",
                response.allocationResults.fail_codes[i].code // Access code
            );
        }

        // Log ExtensionResults
        console.log("ExtensionResults:");
        console.log(
            "  Success Count:",
            response.extensionResults.success_count // Changed to success_count
        );
        console.log(
            "  Fail Codes Length:",
            response.extensionResults.fail_codes.length // Changed to fail_codes
        );
        for (
            uint256 i = 0;
            i < response.extensionResults.fail_codes.length;
            i++
        ) {
            console.log(
                "  Fail Code Index:",
                response.extensionResults.fail_codes[i].idx // Access idx
            );
            console.log(
                "  Fail Code Code:",
                response.extensionResults.fail_codes[i].code // Access code
            );
        }

        // Log NewAllocations
        console.log("NewAllocations:");
        console.log("  Length:", response.newAllocations.length);
        for (uint256 i = 0; i < response.newAllocations.length; i++) {
            console.log(
                "  New Allocation",
                i + 1,
                ":",
                response.newAllocations[i]
            );
        }

        // Verify expected values based on your JSON
        assertEq(
            response.allocationResults.success_count, // Changed to success_count
            1,
            "AllocationResults success count should be 1"
        );
        assertEq(
            response.allocationResults.fail_codes.length, // Changed to fail_codes
            0,
            "AllocationResults fail_codes length should be 0"
        );

        assertEq(
            response.extensionResults.success_count, // Changed to success_count
            0,
            "ExtensionResults success count should be 0"
        );
        assertEq(
            response.extensionResults.fail_codes.length, // Changed to fail_codes
            0,
            "ExtensionResults fail_codes length should be 0"
        );

        assertEq(
            response.newAllocations.length,
            1,
            "NewAllocations length should be 1"
        );
        if (response.newAllocations.length == 1) {
            assertEq(
                response.newAllocations[0],
                62773,
                "NewAllocation ID should be 62773"
            );
        }

        console.log("=== TEST PASSED ===");
    }

    // Helper function to convert bytes to hex string (for testing purposes only)
    function _bytesToHex(
        bytes memory data
    ) private pure returns (string memory) {
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

    // Helper function to extract substring
    function _substring(
        string memory str,
        uint startIndex,
        uint endIndex
    ) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    // Helper function to convert hex string to bytes
    function _hexStringToBytes(
        string memory s
    ) private pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0, "Hex string must have even length");
        bytes memory r = new bytes(ss.length / 2);
        for (uint i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(
                _fromHexChar(uint8(ss[2 * i])) *
                    16 +
                    _fromHexChar(uint8(ss[2 * i + 1]))
            );
        }
        return r;
    }

    // Helper function to convert hex character to uint8
    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
            return c - uint8(bytes1("0"));
        }
        if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (bytes1(c) >= bytes1("A") && bytes1(c) <= bytes1("F")) {
            return 10 + c - uint8(bytes1("A"));
        }
        revert("Invalid hex character");
    }
}
