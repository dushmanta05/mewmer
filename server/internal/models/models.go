package models

import (
	"encoding/json"
	"time"
)

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

type StickerPack struct {
	ID             string    `json:"id"`
	Title          string    `json:"title"`
	Publisher      string    `json:"publisher"`
	TrayImageKey   string    `json:"trayImageKey"`
	IsAnimated     bool      `json:"isAnimated"`
	Visibility     string    `json:"visibility"`
	UserID         string    `json:"userId"`
	DownloadsCount int       `json:"downloadsCount"`
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
	Stickers       []Sticker `json:"stickers,omitempty"`
}

type Sticker struct {
	ID         string    `json:"id"`
	PackID     string    `json:"packId"`
	UserID     string    `json:"userId"`
	ImageKey   string    `json:"imageKey"`
	Emojis     []string  `json:"emojis"`
	ByteSize   int       `json:"byteSize"`
	Width      int       `json:"width"`
	Height     int       `json:"height"`
	IsAnimated bool      `json:"isAnimated"`
	SortOrder  int       `json:"sortOrder"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
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
