package models

import (
	"encoding/json"
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
	CropX      int
	CropY      int
	CropW      int
	CropH      int
	OutW       int
	OutH       int
	ErrChan    chan error
}

type User struct {
	ID           string          `json:"id"`
	Email        string          `json:"email"`
	Username     string          `json:"username"`
	DisplayName  string          `json:"displayName"`
	PasswordHash string          `json:"-"`
	Role         string          `json:"role"`
	AvatarKey    *string         `json:"avatarKey,omitempty"`
	Bio          *string         `json:"bio,omitempty"`
	Links        json.RawMessage `json:"links"`
	CreatedAt    time.Time       `json:"createdAt"`
	UpdatedAt    time.Time       `json:"updatedAt"`
}

type Session struct {
	ID         string     `json:"id"`
	UserID     string     `json:"userId"`
	TokenHash  string     `json:"-"`
	CreatedAt  time.Time  `json:"createdAt"`
	ExpiresAt  time.Time  `json:"expiresAt"`
	LastUsedAt *time.Time `json:"lastUsedAt,omitempty"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}
