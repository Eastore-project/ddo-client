package types

// PieceInfo represents the PieceInfo struct from the contract
type PieceInfo struct {
    PieceCid         []byte `json:"pieceCid"`
    Size             uint64 `json:"size"`
    Provider         uint64 `json:"provider"`
    TermMin          int64  `json:"termMin"`
    TermMax          int64  `json:"termMax"`
    ExpirationOffset int64  `json:"expirationOffset"`
    DownloadURL      string `json:"downloadURL"`
}

// AllocationRequest represents the AllocationRequest struct from the contract
type AllocationRequest struct {
    Provider   uint64
    Data       []byte
    Size       uint64
    TermMin    int64
    TermMax    int64
    Expiration int64
}

// Claim represents the Claim struct from VerifRegTypes.sol
type Claim struct {
    Provider  uint64 `json:"provider"`  // FilActorId
    Client    uint64 `json:"client"`    // FilActorId
    Data      []byte `json:"data"`      // bytes
    Size      uint64 `json:"size"`      // uint64
    TermMin   int64  `json:"termMin"`   // ChainEpoch
    TermMax   int64  `json:"termMax"`   // ChainEpoch
    TermStart int64  `json:"termStart"` // ChainEpoch
    Sector    uint64 `json:"sector"`    // FilActorId
}
