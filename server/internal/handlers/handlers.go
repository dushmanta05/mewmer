package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/dushmanta05/mewmer/server/internal/config"
	"github.com/dushmanta05/mewmer/server/internal/database"
	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/dushmanta05/mewmer/server/internal/processor"
	"github.com/dushmanta05/mewmer/server/internal/storage"
)

type Handler struct {
	cfg        *config.Config
	db         *database.DB
	workerPool *processor.WorkerPool
	store      storage.Store
}

func New(cfg *config.Config, db *database.DB, wp *processor.WorkerPool, store storage.Store) *Handler {
	return &Handler{
		cfg:        cfg,
		db:         db,
		workerPool: wp,
		store:      store,
	}
}

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "mewmer-api",
	})
}

func (h *Handler) ProcessAnimated(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 15<<20)
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

	tempID := generateID()
	inputExt := filepath.Ext(header.Filename)
	if inputExt == "" {
		inputExt = ".gif"
	}
	inputPath := filepath.Join(h.cfg.StorageDir, fmt.Sprintf("temp_%s%s", tempID, inputExt))
	outputPath := filepath.Join(h.cfg.StorageDir, fmt.Sprintf("stk_%s.webp", tempID))

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
	defer os.Remove(inputPath)

	errChan := make(chan error, 1)
	cropX, _ := strconv.Atoi(r.FormValue("cropX"))
	cropY, _ := strconv.Atoi(r.FormValue("cropY"))
	cropW, _ := strconv.Atoi(r.FormValue("cropW"))
	cropH, _ := strconv.Atoi(r.FormValue("cropH"))
	outW, _ := strconv.Atoi(r.FormValue("outW"))
	outH, _ := strconv.Atoi(r.FormValue("outH"))

	job := models.ProcessingJob{
		ID:         tempID,
		InputPath:  inputPath,
		OutputPath: outputPath,
		IsAnimated: true,
		CropX:      cropX,
		CropY:      cropY,
		CropW:      cropW,
		CropH:      cropH,
		OutW:       outW,
		OutH:       outH,
		ErrChan:    errChan,
	}

	if err := h.workerPool.Enqueue(job); err != nil {
		errorResponse(w, http.StatusServiceUnavailable, err.Error())
		return
	}

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

func generateID() string {
	return strconv.FormatInt(time.Now().UnixNano(), 10)
}
