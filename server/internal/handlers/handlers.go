package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/dushmanta05/mewmer/server/internal/config"
	"github.com/dushmanta05/mewmer/server/internal/database"
	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/dushmanta05/mewmer/server/internal/processor"
)

type Handler struct {
	cfg        *config.Config
	db         *database.DB
	workerPool *processor.WorkerPool
}

func New(cfg *config.Config, db *database.DB, wp *processor.WorkerPool) *Handler {
	return &Handler{
		cfg:        cfg,
		db:         db,
		workerPool: wp,
	}
}

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "mewmer-api",
	})
}

// UploadSticker handles client-generated 512x512 WebP uploads
func (h *Handler) UploadSticker(w http.ResponseWriter, r *http.Request) {
	// Limit upload size to 2MB
	r.Body = http.MaxBytesReader(w, r.Body, 2<<20)
	if err := r.ParseMultipartForm(2 << 20); err != nil {
		errorResponse(w, http.StatusBadRequest, "File too large (max 2MB)")
		return
	}

	file, header, err := r.FormFile("sticker")
	if err != nil {
		errorResponse(w, http.StatusBadRequest, "Missing 'sticker' file in form-data")
		return
	}
	defer file.Close()

	// Ensure uploads directory exists
	if err := os.MkdirAll(h.cfg.StorageDir, 0755); err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to create storage directory")
		return
	}

	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = ".webp"
	}
	filename := fmt.Sprintf("stk_%s%s", uuid.New().String(), ext)
	dstPath := filepath.Join(h.cfg.StorageDir, filename)

	dst, err := os.Create(dstPath)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to save file")
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to write file")
		return
	}

	publicURL := fmt.Sprintf("/uploads/%s", filename)
	jsonResponse(w, http.StatusCreated, map[string]interface{}{
		"success":  true,
		"imageUrl": publicURL,
		"filename": filename,
	})
}

// ProcessAnimated converts video or animated GIF into 512x512 Animated WebP via FFmpeg worker pool
func (h *Handler) ProcessAnimated(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 15<<20) // 15MB limit
	if err := r.ParseMultipartForm(15 << 20); err != nil {
		errorResponse(w, http.StatusBadRequest, "Media file too large (max 15MB)")
		return
	}

	file, header, err := r.FormFile("media")
	if err != nil {
		errorResponse(w, http.StatusBadRequest, "Missing 'media' file")
		return
	}
	defer file.Close()

	tempID := uuid.New().String()
	inputExt := filepath.Ext(header.Filename)
	if inputExt == "" {
		inputExt = ".gif"
	}
	inputPath := filepath.Join(h.cfg.StorageDir, fmt.Sprintf("temp_%s%s", tempID, inputExt))
	outputPath := filepath.Join(h.cfg.StorageDir, fmt.Sprintf("stk_%s.webp", tempID))

	// Save input temporarily
	dst, err := os.Create(inputPath)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Storage write error")
		return
	}
	if _, err := io.Copy(dst, file); err != nil {
		dst.Close()
		errorResponse(w, http.StatusInternalServerError, "Storage copy error")
		return
	}
	dst.Close()
	defer os.Remove(inputPath) // Clean up temp input

	// Enqueue job to worker pool
	errChan := make(chan error, 1)
	job := models.ProcessingJob{
		ID:         tempID,
		InputPath:  inputPath,
		OutputPath: outputPath,
		IsAnimated: true,
		ErrChan:    errChan,
	}

	if err := h.workerPool.Enqueue(job); err != nil {
		errorResponse(w, http.StatusServiceUnavailable, err.Error())
		return
	}

	// Wait for worker completion (with timeout)
	select {
	case err := <-errChan:
		if err != nil {
			errorResponse(w, http.StatusInternalServerError, fmt.Sprintf("Conversion failed: %v", err))
			return
		}
	case <-r.Context().Done():
		return
	}

	outputFilename := filepath.Base(outputPath)
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success":    true,
		"imageUrl":   fmt.Sprintf("/uploads/%s", outputFilename),
		"isAnimated": true,
	})
}

// ListPacks returns public packs
func (h *Handler) ListPacks(w http.ResponseWriter, r *http.Request) {
	search := r.URL.Query().Get("q")
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	limit := 24
	offset := (page - 1) * limit

	packs, err := h.db.GetPublicPacks(r.Context(), search, limit, offset)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to query sticker packs")
		return
	}

	if packs == nil {
		packs = []models.StickerPack{}
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"packs": packs,
		"page":  page,
		"limit": limit,
	})
}

// GetPack returns details of a single pack
func (h *Handler) GetPack(w http.ResponseWriter, r *http.Request) {
	packID := chi.URLParam(r, "id")
	pack, err := h.db.GetPackByID(r.Context(), packID)
	if err != nil {
		errorResponse(w, http.StatusNotFound, "Sticker pack not found")
		return
	}

	jsonResponse(w, http.StatusOK, pack)
}

// CreatePack saves a new sticker pack
func (h *Handler) CreatePack(w http.ResponseWriter, r *http.Request) {
	var req models.CreatePackRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if strings.TrimSpace(req.Title) == "" || strings.TrimSpace(req.Publisher) == "" {
		errorResponse(w, http.StatusBadRequest, "Title and publisher are required")
		return
	}

	if len(req.StickerURLs) == 0 {
		errorResponse(w, http.StatusBadRequest, "Pack must contain at least one sticker")
		return
	}

	packID := strings.ToLower(strings.ReplaceAll(req.Title, " ", "-"))
	if req.ID != "" {
		packID = req.ID
	}
	packID = fmt.Sprintf("%s-%s", packID, uuid.New().String()[:6])

	trayURL := req.TrayImageURL
	if trayURL == "" {
		trayURL = req.StickerURLs[0]
	}

	// Anonymous creations are forced to be public (SEO & prevent orphan content)
	isPublic := true
	if req.IsPublic != nil {
		isPublic = *req.IsPublic
	}

	pack := &models.StickerPack{
		ID:           packID,
		Title:        req.Title,
		Publisher:    req.Publisher,
		TrayImageURL: trayURL,
		IsAnimated:   req.IsAnimated,
		IsPublic:     isPublic,
	}

	if err := h.db.CreatePack(r.Context(), pack, req.StickerURLs); err != nil {
		errorResponse(w, http.StatusInternalServerError, fmt.Sprintf("Failed to save pack: %v", err))
		return
	}

	jsonResponse(w, http.StatusCreated, pack)
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
