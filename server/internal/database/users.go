package database

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/jackc/pgx/v5"
)

func (db *DB) CreateUser(ctx context.Context, email, username, displayName, passwordHash, role string) (*models.User, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		INSERT INTO users (email, username, display_name, password_hash, role)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, email, username, display_name, password_hash, role, avatar_key, bio, links, created_at, updated_at
	`
	row := db.Pool.QueryRow(
		ctx,
		query,
		strings.ToLower(strings.TrimSpace(email)),
		strings.ToLower(strings.TrimSpace(username)),
		displayName,
		passwordHash,
		role,
	)
	return scanUser(row)
}

func (db *DB) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT id, email, username, display_name, password_hash, role, avatar_key, bio, links, created_at, updated_at
		FROM users
		WHERE email = $1
	`
	return scanUser(db.Pool.QueryRow(ctx, query, strings.ToLower(strings.TrimSpace(email))))
}

func (db *DB) GetUserByUsername(ctx context.Context, username string) (*models.User, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT id, email, username, display_name, password_hash, role, avatar_key, bio, links, created_at, updated_at
		FROM users
		WHERE username = $1
	`
	return scanUser(db.Pool.QueryRow(ctx, query, strings.ToLower(strings.TrimSpace(username))))
}

func (db *DB) GetUserByID(ctx context.Context, id string) (*models.User, error) {
	if db.Pool == nil {
		return nil, fmt.Errorf("database not connected")
	}

	query := `
		SELECT id, email, username, display_name, password_hash, role, avatar_key, bio, links, created_at, updated_at
		FROM users
		WHERE id = $1
	`
	return scanUser(db.Pool.QueryRow(ctx, query, id))
}

func (db *DB) UpdateUserPasswordAndRole(ctx context.Context, id, passwordHash, role string) error {
	if db.Pool == nil {
		return fmt.Errorf("database not connected")
	}

	query := `UPDATE users SET password_hash = $1, role = $2, updated_at = NOW() WHERE id = $3`
	_, err := db.Pool.Exec(ctx, query, passwordHash, role, id)
	return err
}

func (db *DB) IsNotFound(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}

func scanUser(row pgx.Row) (*models.User, error) {
	var u models.User
	err := row.Scan(
		&u.ID,
		&u.Email,
		&u.Username,
		&u.DisplayName,
		&u.PasswordHash,
		&u.Role,
		&u.AvatarKey,
		&u.Bio,
		&u.Links,
		&u.CreatedAt,
		&u.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &u, nil
}
