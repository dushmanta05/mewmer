package config

import (
	"os"
	"time"
)

type Config struct {
	Port             string
	DatabaseURL      string
	StorageDir       string
	StorageType      string
	CORSOrigin       string
	SessionTTL       time.Duration
	SecureCookie     bool
	CookieDomain     string
	R2AccountID      string
	R2AccessKey      string
	R2SecretKey      string
	R2PublicBucket   string
	R2PrivateBucket  string
	R2PublicEndpoint string
}

func Load() *Config {
	port := getEnv("PORT", "3030")
	dbURL := getEnv("DATABASE_URL", "postgres://dushmanta:password@localhost:5432/mewmer?sslmode=disable")
	storageDir := getEnv("STORAGE_DIR", "./uploads")
	storageType := getEnv("STORAGE_TYPE", "filesystem")
	corsOrigin := getEnv("CORS_ORIGIN", "*")

	sessionTTL := 7 * 24 * time.Hour
	if ttlStr := os.Getenv("SESSION_TTL"); ttlStr != "" {
		if val, err := time.ParseDuration(ttlStr); err == nil && val > 0 {
			sessionTTL = val
		}
	}

	secureCookie := false
	if secureStr := os.Getenv("SECURE_COOKIE"); secureStr == "true" {
		secureCookie = true
	}

	return &Config{
		Port:             port,
		DatabaseURL:      dbURL,
		StorageDir:       storageDir,
		StorageType:      storageType,
		CORSOrigin:       corsOrigin,
		SessionTTL:       sessionTTL,
		SecureCookie:     secureCookie,
		CookieDomain:     getEnv("COOKIE_DOMAIN", ""),
		R2AccountID:      os.Getenv("R2_ACCOUNT_ID"),
		R2AccessKey:      os.Getenv("R2_ACCESS_KEY_ID"),
		R2SecretKey:      os.Getenv("R2_SECRET_ACCESS_KEY"),
		R2PublicBucket:   getEnv("R2_PUBLIC_BUCKET", "mewmer-public-media"),
		R2PrivateBucket:  getEnv("R2_PRIVATE_BUCKET", "mewmer-private-media"),
		R2PublicEndpoint: getEnv("R2_PUBLIC_ENDPOINT", ""),
	}
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}
