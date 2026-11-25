package main

import (
	"context"
	"errors"
	"log"
	"os"
	"strings"

	"github.com/dushmanta05/mewmer/server/internal/auth"
	"github.com/dushmanta05/mewmer/server/internal/config"
	"github.com/dushmanta05/mewmer/server/internal/database"
	"github.com/jackc/pgx/v5"
)

func main() {
	cfg := config.Load()
	ctx := context.Background()

	db, err := database.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database connection error: %v", err)
	}
	defer db.Close()

	email := strings.TrimSpace(os.Getenv("ADMIN_EMAIL"))
	username := strings.TrimSpace(os.Getenv("ADMIN_USERNAME"))
	displayName := strings.TrimSpace(os.Getenv("ADMIN_DISPLAY_NAME"))
	password := os.Getenv("ADMIN_PASSWORD")

	if email == "" || username == "" || displayName == "" || password == "" {
		log.Fatal("ADMIN_EMAIL, ADMIN_USERNAME, ADMIN_DISPLAY_NAME, and ADMIN_PASSWORD must be set")
	}

	hasher := auth.NewPasswordHasher()
	hash, err := hasher.Hash(password)
	if err != nil {
		log.Fatalf("failed to hash password: %v", err)
	}

	existing, err := db.GetUserByEmail(ctx, email)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		log.Fatalf("failed to look up user: %v", err)
	}

	if existing != nil {
		if err := db.UpdateUserPasswordAndRole(ctx, existing.ID, hash, "admin"); err != nil {
			log.Fatalf("failed to update admin: %v", err)
		}
		log.Printf("Updated admin user: %s (%s)", existing.Username, existing.ID)
		return
	}

	user, err := db.CreateUser(ctx, email, username, displayName, hash, "admin")
	if err != nil {
		log.Fatalf("failed to create admin: %v", err)
	}

	log.Printf("Created admin user: %s (%s)", user.Username, user.ID)
}
