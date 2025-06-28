package ddo

// DDOClient ABI - manually defined
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
            "stateMutability": "view"
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
            "stateMutability": "view"
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
            "stateMutability": "view"
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
            "stateMutability": "view"
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
            "stateMutability": "view"
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
            "name": "allocationIdToProvider",
            "inputs": [
                {
                    "name": "",
                    "type": "uint64",
                    "internalType": "uint64"
                }
            ],
            "outputs": [
                {
                    "name": "",
                    "type": "uint64",
                    "internalType": "uint64"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "allocationIdToRailId",
            "inputs": [
                {
                    "name": "",
                    "type": "uint64",
                    "internalType": "uint64"
                }
            ],
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
            "name": "allocationIdsByClient",
            "inputs": [
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
            "outputs": [
                {
                    "name": "",
                    "type": "uint64",
                    "internalType": "uint64"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "allocationIdsByProvider",
            "inputs": [
                {
                    "name": "",
                    "type": "uint64",
                    "internalType": "uint64"
                },
                {
                    "name": "",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [
                {
                    "name": "",
                    "type": "uint64",
                    "internalType": "uint64"
                }
            ],
            "stateMutability": "view"
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
                    "internalType": "struct DDOTypes.PieceInfo[]",
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
                    "name": "allocationIds",
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
                    "name": "allocationIds",
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
                    "internalType": "struct IPayments.RailView",
                    "components": [
                        {
                            "name": "token",
                            "type": "address",
                            "internalType": "address"
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
                    "internalType": "struct DDOSp.TokenConfig[]",
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
            "name": "owner",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
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
                    "internalType": "contract IPayments"
                }
            ],
            "stateMutability": "view"
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
                    "internalType": "struct DDOSp.TokenConfig[]",
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
            "name": "renounceOwnership",
            "inputs": [],
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
            "name": "settleSpFirstPayment",
            "inputs": [
                {
                    "name": "allocationId",
                    "type": "uint64",
                    "internalType": "uint64"
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
                    "name": "totalPaymentFee",
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
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "spConfigs",
            "inputs": [
                {
                    "name": "",
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
            "name": "transferOwnership",
            "inputs": [
                {
                    "name": "newOwner",
                    "type": "address",
                    "internalType": "address"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
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
                    "name": "railId",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "proposedAmount",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "fromEpoch",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "toEpoch",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "rate",
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
            "name": "OwnershipTransferred",
            "inputs": [
                {
                    "name": "previousOwner",
                    "type": "address",
                    "indexed": true,
                    "internalType": "address"
                },
                {
                    "name": "newOwner",
                    "type": "address",
                    "indexed": true,
                    "internalType": "address"
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
            "name": "AllocationCountMismatch",
            "inputs": []
        },
        {
            "type": "error",
            "name": "AllocationNotFound",
            "inputs": []
        },
        {
            "type": "error",
            "name": "CommissionRateExceedsMaximum",
            "inputs": []
        },
        {
            "type": "error",
            "name": "CurrentBlockBeforeTermStart",
            "inputs": []
        },
        {
            "type": "error",
            "name": "DataCapTransferError",
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
            "name": "FailToCallActor",
            "inputs": []
        },
        {
            "type": "error",
            "name": "FailedToGetClaimInfo",
            "inputs": []
        },
        {
            "type": "error",
            "name": "GetClaimsFailed",
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
            "name": "InvalidAllocationRequest",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidClaimExtensionRequest",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidClaimIdForClient",
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
            "name": "InvalidOperatorData",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidPaymentsContract",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidPieceSize",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidProvider",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidProviderId",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidResponseLength",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidSPConfig",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidTermStart",
            "inputs": []
        },
        {
            "type": "error",
            "name": "NoAllocationsFoundForProvider",
            "inputs": []
        },
        {
            "type": "error",
            "name": "NoClaimsFound",
            "inputs": []
        },
        {
            "type": "error",
            "name": "NoClaimsFoundForAllocation",
            "inputs": []
        },
        {
            "type": "error",
            "name": "NoPieceInfosProvided",
            "inputs": []
        },
        {
            "type": "error",
            "name": "NoRailFoundForAllocation",
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
            "type": "error",
            "name": "OwnableInvalidOwner",
            "inputs": [
                {
                    "name": "owner",
                    "type": "address",
                    "internalType": "address"
                }
            ]
        },
        {
            "type": "error",
            "name": "OwnableUnauthorizedAccount",
            "inputs": [
                {
                    "name": "account",
                    "type": "address",
                    "internalType": "address"
                }
            ]
        },
        {
            "type": "error",
            "name": "PaymentsContractNotSet",
            "inputs": []
        },
        {
            "type": "error",
            "name": "PieceSizeOutOfRange",
            "inputs": []
        },
        {
            "type": "error",
            "name": "RailCreationFailed",
            "inputs": []
        },
        {
            "type": "error",
            "name": "ReentrancyGuardReentrantCall",
            "inputs": []
        },
        {
            "type": "error",
            "name": "SPAlreadyRegistered",
            "inputs": []
        },
        {
            "type": "error",
            "name": "SPNotActive",
            "inputs": []
        },
        {
            "type": "error",
            "name": "SPNotRegistered",
            "inputs": []
        },
        {
            "type": "error",
            "name": "TermLengthOutOfRange",
            "inputs": []
        },
        {
            "type": "error",
            "name": "TokenAlreadyExists",
            "inputs": []
        },
        {
            "type": "error",
            "name": "TokenInactive",
            "inputs": []
        },
        {
            "type": "error",
            "name": "TokenNotFound",
            "inputs": []
        },
        {
            "type": "error",
            "name": "TokenNotSupportedBySP",
            "inputs": []
        },
        {
            "type": "error",
            "name": "UnauthorizedMethod",
            "inputs": []
        }
    ]` 