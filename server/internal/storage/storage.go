package storage

import (
	"context"
	"fmt"
	"io"
	"time"
)

type Config struct {
	Type           string
	StorageDir     string
	PublicBucket   string
	PrivateBucket  string
	PublicEndpoint string
	R2AccountID    string
	R2AccessKey    string
	R2SecretKey    string
}

type Store interface {
	Put(ctx context.Context, bucket, key string, data io.Reader, size int64, contentType string) error
	PublicURL(bucket, key string) string
	SignedURL(ctx context.Context, bucket, key string, expiry time.Duration) (string, error)
	Delete(ctx context.Context, bucket, key string) error
}

func New(ctx context.Context, cfg *Config) (Store, error) {
	switch cfg.Type {
	case "r2":
		if cfg.R2AccountID == "" || cfg.R2AccessKey == "" || cfg.R2SecretKey == "" || cfg.PublicBucket == "" || cfg.PrivateBucket == "" {
			return nil, fmt.Errorf("incomplete r2 storage configuration")
		}
		return NewR2Store(ctx, cfg)
	default:
		return NewFSStore(cfg), nil
	}
}
