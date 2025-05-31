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
