package database

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/jackc/pgx/v5"
)

func (db *DB) CreateTemplate(ctx context.Context, t *models.Template) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	query := `
		INSERT INTO meme_templates (
			slug, title, description, image_key, thumbnail_key, media_type,
			width, height, byte_size, mime_type, tags, creator_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, created_at, updated_at
	`
	return db.Pool.QueryRow(
		ctx,
		query,
		t.Slug, t.Title, t.Description, t.ImageKey, t.ThumbnailKey, t.MediaType,
		t.Width, t.Height, t.ByteSize, t.MimeType, t.Tags, t.CreatorID,
	).Scan(&t.ID, &t.CreatedAt, &t.UpdatedAt)
}

func (db *DB) GetTemplateBySlug(ctx context.Context, slug string) (*models.Template, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT id, slug, title, description, image_key, thumbnail_key, media_type,
		       width, height, byte_size, mime_type, tags, creator_id, memes_count,
		       is_verified, is_active, created_at, updated_at
		FROM meme_templates
		WHERE slug = $1 AND is_active = true
	`
	return scanTemplate(db.Pool.QueryRow(ctx, query, slug))
}

func (db *DB) GetTemplates(ctx context.Context, search, tag, sort string, limit, offset int) ([]models.Template, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	if limit <= 0 {
		limit = 24
	}

	var args []interface{}
	var conditions []string
	conditions = append(conditions, "is_active = true")

	if search != "" {
		conditions = append(conditions, "title ILIKE $"+strconv.Itoa(nextArg(&args)))
		args = append(args, "%"+search+"%")
	}
	if tag != "" {
		conditions = append(conditions, "tags @> $"+strconv.Itoa(nextArg(&args)))
		args = append(args, []string{strings.ToLower(strings.TrimSpace(tag))})
	}

	order := "created_at DESC"
	if sort == "popular" {
		order = "memes_count DESC, created_at DESC"
	}

	whereClause := strings.Join(conditions, " AND ")
	query := fmt.Sprintf(`
		SELECT id, slug, title, description, image_key, thumbnail_key, media_type,
		       width, height, byte_size, mime_type, tags, creator_id, memes_count,
		       is_verified, is_active, created_at, updated_at
		FROM meme_templates
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, whereClause, order, nextArg(&args), nextArg(&args)+1)
	args = append(args, limit, offset)

	rows, err := db.Pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var templates []models.Template
	for rows.Next() {
		t, err := scanTemplate(rows)
		if err != nil {
			return nil, err
		}
		templates = append(templates, *t)
	}
	return templates, nil
}

func nextArg(args *[]interface{}) int {
	return len(*args) + 1
}

func scanTemplate(row pgx.Row) (*models.Template, error) {
	var t models.Template
	err := row.Scan(
		&t.ID, &t.Slug, &t.Title, &t.Description, &t.ImageKey, &t.ThumbnailKey,
		&t.MediaType, &t.Width, &t.Height, &t.ByteSize, &t.MimeType, &t.Tags,
		&t.CreatorID, &t.MemesCount, &t.IsVerified, &t.IsActive, &t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &t, nil
}
