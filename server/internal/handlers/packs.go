package handlers

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/dushmanta05/mewmer/server/internal/media"
	"github.com/dushmanta05/mewmer/server/internal/middleware"
	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const maxTraySize = 50 << 10

func (h *Handler) ListMyPacks(w http.ResponseWriter, r *http.Request) {
	user := middleware.User(r.Context())
	search := r.URL.Query().Get("q")
	page, limit := parsePagination(r, 10)
	offset := (page - 1) * limit

	packs, err := h.db.GetPacksByUser(r.Context(), user.ID, search, limit, offset)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to query packs")
		return
	}

	total, err := h.db.CountPacksByUser(r.Context(), user.ID, search)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to count packs")
		return
	}

	for i := range packs {
		packs[i].TrayImageKey = h.signedPrivateURL(r.Context(), packs[i].TrayImageKey)
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"packs": packs,
		"page":  page,
		"limit": limit,
		"total": total,
	})
}

func (h *Handler) CreatePack(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(maxTraySize); err != nil {
		errorResponse(w, http.StatusBadRequest, "tray icon too large")
		return
	}

	title := strings.TrimSpace(r.FormValue("title"))
	if title == "" {
		errorResponse(w, http.StatusBadRequest, "title is required")
		return
	}

	visibility := normalizeVisibility(r.FormValue("visibility"))
	tags := parseTags(r.FormValue("tags"))
	isAnimated, _ := strconv.ParseBool(r.FormValue("isAnimated"))

	file, _, err := r.FormFile("tray")
	if err != nil {
		errorResponse(w, http.StatusBadRequest, "tray icon is required")
		return
	}
	defer file.Close()

	info, err := media.ValidateTray(file, maxTraySize)
	if err != nil {
		errorResponse(w, http.StatusBadRequest, err.Error())
		return
	}
	if seeker, ok := file.(io.Seeker); ok {
		if _, err := seeker.Seek(0, io.SeekStart); err != nil {
			errorResponse(w, http.StatusInternalServerError, "failed to rewind tray icon")
			return
		}
	}

	user := middleware.User(r.Context())
	packID := uuid.New().String()
	key := fmt.Sprintf("packs/%s/tray%s", packID, extensionForMime(info.MIME))

	if err := h.store.Put(r.Context(), h.cfg.R2PrivateBucket, key, file, info.Size, info.MIME); err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to store tray icon")
		return
	}

	pack := &models.StickerPack{
		ID:           packID,
		Title:        title,
		Publisher:    fmt.Sprintf("%s · mewmer.com", user.DisplayName),
		TrayImageKey: key,
		IsAnimated:   isAnimated,
		Visibility:   visibility,
		Tags:         tags,
		UserID:       user.ID,
	}

	if err := h.db.CreatePack(r.Context(), pack); err != nil {
		_ = h.store.Delete(r.Context(), h.cfg.R2PrivateBucket, key)
		errorResponse(w, http.StatusInternalServerError, "failed to save pack")
		return
	}

	pack.TrayImageKey = h.signedPrivateURL(r.Context(), key)
	jsonResponse(w, http.StatusCreated, pack)
}

func (h *Handler) GetPack(w http.ResponseWriter, r *http.Request) {
	packID := chi.URLParam(r, "id")
	user := middleware.User(r.Context())

	pack, err := h.db.GetPackByIDWithStickers(r.Context(), packID, user.ID)
	if err != nil {
		errorResponse(w, http.StatusNotFound, "pack not found")
		return
	}

	pack.TrayImageKey = h.signedPrivateURL(r.Context(), pack.TrayImageKey)
	for i := range pack.Stickers {
		pack.Stickers[i].ImageKey = h.signedPrivateURL(r.Context(), pack.Stickers[i].ImageKey)
	}

	jsonResponse(w, http.StatusOK, pack)
}

func (h *Handler) DeletePack(w http.ResponseWriter, r *http.Request) {
	packID := chi.URLParam(r, "id")
	user := middleware.User(r.Context())

	pack, err := h.db.GetPackByIDWithStickers(r.Context(), packID, user.ID)
	if err != nil {
		errorResponse(w, http.StatusNotFound, "pack not found")
		return
	}

	ctx := r.Context()
	_ = h.store.Delete(ctx, h.cfg.R2PrivateBucket, pack.TrayImageKey)
	for _, s := range pack.Stickers {
		_ = h.store.Delete(ctx, h.cfg.R2PrivateBucket, s.ImageKey)
	}

	if err := h.db.DeletePack(ctx, packID, user.ID); err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to delete pack")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (h *Handler) signedPrivateURL(ctx context.Context, key string) string {
	url, err := h.store.SignedURL(ctx, h.cfg.R2PrivateBucket, key, 15*time.Minute)
	if err != nil {
		return ""
	}
	return url
}

func normalizeVisibility(v string) string {
	switch v {
	case "private", "unlisted", "public":
		return v
	default:
		return "private"
	}
}

func parsePagination(r *http.Request, defaultLimit int) (page, limit int) {
	page, _ = strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	limit, _ = strconv.Atoi(r.URL.Query().Get("limit"))
	if limit < 1 {
		limit = defaultLimit
	}
	if limit > 50 {
		limit = 50
	}
	return page, limit
}
