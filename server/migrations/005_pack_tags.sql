ALTER TABLE sticker_packs
    ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_sticker_packs_tags ON sticker_packs USING gin (tags);
