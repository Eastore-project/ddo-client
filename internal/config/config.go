package config

import "os"

// Global configuration variables
var (
	RPCEndpoint     string
	ContractAddress string
	PrivateKey      string
)

// LoadFromEnv loads configuration from environment variables with defaults
func LoadFromEnv() {
	RPCEndpoint = getEnvWithDefault("RPC_ENDPOINT", "http://localhost:8545")
	ContractAddress = getEnvWithDefault("DDO_CONTRACT_ADDRESS", "")
	PrivateKey = getEnvWithDefault("PRIVATE_KEY", "")
}

func getEnvWithDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// Validation helpers
func IsConfigured() bool {
	return ContractAddress != "" && PrivateKey != ""
}

func GetMissingConfig() []string {
	var missing []string
	if ContractAddress == "" {
		missing = append(missing, "DDO_CONTRACT_ADDRESS or --contract flag")
	}
	if PrivateKey == "" {
		missing = append(missing, "PRIVATE_KEY or --private-key flag")
	}
	return missing
} 