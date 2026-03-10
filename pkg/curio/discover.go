package curio

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	multiaddr "github.com/multiformats/go-multiaddr"
)

// jsonRPCRequest is a minimal JSON-RPC 2.0 request.
type jsonRPCRequest struct {
	JSONRPC string        `json:"jsonrpc"`
	Method  string        `json:"method"`
	Params  []interface{} `json:"params"`
	ID      int           `json:"id"`
}

// jsonRPCResponse is a minimal JSON-RPC 2.0 response.
type jsonRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	Result  json.RawMessage `json:"result"`
	Error   *jsonRPCError   `json:"error,omitempty"`
	ID      int             `json:"id"`
}

type jsonRPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// minerInfoResult holds the fields we care about from StateMinerInfo.
type minerInfoResult struct {
	Multiaddrs []string `json:"Multiaddrs"` // base64-encoded multiaddr bytes
}

// DiscoverSPURL queries the Filecoin node for the SP's on-chain multiaddrs
// and returns the HTTP market URL if one is announced.
func DiscoverSPURL(rpcURL string, providerID uint64) (string, error) {
	minerAddr := fmt.Sprintf("f0%d", providerID)

	reqBody := jsonRPCRequest{
		JSONRPC: "2.0",
		Method:  "Filecoin.StateMinerInfo",
		Params:  []interface{}{minerAddr, nil},
		ID:      1,
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal RPC request: %w", err)
	}

	resp, err := http.Post(rpcURL, "application/json", bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("RPC request failed: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read RPC response: %w", err)
	}

	var rpcResp jsonRPCResponse
	if err := json.Unmarshal(respBytes, &rpcResp); err != nil {
		return "", fmt.Errorf("failed to decode RPC response: %w", err)
	}

	if rpcResp.Error != nil {
		return "", fmt.Errorf("RPC error: %s", rpcResp.Error.Message)
	}

	var minerInfo minerInfoResult
	if err := json.Unmarshal(rpcResp.Result, &minerInfo); err != nil {
		return "", fmt.Errorf("failed to decode miner info: %w", err)
	}

	if len(minerInfo.Multiaddrs) == 0 {
		return "", fmt.Errorf("SP f0%d has no multiaddrs announced on chain", providerID)
	}

	// Parse each multiaddr looking for an HTTP/HTTPS endpoint.
	// First pass: look for explicit /http or /https multiaddrs.
	// Second pass: fall back to any multiaddr with a host+port (Curio registers
	// its libp2p /ws address on-chain, but the HTTP server shares the same host:port).
	var fallbackURL string
	for _, maB64 := range minerInfo.Multiaddrs {
		maBytes, err := base64.StdEncoding.DecodeString(maB64)
		if err != nil {
			continue
		}

		ma, err := multiaddr.NewMultiaddrBytes(maBytes)
		if err != nil {
			continue
		}

		u, err := multiaddrToURL(ma)
		if err == nil {
			return u, nil
		}

		// Save as fallback — extract host:port even without /http suffix
		if fallbackURL == "" {
			if fb, fbErr := multiaddrToFallbackURL(ma); fbErr == nil {
				fallbackURL = fb
			}
		}
	}

	if fallbackURL != "" {
		return fallbackURL, nil
	}

	return "", fmt.Errorf("SP f0%d has no HTTP endpoint in multiaddrs: %v", providerID, minerInfo.Multiaddrs)
}

// multiaddrToURL converts a multiaddr like /dns/example.com/tcp/12310/http into http://example.com:12310
func multiaddrToURL(ma multiaddr.Multiaddr) (string, error) {
	maStr := ma.String()

	// Must contain /http or /https
	isHTTPS := strings.Contains(maStr, "/https")
	isHTTP := strings.Contains(maStr, "/http")
	if !isHTTP && !isHTTPS {
		return "", fmt.Errorf("not an HTTP multiaddr: %s", maStr)
	}

	scheme := "http"
	if isHTTPS && !strings.Contains(maStr, "/http/") {
		scheme = "https"
	}

	// Extract host from /dns/, /dns4/, /dns6/, or /ip4/, /ip6/
	var host string
	for _, proto := range []string{"/dns6/", "/dns4/", "/dns/", "/ip4/", "/ip6/"} {
		if idx := strings.Index(maStr, proto); idx != -1 {
			rest := maStr[idx+len(proto):]
			host = strings.SplitN(rest, "/", 2)[0]
			break
		}
	}
	if host == "" {
		return "", fmt.Errorf("no host found in multiaddr: %s", maStr)
	}

	// Extract port from /tcp/
	var port string
	if idx := strings.Index(maStr, "/tcp/"); idx != -1 {
		rest := maStr[idx+len("/tcp/"):]
		port = strings.SplitN(rest, "/", 2)[0]
	}

	if port == "" || port == "443" && scheme == "https" || port == "80" && scheme == "http" {
		return fmt.Sprintf("%s://%s", scheme, host), nil
	}

	return fmt.Sprintf("%s://%s:%s", scheme, host, port), nil
}

// multiaddrToFallbackURL extracts host:port from a multiaddr that lacks an
// explicit /http or /https protocol. Curio's on-chain multiaddr is typically
// the libp2p /ws address, but its HTTP server listens on the same host:port.
func multiaddrToFallbackURL(ma multiaddr.Multiaddr) (string, error) {
	maStr := ma.String()

	var host string
	for _, proto := range []string{"/dns6/", "/dns4/", "/dns/", "/ip4/", "/ip6/"} {
		if idx := strings.Index(maStr, proto); idx != -1 {
			rest := maStr[idx+len(proto):]
			host = strings.SplitN(rest, "/", 2)[0]
			break
		}
	}
	if host == "" {
		return "", fmt.Errorf("no host found in multiaddr: %s", maStr)
	}

	var port string
	if idx := strings.Index(maStr, "/tcp/"); idx != -1 {
		rest := maStr[idx+len("/tcp/"):]
		port = strings.SplitN(rest, "/", 2)[0]
	}
	if port == "" {
		return "", fmt.Errorf("no port found in multiaddr: %s", maStr)
	}

	return fmt.Sprintf("http://%s:%s", host, port), nil
}
