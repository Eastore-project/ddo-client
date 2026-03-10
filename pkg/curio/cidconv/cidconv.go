package cidconv

import (
	commcid "github.com/filecoin-project/go-fil-commcid"
	"github.com/ipfs/go-cid"
)

// PieceCidV2FromV1 converts a piece CID v1 (baga...) to a CID v2 with embedded payload size.
func PieceCidV2FromV1(pieceCidV1 cid.Cid, payloadSize uint64) (cid.Cid, error) {
	return commcid.PieceCidV2FromV1(pieceCidV1, payloadSize)
}
