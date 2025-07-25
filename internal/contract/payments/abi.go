package payments

// Payments contract ABI - manually defined based on IPayments interface and contract implementation
const PaymentsABI = `[
        {
            "type": "constructor",
            "inputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "COMMISSION_MAX_BPS",
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
            "name": "PAYMENT_FEE_BPS",
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
            "name": "UPGRADE_INTERFACE_VERSION",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "string",
                    "internalType": "string"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "accounts",
            "inputs": [
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
                }
            ],
            "outputs": [
                {
                    "name": "funds",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "lockupCurrent",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "lockupRate",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "lockupLastSettledAt",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "accumulatedFees",
            "inputs": [
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
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
            "name": "createRail",
            "inputs": [
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
                    "name": "validator",
                    "type": "address",
                    "internalType": "address"
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
            ],
            "outputs": [
                {
                    "name": "",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "deposit",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "to",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "payable"
        },
        {
            "type": "function",
            "name": "depositWithPermit",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "to",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "deadline",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "v",
                    "type": "uint8",
                    "internalType": "uint8"
                },
                {
                    "name": "r",
                    "type": "bytes32",
                    "internalType": "bytes32"
                },
                {
                    "name": "s",
                    "type": "bytes32",
                    "internalType": "bytes32"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "depositWithPermitAndApproveOperator",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "to",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "deadline",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "v",
                    "type": "uint8",
                    "internalType": "uint8"
                },
                {
                    "name": "r",
                    "type": "bytes32",
                    "internalType": "bytes32"
                },
                {
                    "name": "s",
                    "type": "bytes32",
                    "internalType": "bytes32"
                },
                {
                    "name": "operator",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "rateAllowance",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "lockupAllowance",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "maxLockupPeriod",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "getAccountInfoIfSettled",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "owner",
                    "type": "address",
                    "internalType": "address"
                }
            ],
            "outputs": [
                {
                    "name": "fundedUntilEpoch",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "currentFunds",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "availableFunds",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "currentLockupRate",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "getAllAccumulatedFees",
            "inputs": [],
            "outputs": [
                {
                    "name": "tokens",
                    "type": "address[]",
                    "internalType": "address[]"
                },
                {
                    "name": "amounts",
                    "type": "uint256[]",
                    "internalType": "uint256[]"
                },
                {
                    "name": "count",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "getRail",
            "inputs": [
                {
                    "name": "railId",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [
                {
                    "name": "",
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
            "name": "getRailsForPayeeAndToken",
            "inputs": [
                {
                    "name": "payee",
                    "type": "address",
                    "internalType": "address"
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
                    "type": "tuple[]",
                    "internalType": "struct IPayments.RailInfo[]",
                    "components": [
                        {
                            "name": "railId",
                            "type": "uint256",
                            "internalType": "uint256"
                        },
                        {
                            "name": "isTerminated",
                            "type": "bool",
                            "internalType": "bool"
                        },
                        {
                            "name": "endEpoch",
                            "type": "uint256",
                            "internalType": "uint256"
                        }
                    ]
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "getRailsForPayerAndToken",
            "inputs": [
                {
                    "name": "payer",
                    "type": "address",
                    "internalType": "address"
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
                    "type": "tuple[]",
                    "internalType": "struct IPayments.RailInfo[]",
                    "components": [
                        {
                            "name": "railId",
                            "type": "uint256",
                            "internalType": "uint256"
                        },
                        {
                            "name": "isTerminated",
                            "type": "bool",
                            "internalType": "bool"
                        },
                        {
                            "name": "endEpoch",
                            "type": "uint256",
                            "internalType": "uint256"
                        }
                    ]
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "getRateChangeQueueSize",
            "inputs": [
                {
                    "name": "railId",
                    "type": "uint256",
                    "internalType": "uint256"
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
            "name": "hasCollectedFees",
            "inputs": [
                {
                    "name": "",
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
            "name": "initialize",
            "inputs": [],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "modifyRailLockup",
            "inputs": [
                {
                    "name": "railId",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "period",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "lockupFixed",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "modifyRailPayment",
            "inputs": [
                {
                    "name": "railId",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "newRate",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "oneTimePayment",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "operatorApprovals",
            "inputs": [
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
                }
            ],
            "outputs": [
                {
                    "name": "isApproved",
                    "type": "bool",
                    "internalType": "bool"
                },
                {
                    "name": "rateAllowance",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "lockupAllowance",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "rateUsage",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "lockupUsage",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "maxLockupPeriod",
                    "type": "uint256",
                    "internalType": "uint256"
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
            "name": "proxiableUUID",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "bytes32",
                    "internalType": "bytes32"
                }
            ],
            "stateMutability": "view"
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
            "name": "setOperatorApproval",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "operator",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "approved",
                    "type": "bool",
                    "internalType": "bool"
                },
                {
                    "name": "rateAllowance",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "lockupAllowance",
                    "type": "uint256",
                    "internalType": "uint256"
                },
                {
                    "name": "maxLockupPeriod",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "settleRail",
            "inputs": [
                {
                    "name": "railId",
                    "type": "uint256",
                    "internalType": "uint256"
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
            "name": "settleTerminatedRailWithoutValidation",
            "inputs": [
                {
                    "name": "railId",
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
            "name": "terminateRail",
            "inputs": [
                {
                    "name": "railId",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
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
            "name": "upgradeToAndCall",
            "inputs": [
                {
                    "name": "newImplementation",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "data",
                    "type": "bytes",
                    "internalType": "bytes"
                }
            ],
            "outputs": [],
            "stateMutability": "payable"
        },
        {
            "type": "function",
            "name": "withdraw",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "withdrawFees",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "to",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "withdrawTo",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "to",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "event",
            "name": "DepositWithPermit",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "indexed": true,
                    "internalType": "address"
                },
                {
                    "name": "account",
                    "type": "address",
                    "indexed": true,
                    "internalType": "address"
                },
                {
                    "name": "amount",
                    "type": "uint256",
                    "indexed": false,
                    "internalType": "uint256"
                }
            ],
            "anonymous": false
        },
        {
            "type": "event",
            "name": "Initialized",
            "inputs": [
                {
                    "name": "version",
                    "type": "uint64",
                    "indexed": false,
                    "internalType": "uint64"
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
            "name": "Upgraded",
            "inputs": [
                {
                    "name": "implementation",
                    "type": "address",
                    "indexed": true,
                    "internalType": "address"
                }
            ],
            "anonymous": false
        },
        {
            "type": "error",
            "name": "AddressEmptyCode",
            "inputs": [
                {
                    "name": "target",
                    "type": "address",
                    "internalType": "address"
                }
            ]
        },
        {
            "type": "error",
            "name": "ERC1967InvalidImplementation",
            "inputs": [
                {
                    "name": "implementation",
                    "type": "address",
                    "internalType": "address"
                }
            ]
        },
        {
            "type": "error",
            "name": "ERC1967NonPayable",
            "inputs": []
        },
        {
            "type": "error",
            "name": "FailedCall",
            "inputs": []
        },
        {
            "type": "error",
            "name": "InvalidInitialization",
            "inputs": []
        },
        {
            "type": "error",
            "name": "NotInitializing",
            "inputs": []
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
            "name": "ReentrancyGuardReentrantCall",
            "inputs": []
        },
        {
            "type": "error",
            "name": "SafeERC20FailedOperation",
            "inputs": [
                {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                }
            ]
        },
        {
            "type": "error",
            "name": "UUPSUnauthorizedCallContext",
            "inputs": []
        },
        {
            "type": "error",
            "name": "UUPSUnsupportedProxiableUUID",
            "inputs": [
                {
                    "name": "slot",
                    "type": "bytes32",
                    "internalType": "bytes32"
                }
            ]
        }
    ]` 