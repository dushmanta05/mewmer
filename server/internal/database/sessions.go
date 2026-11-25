package database

import (
	"context"
	"fmt"
	"time"

	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/jackc/pgx/v5"
)

func (db *DB) CreateSession(ctx context.Context, userID, tokenHash string, expiresAt time.Time) (*models.Session, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		INSERT INTO sessions (user_id, token_hash, expires_at)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, token_hash, created_at, expires_at, last_used_at
	`
	return scanSession(db.Pool.QueryRow(ctx, query, userID, tokenHash, expiresAt))
}

func (db *DB) GetSessionAndUser(ctx context.Context, tokenHash string) (*models.Session, *models.User, error) {
	if db.Pool == nil {
		return nil, nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT
			s.id, s.user_id, s.token_hash, s.created_at, s.expires_at, s.last_used_at,
			u.id, u.email, u.username, u.display_name, u.password_hash, u.role, u.avatar_key, u.bio, u.links, u.created_at, u.updated_at
		FROM sessions s
		JOIN users u ON u.id = s.user_id
		WHERE s.token_hash = $1 AND s.expires_at > NOW()
	`
	row := db.Pool.QueryRow(ctx, query, tokenHash)

	var s models.Session
	var u models.User
	err := row.Scan(
		&s.ID, &s.UserID, &s.TokenHash, &s.CreatedAt, &s.ExpiresAt, &s.LastUsedAt,
		&u.ID, &u.Email, &u.Username, &u.DisplayName, &u.PasswordHash, &u.Role, &u.AvatarKey, &u.Bio, &u.Links, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		return nil, nil, err
	}
	return &s, &u, nil
}

func (db *DB) DeleteSession(ctx context.Context, tokenHash string) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	query := `DELETE FROM sessions WHERE token_hash = $1`
	_, err := db.Pool.Exec(ctx, query, tokenHash)
	return err
}

func (db *DB) DeleteSessionByID(ctx context.Context, id string) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	query := `DELETE FROM sessions WHERE id = $1`
	_, err := db.Pool.Exec(ctx, query, id)
	return err
}

func scanSession(row pgx.Row) (*models.Session, error) {
	var s models.Session
	err := row.Scan(&s.ID, &s.UserID, &s.TokenHash, &s.CreatedAt, &s.ExpiresAt, &s.LastUsedAt)
	if err != nil {
		return nil, err
	}
	return &s, nil
}
