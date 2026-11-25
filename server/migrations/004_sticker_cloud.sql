BEGIN;

ALTER TABLE IF EXISTS sticker_packs RENAME TO sticker_packs_old;
ALTER TABLE IF EXISTS stickers RENAME TO stickers_old;

CREATE TABLE sticker_packs (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    publisher VARCHAR(100) NOT NULL DEFAULT 'mewmer.com',
    tray_image_key TEXT NOT NULL,
    is_animated BOOLEAN DEFAULT FALSE,
    visibility VARCHAR(20) NOT NULL DEFAULT 'private',
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    downloads_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE stickers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pack_id VARCHAR(64) NOT NULL REFERENCES sticker_packs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_key TEXT NOT NULL,
    emojis TEXT[] DEFAULT ARRAY['✨']::TEXT[],
    byte_size INTEGER NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    is_animated BOOLEAN DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sticker_packs_old' AND column_name = 'tray_image_url'
    ) THEN
        INSERT INTO sticker_packs (id, title, publisher, tray_image_key, is_animated, visibility, user_id, downloads_count, created_at, updated_at)
        SELECT
            id,
            title,
            publisher,
            CASE
                WHEN tray_image_url IS NULL OR tray_image_url = '' THEN 'legacy'
                ELSE split_part(tray_image_url, '/', array_length(string_to_array(tray_image_url, '/'), 1))
            END AS tray_image_key,
            COALESCE(is_animated, FALSE),
            'private',
            user_id,
            COALESCE(downloads_count, 0),
            COALESCE(created_at, NOW()),
            COALESCE(updated_at, NOW())
        FROM sticker_packs_old
        WHERE user_id IS NOT NULL;
    END IF;
END $$;

DROP TABLE IF EXISTS stickers_old;
DROP TABLE IF EXISTS sticker_packs_old;

CREATE INDEX IF NOT EXISTS idx_sticker_packs_user_id ON sticker_packs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sticker_packs_visibility ON sticker_packs(visibility, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stickers_pack_id ON stickers(pack_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_stickers_user_id ON stickers(user_id);

COMMIT;
