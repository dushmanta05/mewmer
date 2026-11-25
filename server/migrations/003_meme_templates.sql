CREATE TABLE IF NOT EXISTS meme_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    image_key TEXT NOT NULL,
    thumbnail_key TEXT,
    media_type VARCHAR(20) NOT NULL DEFAULT 'image',
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    byte_size INTEGER NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    tags TEXT[] NOT NULL DEFAULT '{}',
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    memes_count INTEGER NOT NULL DEFAULT 0,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT min_template_tags CHECK (cardinality(tags) >= 3)
);

CREATE INDEX IF NOT EXISTS idx_meme_templates_creator_id ON meme_templates(creator_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_meme_templates_memes_count ON meme_templates(memes_count DESC);
CREATE INDEX IF NOT EXISTS idx_meme_templates_tags ON meme_templates USING gin (tags);
CREATE INDEX IF NOT EXISTS idx_meme_templates_title_trgm ON meme_templates USING gin (title gin_trgm_ops);
