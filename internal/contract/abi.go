package contract

// DDOClient ABI - manually defined
const DDOClientABI = `[
    {
        "type": "function",
        "name": "createAllocationRequests",
        "inputs": [
            {
                "name": "pieceInfos",
                "type": "tuple[]",
                "components": [
                    {"name": "pieceCid", "type": "bytes"},
                    {"name": "size", "type": "uint64"},
                    {"name": "provider", "type": "uint64"},
                    {"name": "termMin", "type": "int64"},
                    {"name": "termMax", "type": "int64"},
                    {"name": "expirationOffset", "type": "int64"},
                    {"name": "downloadURL", "type": "string"}
                ]
            }
        ],
        "outputs": [
            {"name": "recipientData", "type": "bytes"}
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "createSingleAllocationRequest",
        "inputs": [
            {"name": "pieceCid", "type": "bytes"},
            {"name": "size", "type": "uint64"},
            {"name": "provider", "type": "uint64"},
            {"name": "termMin", "type": "int64"},
            {"name": "termMax", "type": "int64"},
            {"name": "expirationOffset", "type": "int64"},
            {"name": "downloadURL", "type": "string"}
        ],
        "outputs": [
            {"name": "recipientData", "type": "bytes"}
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "calculateTotalDataCap",
        "inputs": [
            {
                "name": "pieceInfos",
                "type": "tuple[]",
                "components": [
                    {"name": "pieceCid", "type": "bytes"},
                    {"name": "size", "type": "uint64"},
                    {"name": "provider", "type": "uint64"},
                    {"name": "termMin", "type": "int64"},
                    {"name": "termMax", "type": "int64"},
                    {"name": "expirationOffset", "type": "int64"},
                    {"name": "downloadURL", "type": "string"}
                ]
            }
        ],
        "outputs": [
            {"name": "totalDataCap", "type": "uint256"}
        ],
        "stateMutability": "pure"
    },
    {
        "type": "function",
        "name": "getAllocationIdsForClient",
        "inputs": [
            {"name": "clientAddress", "type": "address"}
        ],
        "outputs": [
            {"name": "allocationIds", "type": "uint64[]"}
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getAllocationCountForClient",
        "inputs": [
            {"name": "clientAddress", "type": "address"}
        ],
        "outputs": [
            {"name": "count", "type": "uint256"}
        ],
        "stateMutability": "view"
    },
    {
        "type": "event",
        "name": "AllocationRequestCreated",
        "inputs": [
            {"name": "provider", "type": "uint64", "indexed": true},
            {"name": "pieceCid", "type": "bytes", "indexed": false},
            {"name": "size", "type": "uint64", "indexed": false},
            {"name": "termMin", "type": "int64", "indexed": false},
            {"name": "termMax", "type": "int64", "indexed": false},
            {"name": "expiration", "type": "int64", "indexed": false},
            {"name": "downloadURL", "type": "string", "indexed": false}
        ]
    },
    {
        "type": "event",
        "name": "DataCapTransferSuccess",
        "inputs": [
            {"name": "amount", "type": "uint256", "indexed": false},
            {"name": "recipientData", "type": "bytes", "indexed": false}
        ]
    }
]` 