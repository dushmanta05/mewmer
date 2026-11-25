package media

import (
	"bytes"
	"errors"
	"image"
	"io"
	"strings"

	"golang.org/x/image/webp"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
)

type Info struct {
	MIME       string
	Width      int
	Height     int
	Size       int64
	IsAnimated bool
}

func ValidateTemplate(r io.Reader, maxBytes int64) (*Info, error) {
	data, err := readLimited(r, maxBytes)
	if err != nil {
		return nil, err
	}

	img, format, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	allowed := map[string]bool{"jpeg": true, "png": true, "gif": true, "webp": true}
	if !allowed[format] {
		return nil, errors.New("unsupported image format")
	}

	return &Info{
		MIME:   formatToMIME(format),
		Width:  img.Bounds().Dx(),
		Height: img.Bounds().Dy(),
		Size:   int64(len(data)),
	}, nil
}

func ValidateSticker(r io.Reader, maxBytes int64) (*Info, error) {
	data, err := readLimited(r, maxBytes)
	if err != nil {
		return nil, err
	}

	cfg, err := webp.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, errors.New("invalid webp file")
	}

	if cfg.Width != 512 || cfg.Height != 512 {
		return nil, errors.New("sticker must be 512x512")
	}

	return &Info{
		MIME:   "image/webp",
		Width:  cfg.Width,
		Height: cfg.Height,
		Size:   int64(len(data)),
	}, nil
}

func readLimited(r io.Reader, maxBytes int64) ([]byte, error) {
	data, err := io.ReadAll(io.LimitReader(r, maxBytes+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > maxBytes {
		return nil, errors.New("file too large")
	}
	return data, nil
}

func formatToMIME(format string) string {
	switch format {
	case "jpeg":
		return "image/jpeg"
	case "png":
		return "image/png"
	case "gif":
		return "image/gif"
	case "webp":
		return "image/webp"
	default:
		return "application/octet-stream"
	}
}

func SanitizeKeySegment(s string) string {
	return strings.ReplaceAll(strings.ToLower(strings.TrimSpace(s)), " ", "-")
}
