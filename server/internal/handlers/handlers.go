package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/dushmanta05/mewmer/server/internal/config"
	"github.com/dushmanta05/mewmer/server/internal/database"
	"github.com/dushmanta05/mewmer/server/internal/storage"
)

type Handler struct {
	cfg   *config.Config
	db    *database.DB
	store storage.Store
}

func New(cfg *config.Config, db *database.DB, store storage.Store) *Handler {
	return &Handler{
		cfg:   cfg,
		db:    db,
		store: store,
	}
}

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "mewmer-api",
	})
}

func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func errorResponse(w http.ResponseWriter, status int, message string) {
	jsonResponse(w, status, map[string]interface{}{
		"success": false,
		"error":   message,
	})
}
