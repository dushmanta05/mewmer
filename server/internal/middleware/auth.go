package middleware

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"
	"time"

	"github.com/dushmanta05/mewmer/server/internal/database"
	"github.com/dushmanta05/mewmer/server/internal/models"
)

type ctxKey int

const (
	userKey ctxKey = iota
	sessionKey
)

func Auth(db *database.DB) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := ExtractToken(r)
			if token == "" {
				next.ServeHTTP(w, r)
				return
			}

			session, user, err := db.GetSessionAndUser(r.Context(), hashToken(token))
			if err != nil || session.ExpiresAt.Before(time.Now().UTC()) {
				next.ServeHTTP(w, r)
				return
			}

			ctx := context.WithValue(r.Context(), userKey, user)
			ctx = context.WithValue(ctx, sessionKey, session)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if User(r.Context()) == nil {
			http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func RequireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		u := User(r.Context())
		if u == nil || u.Role != "admin" {
			http.Error(w, `{"error":"forbidden"}`, http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func User(ctx context.Context) *models.User {
	if u, ok := ctx.Value(userKey).(*models.User); ok {
		return u
	}
	return nil
}

func ExtractToken(r *http.Request) string {
	if authHeader := r.Header.Get("Authorization"); authHeader != "" {
		if strings.HasPrefix(authHeader, "Bearer ") {
			return strings.TrimPrefix(authHeader, "Bearer ")
		}
	}
	if c, err := r.Cookie("session"); err == nil {
		return c.Value
	}
	return ""
}

func hashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
