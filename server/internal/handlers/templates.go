package handlers

import (
	"fmt"
	"io"
	"net/http"
	"path"
	"regexp"
	"strconv"
	"strings"

	"github.com/dushmanta05/mewmer/server/internal/media"
	"github.com/dushmanta05/mewmer/server/internal/middleware"
	"github.com/dushmanta05/mewmer/server/internal/models"
	"github.com/google/uuid"
)

const maxTemplateSize = 5 << 20

var slugCleaner = regexp.MustCompile(`[^a-z0-9]+`)

func (h *Handler) CreateTemplate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(maxTemplateSize); err != nil {
		errorResponse(w, http.StatusBadRequest, "file too large")
		return
	}

	title := strings.TrimSpace(r.FormValue("title"))
	if title == "" {
		errorResponse(w, http.StatusBadRequest, "title is required")
		return
	}

	tags := parseTags(r.FormValue("tags"))
	if len(tags) < 3 {
		errorResponse(w, http.StatusBadRequest, "at least 3 tags are required")
		return
	}

	slug := strings.TrimSpace(r.FormValue("slug"))
	if slug == "" {
		slug = generateSlug(title)
	}

	existing, _ := h.db.GetTemplateBySlug(r.Context(), slug)
	if existing != nil {
		slug = fmt.Sprintf("%s-%s", slug, uuid.New().String()[:6])
	}

	file, _, err := r.FormFile("media")
	if err != nil {
		errorResponse(w, http.StatusBadRequest, "media file is required")
		return
	}
	defer file.Close()

	info, err := media.ValidateTemplate(file, maxTemplateSize)
	if err != nil {
		errorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	if _, err := file.(io.Seeker).Seek(0, io.SeekStart); err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to rewind file")
		return
	}

	user := middleware.User(r.Context())
	if user == nil {
		errorResponse(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	templateID := uuid.New().String()
	key := fmt.Sprintf("templates/%s/%s%s", templateID, slug, extensionForMime(info.MIME))

	if err := h.store.Put(r.Context(), h.cfg.R2PublicBucket, key, file, info.Size, info.MIME); err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to store media")
		return
	}

	t := &models.Template{
		Slug:        slug,
		Title:       title,
		Description: strings.TrimSpace(r.FormValue("description")),
		ImageKey:    key,
		MediaType:   mediaTypeFromMime(info.MIME),
		Width:       info.Width,
		Height:      info.Height,
		ByteSize:    int(info.Size),
		MimeType:    info.MIME,
		Tags:        tags,
		CreatorID:   user.ID,
	}

	if err := h.db.CreateTemplate(r.Context(), t); err != nil {
		_ = h.store.Delete(r.Context(), h.cfg.R2PublicBucket, key)
		errorResponse(w, http.StatusInternalServerError, "failed to save template")
		return
	}

	t.IsActive = true
	t.ImageKey = h.store.PublicURL(h.cfg.R2PublicBucket, key)
	jsonResponse(w, http.StatusCreated, t)
}

func (h *Handler) ListTemplates(w http.ResponseWriter, r *http.Request) {
	search := r.URL.Query().Get("q")
	tag := r.URL.Query().Get("tag")
	sort := r.URL.Query().Get("sort")
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	limit := 24
	offset := (page - 1) * limit

	templates, err := h.db.GetTemplates(r.Context(), search, tag, sort, limit, offset)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "failed to query templates")
		return
	}

	for i := range templates {
		templates[i].ImageKey = h.store.PublicURL(h.cfg.R2PublicBucket, templates[i].ImageKey)
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"templates": templates,
		"page":      page,
		"limit":     limit,
	})
}

func (h *Handler) GetTemplate(w http.ResponseWriter, r *http.Request) {
	slug := path.Base(r.URL.Path)
	if slug == "" || slug == "templates" {
		errorResponse(w, http.StatusBadRequest, "slug is required")
		return
	}

	t, err := h.db.GetTemplateBySlug(r.Context(), slug)
	if err != nil {
		errorResponse(w, http.StatusNotFound, "template not found")
		return
	}

	t.ImageKey = h.store.PublicURL(h.cfg.R2PublicBucket, t.ImageKey)
	jsonResponse(w, http.StatusOK, t)
}

func parseTags(raw string) []string {
	var tags []string
	for _, part := range strings.Split(raw, ",") {
		t := strings.ToLower(strings.TrimSpace(part))
		if t != "" {
			tags = append(tags, t)
		}
	}
	return tags
}

func generateSlug(title string) string {
	base := strings.ToLower(strings.TrimSpace(title))
	base = slugCleaner.ReplaceAllString(base, "-")
	base = strings.Trim(base, "-")
	if base == "" {
		base = "template"
	}
	return base
}

func extensionForMime(mime string) string {
	switch mime {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	default:
		return ""
	}
}

func mediaTypeFromMime(mime string) string {
	if mime == "image/gif" {
		return "animated_gif"
	}
	return "image"
}
