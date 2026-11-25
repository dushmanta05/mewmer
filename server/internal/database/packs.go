package database

import (
	"context"
	"fmt"

	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/jackc/pgx/v5"
)

func (db *DB) CreatePack(ctx context.Context, p *models.StickerPack) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	query := `
		INSERT INTO sticker_packs (id, title, publisher, tray_image_key, is_animated, visibility, user_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING created_at, updated_at
	`
	return db.Pool.QueryRow(
		ctx,
		query,
		p.ID, p.Title, p.Publisher, p.TrayImageKey, p.IsAnimated, p.Visibility, p.UserID,
	).Scan(&p.CreatedAt, &p.UpdatedAt)
}

func (db *DB) GetPacksByUser(ctx context.Context, userID string) ([]models.StickerPack, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT id, title, publisher, tray_image_key, is_animated, visibility, user_id, downloads_count, created_at, updated_at
		FROM sticker_packs
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	rows, err := db.Pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var packs []models.StickerPack
	for rows.Next() {
		var p models.StickerPack
		if err := rows.Scan(
			&p.ID, &p.Title, &p.Publisher, &p.TrayImageKey, &p.IsAnimated, &p.Visibility,
			&p.UserID, &p.DownloadsCount, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, err
		}
		packs = append(packs, p)
	}
	return packs, nil
}

func (db *DB) GetPackByIDWithStickers(ctx context.Context, packID, userID string) (*models.StickerPack, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT id, title, publisher, tray_image_key, is_animated, visibility, user_id, downloads_count, created_at, updated_at
		FROM sticker_packs
		WHERE id = $1 AND user_id = $2
	`
	var p models.StickerPack
	err := db.Pool.QueryRow(ctx, query, packID, userID).Scan(
		&p.ID, &p.Title, &p.Publisher, &p.TrayImageKey, &p.IsAnimated, &p.Visibility,
		&p.UserID, &p.DownloadsCount, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	stickerQuery := `
		SELECT id, pack_id, user_id, image_key, emojis, byte_size, width, height, is_animated, sort_order, created_at, updated_at
		FROM stickers
		WHERE pack_id = $1 AND user_id = $2
		ORDER BY sort_order ASC, created_at ASC
	`
	stickerRows, err := db.Pool.Query(ctx, stickerQuery, packID, userID)
	if err != nil {
		return nil, err
	}
	defer stickerRows.Close()

	for stickerRows.Next() {
		var s models.Sticker
		if err := stickerRows.Scan(
			&s.ID, &s.PackID, &s.UserID, &s.ImageKey, &s.Emojis, &s.ByteSize,
			&s.Width, &s.Height, &s.IsAnimated, &s.SortOrder, &s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, err
		}
		p.Stickers = append(p.Stickers, s)
	}

	return &p, nil
}

func (db *DB) CreateSticker(ctx context.Context, s *models.Sticker) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var existingIsAnimated *bool
	err = tx.QueryRow(
		ctx,
		`SELECT is_animated FROM sticker_packs WHERE id = $1 AND user_id = $2`,
		s.PackID, s.UserID,
	).Scan(&existingIsAnimated)
	if err != nil {
		return err
	}

	if existingIsAnimated != nil && *existingIsAnimated != s.IsAnimated {
		return fmt.Errorf("cannot mix static and animated stickers in one pack")
	}

	var order int
	err = tx.QueryRow(
		ctx,
		`SELECT COALESCE(MAX(sort_order), 0) + 1 FROM stickers WHERE pack_id = $1`,
		s.PackID,
	).Scan(&order)
	if err != nil {
		return err
	}
	s.SortOrder = order

	insertQuery := `
		INSERT INTO stickers (pack_id, user_id, image_key, emojis, byte_size, width, height, is_animated, sort_order)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, created_at, updated_at
	`
	err = tx.QueryRow(
		ctx,
		insertQuery,
		s.PackID, s.UserID, s.ImageKey, s.Emojis, s.ByteSize, s.Width, s.Height, s.IsAnimated, s.SortOrder,
	).Scan(&s.ID, &s.CreatedAt, &s.UpdatedAt)
	if err != nil {
		return err
	}

	if existingIsAnimated == nil {
		_, err = tx.Exec(
			ctx,
			`UPDATE sticker_packs SET is_animated = $1, updated_at = NOW() WHERE id = $2`,
			s.IsAnimated, s.PackID,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func (db *DB) DeletePack(ctx context.Context, packID, userID string) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	query := `DELETE FROM sticker_packs WHERE id = $1 AND user_id = $2`
	_, err := db.Pool.Exec(ctx, query, packID, userID)
	return err
}

func (db *DB) DeleteSticker(ctx context.Context, stickerID, userID string) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	query := `DELETE FROM stickers WHERE id = $1 AND user_id = $2`
	_, err := db.Pool.Exec(ctx, query, stickerID, userID)
	return err
}

func (db *DB) GetStickerByID(ctx context.Context, stickerID, userID string) (*models.Sticker, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT id, pack_id, user_id, image_key, emojis, byte_size, width, height, is_animated, sort_order, created_at, updated_at
		FROM stickers
		WHERE id = $1 AND user_id = $2
	`
	var s models.Sticker
	err := db.Pool.QueryRow(ctx, query, stickerID, userID).Scan(
		&s.ID, &s.PackID, &s.UserID, &s.ImageKey, &s.Emojis, &s.ByteSize,
		&s.Width, &s.Height, &s.IsAnimated, &s.SortOrder, &s.CreatedAt, &s.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func scanPack(row pgx.Row) (*models.StickerPack, error) {
	var p models.StickerPack
	err := row.Scan(
		&p.ID, &p.Title, &p.Publisher, &p.TrayImageKey, &p.IsAnimated, &p.Visibility,
		&p.UserID, &p.DownloadsCount, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}
