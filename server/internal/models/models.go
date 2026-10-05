package models

import (
	"time"
)

type StickerPack struct {
	ID             string    `json:"id"`
	Title          string    `json:"title"`
	Publisher      string    `json:"publisher"`
	TrayImageURL   string    `json:"trayImageUrl"`
	IsAnimated     bool      `json:"isAnimated"`
	IsPublic       bool      `json:"isPublic"`
	UserID         *string   `json:"userId,omitempty"`
	DownloadsCount int       `json:"downloadsCount"`
	CreatedAt      time.Time `json:"createdAt"`
	Stickers       []Sticker `json:"stickers,omitempty"`
}

type Sticker struct {
	ID         string    `json:"id"`
	PackID     string    `json:"packId"`
	ImageURL   string    `json:"imageUrl"`
	Emojis     []string  `json:"emojis"`
	FileSize   int       `json:"fileSize"`
	IsAnimated bool      `json:"isAnimated"`
	CreatedAt  time.Time `json:"createdAt"`
}

type CreatePackRequest struct {
	ID           string   `json:"id"`
	Title        string   `json:"title"`
	Publisher    string   `json:"publisher"`
	TrayImageURL string   `json:"trayImageUrl"`
	IsAnimated   bool     `json:"isAnimated"`
	IsPublic     *bool    `json:"isPublic,omitempty"`
	StickerURLs  []string `json:"stickerUrls"`
}

type ProcessingJob struct {
	ID         string
	InputPath  string
	OutputPath string
	IsAnimated bool
	ErrChan    chan error
}
