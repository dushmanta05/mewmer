package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/dushmanta05/mewmer/server/internal/auth"
	"github.com/dushmanta05/mewmer/server/internal/config"
	"github.com/dushmanta05/mewmer/server/internal/database"
	"github.com/dushmanta05/mewmer/server/internal/middleware"
	"github.com/dushmanta05/mewmer/server/internal/models"
)

type AuthHandler struct {
	db     *database.DB
	hasher *auth.PasswordHasher
	cfg    *config.Config
}

func NewAuthHandler(db *database.DB, cfg *config.Config) *AuthHandler {
	return &AuthHandler{
		db:     db,
		hasher: auth.NewPasswordHasher(),
		cfg:    cfg,
	}
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req models.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, http.StatusBadRequest, "invalid json")
		return
	}

	user, err := h.db.GetUserByEmail(r.Context(), req.Email)
	if err != nil {
		errorResponse(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	ok, err := h.hasher.Verify(req.Password, user.PasswordHash)
	if err != nil || !ok {
		errorResponse(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	raw, hash, err := auth.GenerateToken()
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "session error")
		return
	}

	expiresAt := time.Now().UTC().Add(h.cfg.SessionTTL)
	if _, err := h.db.CreateSession(r.Context(), user.ID, hash, expiresAt); err != nil {
		errorResponse(w, http.StatusInternalServerError, "session error")
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    raw,
		Path:     "/",
		Expires:  expiresAt,
		HttpOnly: true,
		Secure:   h.cfg.SecureCookie,
		SameSite: http.SameSiteLaxMode,
		Domain:   h.cfg.CookieDomain,
	})

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"user":  user,
		"token": raw,
	})
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	if token := middleware.ExtractToken(r); token != "" {
		_ = h.db.DeleteSession(r.Context(), auth.HashToken(token))
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    "",
		Path:     "/",
		MaxAge:   -1,
		HttpOnly: true,
		Secure:   h.cfg.SecureCookie,
		SameSite: http.SameSiteLaxMode,
		Domain:   h.cfg.CookieDomain,
	})

	jsonResponse(w, http.StatusOK, map[string]string{"status": "logged out"})
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	user := middleware.User(r.Context())
	if user == nil {
		errorResponse(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	jsonResponse(w, http.StatusOK, user)
}
