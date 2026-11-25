package models

import "time"

type Template struct {
	ID           string    `json:"id"`
	Slug         string    `json:"slug"`
	Title        string    `json:"title"`
	Description  string    `json:"description,omitempty"`
	ImageKey     string    `json:"imageKey"`
	ThumbnailKey string    `json:"thumbnailKey,omitempty"`
	MediaType    string    `json:"mediaType"`
	Width        int       `json:"width"`
	Height       int       `json:"height"`
	ByteSize     int       `json:"byteSize"`
	MimeType     string    `json:"mimeType"`
	Tags         []string  `json:"tags"`
	CreatorID    string    `json:"creatorId"`
	MemesCount   int       `json:"memesCount"`
	IsVerified   bool      `json:"isVerified"`
	IsActive     bool      `json:"isActive"`
	CreatedAt    time.Time `json:"createdAt"`
	UpdatedAt    time.Time `json:"updatedAt"`
}
