package storage

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

type FSStore struct {
	cfg *Config
}

func NewFSStore(cfg *Config) *FSStore {
	return &FSStore{cfg: cfg}
}

func (s *FSStore) baseDir(bucket string) string {
	return filepath.Join(s.cfg.StorageDir, bucket)
}

func (s *FSStore) Put(ctx context.Context, bucket, key string, data io.Reader, size int64, contentType string) error {
	path := filepath.Join(s.baseDir(bucket), key)
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}

	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(file, data)
	return err
}

func (s *FSStore) PublicURL(bucket, key string) string {
	return fmt.Sprintf("/uploads/%s/%s", bucket, key)
}

func (s *FSStore) SignedURL(ctx context.Context, bucket, key string, expiry time.Duration) (string, error) {
	return s.PublicURL(bucket, key), nil
}

func (s *FSStore) Delete(ctx context.Context, bucket, key string) error {
	return os.Remove(filepath.Join(s.baseDir(bucket), key))
}
