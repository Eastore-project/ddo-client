package ddo

// DDOClientABI is the merged ABI of all diamond facets (AdminFacet, SPFacet, AllocationFacet, ViewFacet, ValidatorFacet).
const DDOClientABI = `[
        {
                "type": "function",
                "name": "DATACAP_ACTOR_ETH_ADDRESS",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "stateMutability": "pure"
        },
        {
                "type": "function",
                "name": "DATACAP_RECEIVER_HOOK_METHOD_NUM",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "stateMutability": "pure"
        },
        {
                "type": "function",
                "name": "EPOCHS_PER_DAY",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "pure"
        },
        {
                "type": "function",
                "name": "EPOCHS_PER_MONTH",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "pure"
        },
        {
                "type": "function",
                "name": "MAX_COMMISSION_RATE_BPS",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "pure"
        },
        {
                "type": "function",
                "name": "SECTOR_CONTENT_CHANGED_METHOD_NUM",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "stateMutability": "pure"
        },
        {
                "type": "function",
                "name": "addSPToken",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "pricePerBytePerEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "allocationInfos",
                "inputs": [
                        {
                                "name": "allocationId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "client",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "provider",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "activated",
                                "type": "bool",
                                "internalType": "bool"
                        },
                        {
                                "name": "pieceCidHash",
                                "type": "bytes32",
                                "internalType": "bytes32"
                        },
                        {
                                "name": "paymentToken",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "pieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "railId",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "pricePerBytePerEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "sectorNumber",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "allocationLockupAmount",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "blacklistSector",
                "inputs": [
                        {
                                "name": "providerId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "sectorNumber",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "blacklisted",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "calculateStorageCost",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "pieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "termLength",
                                "type": "int64",
                                "internalType": "int64"
                        }
                ],
                "outputs": [
                        {
                                "name": "totalCost",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "commissionRateBps",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "createAllocationRequests",
                "inputs": [
                        {
                                "name": "pieceInfos",
                                "type": "tuple[]",
                                "internalType": "struct LibDDOStorage.PieceInfo[]",
                                "components": [
                                        {
                                                "name": "pieceCid",
                                                "type": "bytes",
                                                "internalType": "bytes"
                                        },
                                        {
                                                "name": "size",
                                                "type": "uint64",
                                                "internalType": "uint64"
                                        },
                                        {
                                                "name": "provider",
                                                "type": "uint64",
                                                "internalType": "uint64"
                                        },
                                        {
                                                "name": "termMin",
                                                "type": "int64",
                                                "internalType": "int64"
                                        },
                                        {
                                                "name": "termMax",
                                                "type": "int64",
                                                "internalType": "int64"
                                        },
                                        {
                                                "name": "expirationOffset",
                                                "type": "int64",
                                                "internalType": "int64"
                                        },
                                        {
                                                "name": "downloadURL",
                                                "type": "string",
                                                "internalType": "string"
                                        },
                                        {
                                                "name": "paymentTokenAddress",
                                                "type": "address",
                                                "internalType": "address"
                                        }
                                ]
                        }
                ],
                "outputs": [
                        {
                                "name": "recipientData",
                                "type": "bytes",
                                "internalType": "bytes"
                        }
                ],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "deactivateSP",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "getAllSPIds",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint64[]",
                                "internalType": "uint64[]"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getAllocationIdsForClient",
                "inputs": [
                        {
                                "name": "clientAddress",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint64[]",
                                "internalType": "uint64[]"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getAllocationIdsForProvider",
                "inputs": [
                        {
                                "name": "providerId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint64[]",
                                "internalType": "uint64[]"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getAllocationRailInfo",
                "inputs": [
                        {
                                "name": "allocationId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "railId",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "providerId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "railView",
                                "type": "tuple",
                                "internalType": "struct FilecoinPayV1.RailView",
                                "components": [
                                        {
                                                "name": "token",
                                                "type": "address",
                                                "internalType": "contract IERC20"
                                        },
                                        {
                                                "name": "from",
                                                "type": "address",
                                                "internalType": "address"
                                        },
                                        {
                                                "name": "to",
                                                "type": "address",
                                                "internalType": "address"
                                        },
                                        {
                                                "name": "operator",
                                                "type": "address",
                                                "internalType": "address"
                                        },
                                        {
                                                "name": "validator",
                                                "type": "address",
                                                "internalType": "address"
                                        },
                                        {
                                                "name": "paymentRate",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "lockupPeriod",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "lockupFixed",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "settledUpTo",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "endEpoch",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "commissionRateBps",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "serviceFeeRecipient",
                                                "type": "address",
                                                "internalType": "address"
                                        }
                                ]
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getAndValidateSPPrice",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "outputs": [
                        {
                                "name": "pricePerBytePerEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getClaimInfo",
                "inputs": [
                        {
                                "name": "providerActorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "claimId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "",
                                "type": "tuple",
                                "internalType": "struct VerifRegTypes.GetClaimsReturn",
                                "components": [
                                        {
                                                "name": "batch_info",
                                                "type": "tuple",
                                                "internalType": "struct CommonTypes.BatchReturn",
                                                "components": [
                                                        {
                                                                "name": "success_count",
                                                                "type": "uint32",
                                                                "internalType": "uint32"
                                                        },
                                                        {
                                                                "name": "fail_codes",
                                                                "type": "tuple[]",
                                                                "internalType": "struct CommonTypes.FailCode[]",
                                                                "components": [
                                                                        {
                                                                                "name": "idx",
                                                                                "type": "uint32",
                                                                                "internalType": "uint32"
                                                                        },
                                                                        {
                                                                                "name": "code",
                                                                                "type": "uint32",
                                                                                "internalType": "uint32"
                                                                        }
                                                                ]
                                                        }
                                                ]
                                        },
                                        {
                                                "name": "claims",
                                                "type": "tuple[]",
                                                "internalType": "struct VerifRegTypes.Claim[]",
                                                "components": [
                                                        {
                                                                "name": "provider",
                                                                "type": "uint64",
                                                                "internalType": "CommonTypes.FilActorId"
                                                        },
                                                        {
                                                                "name": "client",
                                                                "type": "uint64",
                                                                "internalType": "CommonTypes.FilActorId"
                                                        },
                                                        {
                                                                "name": "data",
                                                                "type": "bytes",
                                                                "internalType": "bytes"
                                                        },
                                                        {
                                                                "name": "size",
                                                                "type": "uint64",
                                                                "internalType": "uint64"
                                                        },
                                                        {
                                                                "name": "term_min",
                                                                "type": "int64",
                                                                "internalType": "CommonTypes.ChainEpoch"
                                                        },
                                                        {
                                                                "name": "term_max",
                                                                "type": "int64",
                                                                "internalType": "CommonTypes.ChainEpoch"
                                                        },
                                                        {
                                                                "name": "term_start",
                                                                "type": "int64",
                                                                "internalType": "CommonTypes.ChainEpoch"
                                                        },
                                                        {
                                                                "name": "sector",
                                                                "type": "uint64",
                                                                "internalType": "CommonTypes.FilActorId"
                                                        }
                                                ]
                                        }
                                ]
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getClaimInfoForClient",
                "inputs": [
                        {
                                "name": "clientAddress",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "claimId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "claims",
                                "type": "tuple[]",
                                "internalType": "struct VerifRegTypes.Claim[]",
                                "components": [
                                        {
                                                "name": "provider",
                                                "type": "uint64",
                                                "internalType": "CommonTypes.FilActorId"
                                        },
                                        {
                                                "name": "client",
                                                "type": "uint64",
                                                "internalType": "CommonTypes.FilActorId"
                                        },
                                        {
                                                "name": "data",
                                                "type": "bytes",
                                                "internalType": "bytes"
                                        },
                                        {
                                                "name": "size",
                                                "type": "uint64",
                                                "internalType": "uint64"
                                        },
                                        {
                                                "name": "term_min",
                                                "type": "int64",
                                                "internalType": "CommonTypes.ChainEpoch"
                                        },
                                        {
                                                "name": "term_max",
                                                "type": "int64",
                                                "internalType": "CommonTypes.ChainEpoch"
                                        },
                                        {
                                                "name": "term_start",
                                                "type": "int64",
                                                "internalType": "CommonTypes.ChainEpoch"
                                        },
                                        {
                                                "name": "sector",
                                                "type": "uint64",
                                                "internalType": "CommonTypes.FilActorId"
                                        }
                                ]
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getDealId",
                "inputs": [
                        {
                                "name": "params",
                                "type": "bytes",
                                "internalType": "bytes"
                        }
                ],
                "outputs": [
                        {
                                "name": "",
                                "type": "int64",
                                "internalType": "int64"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getVersion",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "string",
                                "internalType": "string"
                        }
                ],
                "stateMutability": "pure"
        },
        {
                "type": "function",
                "name": "getSPActivePricePerBytePerEpoch",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "outputs": [
                        {
                                "name": "pricePerBytePerEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getSPAllTokenPricesPerMonth",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "tokens",
                                "type": "address[]",
                                "internalType": "address[]"
                        },
                        {
                                "name": "pricesPerTBPerMonth",
                                "type": "uint256[]",
                                "internalType": "uint256[]"
                        },
                        {
                                "name": "activeStatus",
                                "type": "bool[]",
                                "internalType": "bool[]"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getSPBasicInfo",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "paymentAddress",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "isActive",
                                "type": "bool",
                                "internalType": "bool"
                        },
                        {
                                "name": "supportedTokenCount",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "minPieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "maxPieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getSPSupportedTokens",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "tokenConfigs",
                                "type": "tuple[]",
                                "internalType": "struct LibDDOStorage.TokenConfig[]",
                                "components": [
                                        {
                                                "name": "token",
                                                "type": "address",
                                                "internalType": "address"
                                        },
                                        {
                                                "name": "pricePerBytePerEpoch",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "isActive",
                                                "type": "bool",
                                                "internalType": "bool"
                                        }
                                ]
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getSPTokenPrice",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "outputs": [
                        {
                                "name": "price",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "isActive",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "getSPTokenPricePerTBPerMonth",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "outputs": [
                        {
                                "name": "pricePerTBPerMonth",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "isActive",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "handle_filecoin_method",
                "inputs": [
                        {
                                "name": "method",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "_codec",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "params",
                                "type": "bytes",
                                "internalType": "bytes"
                        }
                ],
                "outputs": [
                        {
                                "name": "",
                                "type": "uint32",
                                "internalType": "uint32"
                        },
                        {
                                "name": "",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "",
                                "type": "bytes",
                                "internalType": "bytes"
                        }
                ],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "isSPActive",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "isSPTokenSupported",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "outputs": [
                        {
                                "name": "",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "paymentsContract",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "address",
                                "internalType": "contract FilecoinPayV1"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "railTerminated",
                "inputs": [
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "registerSP",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "paymentAddress",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "minPieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "maxPieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "minTermLength",
                                "type": "int64",
                                "internalType": "int64"
                        },
                        {
                                "name": "maxTermLength",
                                "type": "int64",
                                "internalType": "int64"
                        },
                        {
                                "name": "tokenConfigs",
                                "type": "tuple[]",
                                "internalType": "struct LibDDOStorage.TokenConfig[]",
                                "components": [
                                        {
                                                "name": "token",
                                                "type": "address",
                                                "internalType": "address"
                                        },
                                        {
                                                "name": "pricePerBytePerEpoch",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "isActive",
                                                "type": "bool",
                                                "internalType": "bool"
                                        }
                                ]
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "removeSPToken",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "setAllocationLockupAmount",
                "inputs": [
                        {
                                "name": "_amount",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "setCommissionRate",
                "inputs": [
                        {
                                "name": "_commissionRateBps",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "setPaymentsContract",
                "inputs": [
                        {
                                "name": "_paymentsContract",
                                "type": "address",
                                "internalType": "address"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "settleSpPayment",
                "inputs": [
                        {
                                "name": "allocationId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "untilEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "outputs": [
                        {
                                "name": "totalSettledAmount",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "totalNetPayeeAmount",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "totalNetworkFee",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "totalOperatorCommission",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "finalSettledEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "note",
                                "type": "string",
                                "internalType": "string"
                        }
                ],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "settleSpTotalPayment",
                "inputs": [
                        {
                                "name": "providerId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "untilEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "startIndex",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "batchSize",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "outputs": [
                        {
                                "name": "settledCount",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "spConfigs",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "paymentAddress",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "minPieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "maxPieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "minTermLength",
                                "type": "int64",
                                "internalType": "int64"
                        },
                        {
                                "name": "maxTermLength",
                                "type": "int64",
                                "internalType": "int64"
                        },
                        {
                                "name": "isActive",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "updateSPConfig",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "paymentAddress",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "minPieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "maxPieceSize",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "minTermLength",
                                "type": "int64",
                                "internalType": "int64"
                        },
                        {
                                "name": "maxTermLength",
                                "type": "int64",
                                "internalType": "int64"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "updateSPToken",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "internalType": "address"
                        },
                        {
                                "name": "pricePerBytePerEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "isActive",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "validatePayment",
                "inputs": [
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "proposedAmount",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "toEpoch",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ],
                "outputs": [
                        {
                                "name": "result",
                                "type": "tuple",
                                "internalType": "struct IValidator.ValidationResult",
                                "components": [
                                        {
                                                "name": "modifiedAmount",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "settleUpto",
                                                "type": "uint256",
                                                "internalType": "uint256"
                                        },
                                        {
                                                "name": "note",
                                                "type": "string",
                                                "internalType": "string"
                                        }
                                ]
                        }
                ],
                "stateMutability": "pure"
        },
        {
                "type": "event",
                "name": "AllocationActivated",
                "inputs": [
                        {
                                "name": "allocationId",
                                "type": "uint64",
                                "indexed": true,
                                "internalType": "uint64"
                        },
                        {
                                "name": "provider",
                                "type": "uint64",
                                "indexed": true,
                                "internalType": "uint64"
                        },
                        {
                                "name": "sector",
                                "type": "uint64",
                                "indexed": false,
                                "internalType": "uint64"
                        },
                        {
                                "name": "railId",
                                "type": "uint256",
                                "indexed": false,
                                "internalType": "uint256"
                        },
                        {
                                "name": "paymentRate",
                                "type": "uint256",
                                "indexed": false,
                                "internalType": "uint256"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "event",
                "name": "AllocationCreated",
                "inputs": [
                        {
                                "name": "client",
                                "type": "address",
                                "indexed": true,
                                "internalType": "address"
                        },
                        {
                                "name": "allocationId",
                                "type": "uint64",
                                "indexed": true,
                                "internalType": "uint64"
                        },
                        {
                                "name": "provider",
                                "type": "uint64",
                                "indexed": true,
                                "internalType": "uint64"
                        },
                        {
                                "name": "data",
                                "type": "bytes",
                                "indexed": false,
                                "internalType": "bytes"
                        },
                        {
                                "name": "size",
                                "type": "uint64",
                                "indexed": false,
                                "internalType": "uint64"
                        },
                        {
                                "name": "termMin",
                                "type": "int64",
                                "indexed": false,
                                "internalType": "int64"
                        },
                        {
                                "name": "termMax",
                                "type": "int64",
                                "indexed": false,
                                "internalType": "int64"
                        },
                        {
                                "name": "expiration",
                                "type": "int64",
                                "indexed": false,
                                "internalType": "int64"
                        },
                        {
                                "name": "downloadURL",
                                "type": "string",
                                "indexed": false,
                                "internalType": "string"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "event",
                "name": "DataCapTransferSuccess",
                "inputs": [
                        {
                                "name": "totalDataCap",
                                "type": "uint256",
                                "indexed": false,
                                "internalType": "uint256"
                        },
                        {
                                "name": "recipientData",
                                "type": "bytes",
                                "indexed": false,
                                "internalType": "bytes"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "event",
                "name": "RailCreated",
                "inputs": [
                        {
                                "name": "client",
                                "type": "address",
                                "indexed": true,
                                "internalType": "address"
                        },
                        {
                                "name": "storageProvider",
                                "type": "address",
                                "indexed": true,
                                "internalType": "address"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "indexed": true,
                                "internalType": "address"
                        },
                        {
                                "name": "railId",
                                "type": "uint256",
                                "indexed": false,
                                "internalType": "uint256"
                        },
                        {
                                "name": "providerId",
                                "type": "uint64",
                                "indexed": false,
                                "internalType": "uint64"
                        },
                        {
                                "name": "allocationId",
                                "type": "uint64",
                                "indexed": false,
                                "internalType": "uint64"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "event",
                "name": "ReceivedDataCap",
                "inputs": [
                        {
                                "name": "message",
                                "type": "string",
                                "indexed": false,
                                "internalType": "string"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "event",
                "name": "SPConfigUpdated",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "indexed": true,
                                "internalType": "uint64"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "event",
                "name": "SPDeactivated",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "indexed": true,
                                "internalType": "uint64"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "event",
                "name": "SPRegistered",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "indexed": true,
                                "internalType": "uint64"
                        },
                        {
                                "name": "paymentAddress",
                                "type": "address",
                                "indexed": false,
                                "internalType": "address"
                        },
                        {
                                "name": "minPieceSize",
                                "type": "uint64",
                                "indexed": false,
                                "internalType": "uint64"
                        },
                        {
                                "name": "maxPieceSize",
                                "type": "uint64",
                                "indexed": false,
                                "internalType": "uint64"
                        },
                        {
                                "name": "minTermLength",
                                "type": "int64",
                                "indexed": false,
                                "internalType": "int64"
                        },
                        {
                                "name": "maxTermLength",
                                "type": "int64",
                                "indexed": false,
                                "internalType": "int64"
                        },
                        {
                                "name": "tokenCount",
                                "type": "uint256",
                                "indexed": false,
                                "internalType": "uint256"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "event",
                "name": "SPTokenConfigUpdated",
                "inputs": [
                        {
                                "name": "actorId",
                                "type": "uint64",
                                "indexed": true,
                                "internalType": "uint64"
                        },
                        {
                                "name": "token",
                                "type": "address",
                                "indexed": true,
                                "internalType": "address"
                        },
                        {
                                "name": "pricePerBytePerEpoch",
                                "type": "uint256",
                                "indexed": false,
                                "internalType": "uint256"
                        },
                        {
                                "name": "isActive",
                                "type": "bool",
                                "indexed": false,
                                "internalType": "bool"
                        }
                ],
                "anonymous": false
        },
        {
                "type": "error",
                "name": "ActorNotFound",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__InvalidSPConfig",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__PieceSizeOutOfRange",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__SPAlreadyRegistered",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__SPNotActive",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__SPNotRegistered",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__TermLengthOutOfRange",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__TokenAlreadyExists",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__TokenInactive",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__TokenNotFound",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOSp__TokenNotSupportedBySP",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__AllocationCountMismatch",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__AllocationNotActivated",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__CommissionRateExceedsMaximum",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__DataCapTransferError",
                "inputs": [
                        {
                                "name": "exitCode",
                                "type": "int256",
                                "internalType": "int256"
                        }
                ]
        },
        {
                "type": "error",
                "name": "DDOTypes__GetClaimsFailed",
                "inputs": [
                        {
                                "name": "exitCode",
                                "type": "int256",
                                "internalType": "int256"
                        }
                ]
        },
        {
                "type": "error",
                "name": "DDOTypes__InvalidBatchReturnFormat",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__InvalidClaimIdForClient",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__InvalidFailCodeFormat",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__InvalidPaymentsContract",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__InvalidPieceSize",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__InvalidProvider",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__InvalidProviderId",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__InvalidVerifregResponse",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__NoAllocationsFoundForProvider",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__NoClaimsFound",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__NoPieceInfosProvided",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__NoRailFoundForAllocation",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__NotMinerActor",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__PaymentsContractNotSet",
                "inputs": []
        },
        {
                "type": "error",
                "name": "DDOTypes__UnauthorizedMethod",
                "inputs": []
        },
        {
                "type": "error",
                "name": "FailToCallActor",
                "inputs": []
        },
        {
                "type": "error",
                "name": "InvalidCodec",
                "inputs": [
                        {
                                "name": "",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ]
        },
        {
                "type": "error",
                "name": "InvalidResponseLength",
                "inputs": []
        },
        {
                "type": "error",
                "name": "NotEnoughBalance",
                "inputs": [
                        {
                                "name": "balance",
                                "type": "uint256",
                                "internalType": "uint256"
                        },
                        {
                                "name": "value",
                                "type": "uint256",
                                "internalType": "uint256"
                        }
                ]
        },
        {
                "type": "function",
                "name": "isSectorBlacklisted",
                "inputs": [
                        {
                                "name": "providerId",
                                "type": "uint64",
                                "internalType": "uint64"
                        },
                        {
                                "name": "sectorNumber",
                                "type": "uint64",
                                "internalType": "uint64"
                        }
                ],
                "outputs": [
                        {
                                "name": "",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "stateMutability": "view"
        },
        {
                "type": "function",
                "name": "pause",
                "inputs": [],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "unpause",
                "inputs": [],
                "outputs": [],
                "stateMutability": "nonpayable"
        },
        {
                "type": "function",
                "name": "paused",
                "inputs": [],
                "outputs": [
                        {
                                "name": "",
                                "type": "bool",
                                "internalType": "bool"
                        }
                ],
                "stateMutability": "view"
        }
]`
