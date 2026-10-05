package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port        string
	DatabaseURL string
	StorageDir  string
	MaxWorkers  int
	CORSOrigin  string
}

func Load() *Config {
	port := getEnv("PORT", "3030")
	dbURL := getEnv("DATABASE_URL", "postgres://dushmanta:password@localhost:5432/mewmer?sslmode=disable")
	storageDir := getEnv("STORAGE_DIR", "./uploads")
	corsOrigin := getEnv("CORS_ORIGIN", "*")

	maxWorkers := 2
	if workersStr := os.Getenv("MAX_WORKERS"); workersStr != "" {
		if val, err := strconv.Atoi(workersStr); err == nil && val > 0 {
			maxWorkers = val
		}
	}

	return &Config{
		Port:        port,
		DatabaseURL: dbURL,
		StorageDir:  storageDir,
		MaxWorkers:  maxWorkers,
		CORSOrigin:  corsOrigin,
	}
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}
