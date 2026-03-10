package curio

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/oklog/ulid/v2"
)

const marketPath = "/market/mk20"

// Client is an HTTP client for the Curio MK20 REST API.
type Client struct {
	baseURL    string
	httpClient *http.Client
	privateKey *ecdsa.PrivateKey
}

// NewClient creates a new Curio MK20 client.
func NewClient(baseURL string, privateKey *ecdsa.PrivateKey) *Client {
	return &Client{
		baseURL: baseURL + marketPath,
		httpClient: &http.Client{
			Timeout: 5 * time.Minute,
		},
		privateKey: privateKey,
	}
}

// Store submits a new deal to the Curio MK20 API.
func (c *Client) Store(ctx context.Context, deal *Deal) error {
	body, err := json.Marshal(deal)
	if err != nil {
		return fmt.Errorf("failed to marshal deal: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/store", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.doWithAuth(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("store failed (status %d): %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// UploadSerial streams data to the Curio MK20 API for a given deal.
func (c *Client) UploadSerial(ctx context.Context, dealID ulid.ULID, reader io.Reader) error {
	url := fmt.Sprintf("%s/upload/%s", c.baseURL, dealID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, url, reader)
	if err != nil {
		return fmt.Errorf("failed to create upload request: %w", err)
	}
	req.Header.Set("Content-Type", "application/octet-stream")

	resp, err := c.doWithAuth(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("upload failed (status %d): %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// UploadSerialFinalize finalizes the upload for a given deal.
func (c *Client) UploadSerialFinalize(ctx context.Context, dealID ulid.ULID) error {
	url := fmt.Sprintf("%s/upload/%s", c.baseURL, dealID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, nil)
	if err != nil {
		return fmt.Errorf("failed to create finalize request: %w", err)
	}

	resp, err := c.doWithAuth(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("finalize failed (status %d): %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// DealStatus queries the status of a deal.
func (c *Client) DealStatus(ctx context.Context, dealID ulid.ULID) (*DealProductStatusResponse, error) {
	url := fmt.Sprintf("%s/status/%s", c.baseURL, dealID.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create status request: %w", err)
	}

	resp, err := c.doWithAuth(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("status query failed (status %d): %s", resp.StatusCode, string(respBody))
	}

	var status DealProductStatusResponse
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return nil, fmt.Errorf("failed to decode status response: %w", err)
	}

	return &status, nil
}

// doWithAuth injects the CurioAuth header and executes the request.
func (c *Client) doWithAuth(req *http.Request) (*http.Response, error) {
	authHeader, err := GenerateAuthHeader(c.privateKey)
	if err != nil {
		return nil, fmt.Errorf("failed to generate auth header: %w", err)
	}
	req.Header.Set("Authorization", authHeader)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}

	return resp, nil
}
