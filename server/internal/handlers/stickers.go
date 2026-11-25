package handlers

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/dushmanta05/mewmer/server/internal/media"
	"github.com/dushmanta05/mewmer/server/internal/middleware"
	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const maxStickerFormSize = 1 << 20

func (h *Handler) CreateSticker(w http.ResponseWriter, r *http.Request) {
	packID := chi.URLParam(r, "id")
	user := middleware.User(r.Context())

	if err := r.ParseMultipartForm(maxStickerFormSize); err != nil {
		errorResponse(w, http.StatusBadRequest, "sticker too large")
		return
	}

	isAnimated, _ := strconv.ParseBool(r.FormValue("isAnimated"))
	maxSize := int64(100 << 10)
	if isAnimated {
		maxSize = 500 << 10
	}

	file, _, err := r.FormFile("sticker")
	if err != nil {
		errorResponse(w, http.StatusBadRequest, "sticker file is required")
		return
	}
	defer file.Close()

	info, err := media.ValidateSticker(file, maxSize)
	if err != nil {
		errorResponse(w, http.StatusBadRequest, err.Error())
		return
	}
	if seeker, ok := file.(io.Seeker); ok {
		if _, err := seeker.Seek(0, io.SeekStart); err != nil {
			errorResponse(w, http.StatusInternalServerError, "failed to rewind sticker")
			return
		}
	}

	key := fmt.Sprintf("stickers/%s/%s/%s.webp", user.ID, packID, uuid.New().String())
	if err := h.store.Put(r.Context(), h.cfg.R2PrivateBucket, key, file, info.Size, "image/webp"); err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to store sticker")
		return
	}

	sticker := &models.Sticker{
		PackID:     packID,
		UserID:     user.ID,
		ImageKey:   key,
		Emojis:     parseEmojis(r.FormValue("emojis")),
		ByteSize:   int(info.Size),
		Width:      info.Width,
		Height:     info.Height,
		IsAnimated: isAnimated,
	}

	if err := h.db.CreateSticker(r.Context(), sticker); err != nil {
		_ = h.store.Delete(r.Context(), h.cfg.R2PrivateBucket, key)
		errorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	sticker.ImageKey = h.signedPrivateURL(r.Context(), key)
	jsonResponse(w, http.StatusCreated, sticker)
}

func (h *Handler) DeleteSticker(w http.ResponseWriter, r *http.Request) {
	stickerID := chi.URLParam(r, "id")
	user := middleware.User(r.Context())

	sticker, err := h.db.GetStickerByID(r.Context(), stickerID, user.ID)
	if err != nil {
		errorResponse(w, http.StatusNotFound, "sticker not found")
		return
	}

	ctx := r.Context()
	_ = h.store.Delete(ctx, h.cfg.R2PrivateBucket, sticker.ImageKey)

	if err := h.db.DeleteSticker(ctx, stickerID, user.ID); err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to delete sticker")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func parseEmojis(raw string) []string {
	var emojis []string
	for _, part := range strings.Split(raw, ",") {
		e := strings.TrimSpace(part)
		if e != "" {
			emojis = append(emojis, e)
		}
	}
	if len(emojis) == 0 {
		return []string{"✨"}
	}
	return emojis
}
