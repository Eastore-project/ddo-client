package curio

import (
	"encoding/binary"

	"github.com/ipfs/go-cid"
	"github.com/oklog/ulid/v2"
)

// Deal represents an MK20 deal submission.
type Deal struct {
	Identifier ulid.ULID   `json:"identifier"`
	Client     string      `json:"client"`
	Data       *DataSource `json:"data,omitempty"`
	Products   Products    `json:"products"`
}

// Products contains the product configurations for a deal.
type Products struct {
	DDOV1       *DDOV1       `json:"ddo_v1,omitempty"`
	RetrievalV1 *RetrievalV1 `json:"retrieval_v1,omitempty"`
}

// DDOV1 represents the DDO v1 product parameters.
type DDOV1 struct {
	Provider                   string  `json:"provider"`
	PieceManager               string  `json:"piece_manager"`
	Duration                   int64   `json:"duration"`
	AllocationId               *uint64 `json:"allocation_id,omitempty"`
	ContractAddress            string  `json:"contract_address"`
	ContractVerifyMethod       string  `json:"contract_verify_method"`
	ContractVerifyMethodParams []byte  `json:"contract_verify_method_Params,omitempty"`
	NotificationAddress        string  `json:"notification_address"`
	NotificationPayload        []byte  `json:"notification_payload,omitempty"`
}

// RetrievalV1 represents the retrieval v1 product parameters.
type RetrievalV1 struct {
	Indexing bool `json:"indexing"`
}

// DataSource describes the data being submitted.
type DataSource struct {
	PieceCID      cid.Cid          `json:"piece_cid"`
	Format        PieceDataFormat  `json:"format"`
	SourceHttpPut *DataSourcePut   `json:"source_http_put,omitempty"`
	SourceHTTP    *DataSourceHTTP  `json:"source_http,omitempty"`
}

// PieceDataFormat specifies the format of the piece data.
type PieceDataFormat struct {
	Car *FormatCar `json:"car,omitempty"`
}

// FormatCar indicates CAR format.
type FormatCar struct{}

// DataSourcePut indicates the client will push data via HTTP PUT.
type DataSourcePut struct{}

// DataSourceHTTP provides HTTP URLs for fetching data.
type DataSourceHTTP struct {
	URLs []HttpUrl `json:"urls"`
}

// HttpUrl represents a single HTTP URL for data fetching.
type HttpUrl struct {
	URL string `json:"url"`
}

// DealStatusResponse represents the status of a deal product.
type DealStatusResponse struct {
	State    string `json:"status"`
	ErrorMsg string `json:"errorMsg"`
}

// DealProductStatusResponse contains per-product status.
type DealProductStatusResponse struct {
	DDOV1 *DealStatusResponse `json:"ddo_v1,omitempty"`
}

// CborEncodeUint64 produces minimal CBOR encoding of a uint64 value.
func CborEncodeUint64(v uint64) []byte {
	if v < 24 {
		return []byte{byte(v)}
	}
	if v <= 0xFF {
		return []byte{0x18, byte(v)}
	}
	if v <= 0xFFFF {
		buf := make([]byte, 3)
		buf[0] = 0x19
		binary.BigEndian.PutUint16(buf[1:], uint16(v))
		return buf
	}
	if v <= 0xFFFFFFFF {
		buf := make([]byte, 5)
		buf[0] = 0x1a
		binary.BigEndian.PutUint32(buf[1:], uint32(v))
		return buf
	}
	buf := make([]byte, 9)
	buf[0] = 0x1b
	binary.BigEndian.PutUint64(buf[1:], v)
	return buf
}
