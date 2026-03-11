package token

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	ethtypes "github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
)

func testAuth() *bind.TransactOpts {
	return &bind.TransactOpts{
		From:   common.HexToAddress("0x1"),
		Signer: func(common.Address, *ethtypes.Transaction) (*ethtypes.Transaction, error) { return nil, nil },
	}
}

func dialTestServer(t *testing.T) *ethclient.Client {
	t.Helper()
	srv := httptest.NewServer(nil)
	t.Cleanup(srv.Close)
	rc, err := rpc.Dial(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	return ethclient.NewClient(rc)
}

func TestNewERC20ClientWithTransactor_NilEthClient(t *testing.T) {
	_, err := NewERC20ClientWithTransactor(nil, "0xdead", testAuth())
	if err == nil || !strings.Contains(err.Error(), "ethClient") {
		t.Fatalf("expected ethClient error, got: %v", err)
	}
}

func TestNewERC20ClientWithTransactor_NilAuth(t *testing.T) {
	ec := dialTestServer(t)
	defer ec.Close()

	_, err := NewERC20ClientWithTransactor(ec, "0xdead", nil)
	if err == nil || !strings.Contains(err.Error(), "auth") {
		t.Fatalf("expected auth error, got: %v", err)
	}
}

func TestCloseIsNoOpForNonOwningClient(t *testing.T) {
	ec := dialTestServer(t)
	defer ec.Close()

	c, err := NewERC20ClientWithTransactor(ec, "0xdead", testAuth())
	if err != nil {
		t.Fatal(err)
	}

	c.Close()

	_, err = ec.ChainID(context.Background())
	if err != nil && strings.Contains(err.Error(), "closed") {
		t.Fatalf("ethclient was closed by non-owning wrapper: %v", err)
	}
}
