package database

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/dushmanta05/mewmer/server/internal/models"
)

type DB struct {
	Pool *pgxpool.Pool
}

func Connect(ctx context.Context, databaseURL string) (*DB, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("unable to parse database config: %w", err)
	}

	config.MaxConns = 15
	config.MinConns = 2
	config.MaxConnLifetime = time.Hour
	config.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("unable to create connection pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		log.Printf("⚠️ Database connection failed (database might not be running yet): %v", err)
		return &DB{Pool: pool}, nil
	}

	log.Println(" Connected to PostgreSQL database")
	return &DB{Pool: pool}, nil
}

func (db *DB) Close() {
	if db.Pool != nil {
		db.Pool.Close()
	}
}

// GetPublicPacks returns public sticker packs with search and pagination
func (db *DB) GetPublicPacks(ctx context.Context, searchQuery string, limit, offset int) ([]models.StickerPack, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	var query string
	var args []interface{}

	if searchQuery != "" {
		query = `
			SELECT id, title, publisher, tray_image_url, is_animated, is_public, downloads_count, created_at
			FROM sticker_packs
			WHERE is_public = true AND (title ILIKE $1 OR publisher ILIKE $1)
			ORDER BY downloads_count DESC, created_at DESC
			LIMIT $2 OFFSET $3
		`
		args = []interface{}{"%" + searchQuery + "%", limit, offset}
	} else {
		query = `
			SELECT id, title, publisher, tray_image_url, is_animated, is_public, downloads_count, created_at
			FROM sticker_packs
			WHERE is_public = true
			ORDER BY downloads_count DESC, created_at DESC
			LIMIT $1 OFFSET $2
		`
		args = []interface{}{limit, offset}
	}

	rows, err := db.Pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var packs []models.StickerPack
	for rows.Next() {
		var p models.StickerPack
		if err := rows.Scan(&p.ID, &p.Title, &p.Publisher, &p.TrayImageURL, &p.IsAnimated, &p.IsPublic, &p.DownloadsCount, &p.CreatedAt); err != nil {
			return nil, err
		}
		packs = append(packs, p)
	}

	return packs, nil
}

// GetPackByID retrieves a sticker pack and all its stickers
func (db *DB) GetPackByID(ctx context.Context, packID string) (*models.StickerPack, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT id, title, publisher, tray_image_url, is_animated, is_public, downloads_count, created_at
		FROM sticker_packs
		WHERE id = $1
	`
	var p models.StickerPack
	err := db.Pool.QueryRow(ctx, query, packID).Scan(
		&p.ID, &p.Title, &p.Publisher, &p.TrayImageURL, &p.IsAnimated, &p.IsPublic, &p.DownloadsCount, &p.CreatedAt,
	)
	if err != nil {
		return nil, err
	}

	// Fetch stickers
	stickerQuery := `
		SELECT id, pack_id, image_url, emojis, file_size, is_animated, created_at
		FROM stickers
		WHERE pack_id = $1
		ORDER BY created_at ASC
	`
	rows, err := db.Pool.Query(ctx, stickerQuery, packID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var s models.Sticker
		if err := rows.Scan(&s.ID, &s.PackID, &s.ImageURL, &s.Emojis, &s.FileSize, &s.IsAnimated, &s.CreatedAt); err != nil {
			return nil, err
		}
		p.Stickers = append(p.Stickers, s)
	}

	return &p, nil
}

// CreatePack inserts a new pack and its sticker records inside a transaction
func (db *DB) CreatePack(ctx context.Context, pack *models.StickerPack, stickerURLs []string) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	packQuery := `
		INSERT INTO sticker_packs (id, title, publisher, tray_image_url, is_animated, is_public, user_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err = tx.Exec(ctx, packQuery, pack.ID, pack.Title, pack.Publisher, pack.TrayImageURL, pack.IsAnimated, pack.IsPublic, pack.UserID)
	if err != nil {
		return fmt.Errorf("failed to insert pack: %w", err)
	}

	stickerQuery := `
		INSERT INTO stickers (pack_id, image_url, emojis, is_animated)
		VALUES ($1, $2, $3, $4)
	`
	for _, url := range stickerURLs {
		_, err = tx.Exec(ctx, stickerQuery, pack.ID, url, []string{"✨"}, pack.IsAnimated)
		if err != nil {
			return fmt.Errorf("failed to insert sticker: %w", err)
		}
	}

	return tx.Commit(ctx)
}
