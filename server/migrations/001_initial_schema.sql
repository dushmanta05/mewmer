-- Enable extensions for UUID and fast search
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sticker Packs table
CREATE TABLE IF NOT EXISTS sticker_packs (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    publisher VARCHAR(100) NOT NULL,
    tray_image_url TEXT NOT NULL,
    is_animated BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT TRUE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    downloads_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Stickers table
CREATE TABLE IF NOT EXISTS stickers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pack_id VARCHAR(64) REFERENCES sticker_packs(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    emojis TEXT[] DEFAULT ARRAY['✨']::TEXT[],
    file_size INTEGER DEFAULT 0,
    is_animated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for lightning fast queries and search
CREATE INDEX IF NOT EXISTS idx_sticker_packs_public ON sticker_packs(is_public);
CREATE INDEX IF NOT EXISTS idx_sticker_packs_downloads ON sticker_packs(downloads_count DESC);
CREATE INDEX IF NOT EXISTS idx_stickers_pack_id ON stickers(pack_id);

-- Full-text fuzzy search indexes
CREATE INDEX IF NOT EXISTS idx_sticker_packs_title_trgm ON sticker_packs USING gin (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_sticker_packs_publisher_trgm ON sticker_packs USING gin (publisher gin_trgm_ops);
