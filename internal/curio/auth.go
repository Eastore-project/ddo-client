package curio

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/filecoin-project/go-address"
)

// GenerateAuthHeader produces the CurioAuth authorization header value
// using the delegated (f410) signing scheme without Lotus dependencies.
//
// Algorithm:
//  1. Derive Filecoin delegated address from the Ethereum address
//  2. Truncate current UTC time to the hour
//  3. Message = SHA256(filAddr.Bytes() || timestampRFC3339)
//  4. Hash the digest with Keccak256, then sign with secp256k1
//  5. Prepend sig type byte 0x03 (SigTypeDelegated)
//  6. Format: "CurioAuth delegated:<base64(filAddr.Bytes())>:<base64(sigWithType)>"
func GenerateAuthHeader(privateKey *ecdsa.PrivateKey) (string, error) {
	ethAddr := crypto.PubkeyToAddress(privateKey.PublicKey)
	return generateAuthHeaderForAddr(privateKey, ethAddr)
}

func generateAuthHeaderForAddr(privateKey *ecdsa.PrivateKey, ethAddr common.Address) (string, error) {
	filAddr, err := address.NewDelegatedAddress(10, ethAddr.Bytes())
	if err != nil {
		return "", fmt.Errorf("failed to create delegated address: %w", err)
	}

	pubKeyBytes := filAddr.Bytes()

	now := time.Now().UTC().Truncate(time.Hour)
	timestamp := now.Format(time.RFC3339)

	msg := bytes.Join([][]byte{pubKeyBytes, []byte(timestamp)}, []byte{})
	digest := sha256.Sum256(msg)

	// Sign: Keccak256 the SHA256 digest, then secp256k1 sign
	hash := crypto.Keccak256(digest[:])
	sig, err := crypto.Sign(hash, privateKey)
	if err != nil {
		return "", fmt.Errorf("failed to sign auth message: %w", err)
	}

	// Prepend SigTypeDelegated (0x03) to make it a Filecoin-compatible signature
	sigWithType := append([]byte{0x03}, sig...)

	header := fmt.Sprintf("CurioAuth delegated:%s:%s",
		base64.StdEncoding.EncodeToString(pubKeyBytes),
		base64.StdEncoding.EncodeToString(sigWithType),
	)

	return header, nil
}
