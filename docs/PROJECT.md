# MEWMER — PROJECT SPECIFICATION & ARCHITECTURE

Mewmer (`mewmer.com`) is an open-source, privacy-first web and mobile platform for creating, customizing, and sharing WhatsApp stickers and memes.

---

## 1. Project Vision & Phased Roadmap

### Phase 1: Admin Auth, Templates & Sticker Cloud Sync (Active)

- **Identity & Sessions (Go Backend)**:
  - PostgreSQL-backed users table with roles, display name, unique username/email, and future-ready `links` JSONB.
  - Revocable opaque session tokens; web uses HttpOnly cookies, Flutter uses bearer tokens stored in secure storage.
  - Admin-only seeding; no public registration.

- **Cloud Storage (Cloudflare R2)**:
  - Public R2 bucket for meme templates and public memes.
  - Private R2 bucket for sticker packs and stickers, served via signed URLs.
  - PostgreSQL stores object keys and media metadata only.

- **Meme Templates Domain (`meme_templates`)**:
  - Clean uncaptioned base images/GIFs uploaded by an admin.
  - Tagged with at least 3 descriptive tags.
  - Public catalog ranked by recency and popularity.
  - One-click `Use this Template` pre-loads `/studio?template=:slug`.

- **Web Studio (`frontend/`)**:
  - Client-side captioning and export for anonymous users.
  - Template preloading for public templates.

- **Flutter Mobile App (`app/`)**:
  - Existing local editor stays first-class.
  - Admin login, explicit cloud save for compliant stickers, and restore to owned packs.
  - Native WhatsApp pack injection after downloading media to local files.

### Phase 2: Community Memes, Multi-User Publishing & Curation (Next)

- Public registration, OAuth, or magic-link authentication.
- `memes` table for rendered community memes linked to templates and creators.
- Public meme feed, likes, reports, and moderation tools.
- Creator/staff roles beyond admin/user.

### Phase 3: Moderation, Advanced Discovery & Mobile Polish

- Reporting system and staff moderation dashboard.
- Trending feeds, tag autocomplete, creator profiles.
- Offline sync conflict resolution and iOS/app-store polish.

---

## 2. Technology Stack

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Web Frontend** | Astro 5 + Svelte 5 + Tailwind CSS | Islands architecture, zero-JS page shells, 100/100 Core Web Vitals, SSR/SSG. |
| **Package Manager** | `pnpm` | Mandatory package manager across all frontend tooling. |
| **Backend** | Go (Golang 1.24+) | Chi v5 router, PGX v5 connection pool. |
| **Media Storage** | Cloudflare R2 | Public bucket for templates/public memes; private bucket for stickers/packs. |
| **Media Processing**| Browser Canvas / Flutter | Static and animated stickers generated client-side; backend validates, stores, and serves compliant WebP media. |
| **Database** | PostgreSQL 17 | Relational database with `uuid-ossp` and `pg_trgm` extensions for fast trigram search. |
| **Mobile App** | Flutter (`app/`) | Android & iOS native app for WhatsApp pack injection (`whatsapp_stickers_injector`), local file storage, and Gboard GIF insertion. |

---

## 3. WhatsApp Sticker Technical Specifications

Meta / WhatsApp strictly enforces the following technical rules:

| Specification | Static Stickers | Animated Stickers |
| :--- | :--- | :--- |
| **Dimensions** | Exactly 512 × 512 px | Exactly 512 × 512 px |
| **Aspect Ratio & Padding** | Square canvas, transparent background padding | Square canvas, transparent background padding |
| **Safe Margin** | ~16 px safe margin boundary | ~16 px safe margin boundary |
| **Format** | `image/webp` (with alpha channel) | `image/webp` (animated WebP) |
| **Max File Size** | < 100 KB | < 500 KB |
| **Animation Constraints** | N/A | Continuous loop (`-loop 0`), 8–20 fps, no audio (`-an`) |
| **Tray Icon** | 96 × 96 px PNG or WebP (< 50 KB) | 96 × 96 px PNG or WebP (< 50 KB) |
| **Pack Quantity** | 3 to 30 stickers per pack | 3 to 30 stickers per pack |
| **Pack Mixing** | Never mix static and animated in one pack | Never mix static and animated in one pack |

### Auto-Compression Rules:
- Exports must auto-compress by lowering WebP quality in steps (and for animated, reducing frame rate / frame count) until under the size limit.
- Never alter the 512×512 canvas dimensions to save bytes.
- If the limit cannot be met, display a clear user error asking to pick a shorter or simpler GIF.

### Distribution & Sharing Mechanisms:
1. **Single Sticker Direct Chat Share (Web & Mobile)**:
   - Exported as 512×512 `image/webp`.
   - Shared directly into any WhatsApp chat via `navigator.share({ files: [file] })` or desktop clipboard copy.
   - Senders and recipients can tap the sticker in the chat and tap **"Add to Favorites" (⭐)** to keep and reuse it.
2. **Sticker Pack Injection (Mobile App only)**:
   - Requires 3 to 30 stickers and a 96×96 tray icon.
   - Injected into WhatsApp's keyboard drawer tray via the native ContentProvider mechanism (`whatsapp_stickers_injector`).
   - Web browsers cannot directly inject packs into WhatsApp's keyboard drawer due to OS security boundaries.

### Metadata & Branding:
- Publisher name format: `<creator> · mewmer.com` (attributing the creator while promoting the platform).
- Never use the trademark "WhatsApp" in the app name or listing name (use only in descriptions).

---

## 4. Keyboard GIF Integration (Mobile)

- **Source**: Android Commit Content API via Flutter `TextField.contentInsertionConfiguration`.
- **Supported Keyboards**: Gboard, Samsung Keyboard, SwiftKey.
- **Accepted MIME Types**: `image/gif`, `image/webp`, `image/png`, `image/jpeg`.
- **Zero Third-Party Search API**: No Tenor, Giphy, or Klipy API keys or proxies required.
- **Privacy Assurance**: The user's search queries stay inside their keyboard application; Mewmer never sees or logs search terms.
- **Handling**: Temporary URI read permission requested, file copied immediately to app cache folder, then permission released.
- **Canvas Placement**: Inserted as a scalable, rotatable layer inside 512×512 canvas with transparent padding. Animation preserved for GIFs and animated WebPs.
- **Fallback**: Option to "Make static sticker (pick a frame)". On iOS or web, fall back to file picker and clipboard paste.

---

## 5. Editor & Studio Specifications

- **Dual-Mode Studio**:
  - **Meme Studio Mode**: Supports natural image dimensions and arbitrary aspect ratios (`Original (Free)`, `1:1 (Square)`, `4:3 (Standard)`, `16:9 (Widescreen)`, `9:16 (Story/Reel)`, `3:4 (Portrait)`). Exports high-resolution WebP, JPG/JPEG, or PNG.
  - **WhatsApp Sticker Mode**: Strictly enforces 512×512 square canvas with transparent padding, WebP format, <100 KB static or <500 KB animated.
- **Layers System**:
  - Base image or animated GIF layer (draggable within crop frame, pinch-to-zoom / scroll pan, rotation, and aspect ratio clamping).
  - Multi-layer caption text layers: Unlimited captions, draggable anywhere on canvas, circular `RotateCw` handle for direct rotation, corner `Maximize2` handle for scaling, font family selector (`Impact`, `Bebas Neue`, `Poppins`, `Inter`, `Caveat`), stroke outline, text shadow, and color pickers.
  - Watermark branding layer: Movable, non-deletable `mewmer.com` brand mark. Clamped within `[4%, 96%]` of cropped area, draggable on canvas, customizable color, opacity slider, and position presets.
- **Client-Side Generation**: 100% rendered locally on device/browser via HTML5 Canvas. Anonymous users can generate, caption, and export memes without server processing.

---

## 6. Privacy, Roles & Publishing Rules

- **Anonymous Users**:
  - Can freely crop, customize, rotate captions, and export/download (WebP, JPG, PNG) locally with zero server retention.
  - No server storage or account required for private creation.
  - Cannot upload templates, save stickers to the cloud, or publish community content.
- **Authenticated Users & Roles**:
  - Roles: `user` (default), `admin`.
  - `admin` can upload public meme templates and publish sticker packs.
  - Future roles `creator` and `staff` are reserved in the schema but not enabled yet.
- **Publishing Requirements**:
  - **Template Submission**: Must be logged in as admin, provide template name, clean uncaptioned media, and **at least 3 tags**.
  - **Sticker Cloud Save**: Must be logged in, owned pack, compliant WebP bytes.
  - **Creator Attribution**: Every published template and pack is attributed to its owner.
- **Data Deletion**: Complete account and associated content deletion supported upon user request.

---

## 7. Database Schema (`mewmer`)

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 1. Users & Roles Table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(64) UNIQUE NOT NULL,
  display_name VARCHAR(100) NOT NULL,
  password_hash TEXT NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'user', -- user | admin (creator | staff reserved)
  avatar_key TEXT,
  bio TEXT,
  links JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Sessions Table
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  last_used_at TIMESTAMP WITH TIME ZONE
);

-- 3. Meme Templates Table (Clean uncaptioned bases)
CREATE TABLE meme_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(100) UNIQUE NOT NULL,
  title VARCHAR(150) NOT NULL,
  description TEXT,
  image_key TEXT NOT NULL,
  thumbnail_key TEXT,
  media_type VARCHAR(20) NOT NULL DEFAULT 'image', -- image | animated_gif
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  byte_size INTEGER NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  tags TEXT[] NOT NULL DEFAULT '{}',
  creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  memes_count INTEGER NOT NULL DEFAULT 0,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT min_template_tags CHECK (cardinality(tags) >= 3)
);

-- 4. WhatsApp Sticker Packs Table
CREATE TABLE sticker_packs (
  id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(100) NOT NULL,
  publisher VARCHAR(100) NOT NULL DEFAULT 'mewmer.com',
  tray_image_key TEXT NOT NULL,
  is_animated BOOLEAN DEFAULT FALSE,
  visibility VARCHAR(20) NOT NULL DEFAULT 'private', -- private | unlisted | public
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  downloads_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Individual WhatsApp Stickers Table (512x512 WebP)
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
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. Generated Community Memes Table (Phase 2)
CREATE TABLE memes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(100) UNIQUE NOT NULL,
  template_id UUID REFERENCES meme_templates(id) ON DELETE SET NULL,
  creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  caption_summary TEXT,
  layers_data JSONB NOT NULL DEFAULT '[]',
  image_key TEXT NOT NULL,
  media_type VARCHAR(20) NOT NULL DEFAULT 'image',
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  byte_size INTEGER NOT NULL,
  tags TEXT[] NOT NULL,
  is_public BOOLEAN NOT NULL DEFAULT TRUE,
  views_count INTEGER NOT NULL DEFAULT 0,
  shares_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT min_meme_tags CHECK (cardinality(tags) >= 3)
);

-- 7. Content Moderation Reports Table (Phase 2)
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type VARCHAR(20) NOT NULL, -- meme | template | sticker | pack
  target_id VARCHAR(64) NOT NULL,
  reason TEXT,
  reporter_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for Fast Search, Tag Overlaps & Ranking
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_token_hash ON sessions(token_hash);
CREATE INDEX idx_meme_templates_creator_id ON meme_templates(creator_id, created_at DESC);
CREATE INDEX idx_meme_templates_memes_count ON meme_templates(memes_count DESC);
CREATE INDEX idx_meme_templates_tags ON meme_templates USING gin (tags);
CREATE INDEX idx_meme_templates_title_trgm ON meme_templates USING gin (title gin_trgm_ops);
CREATE INDEX idx_memes_template_id ON memes(template_id, created_at DESC);
CREATE INDEX idx_memes_creator_id ON memes(creator_id, created_at DESC);
CREATE INDEX idx_memes_tags ON memes USING gin (tags);
CREATE INDEX idx_memes_public ON memes(is_public, created_at DESC);
CREATE INDEX idx_sticker_packs_user_id ON sticker_packs(user_id, created_at DESC);
CREATE INDEX idx_sticker_packs_visibility ON sticker_packs(visibility, created_at DESC);
CREATE INDEX idx_sticker_packs_title_trgm ON sticker_packs USING gin (title gin_trgm_ops);
CREATE INDEX idx_stickers_pack_id ON stickers(pack_id, sort_order);
CREATE INDEX idx_stickers_user_id ON stickers(user_id);
```

---

## 8. Backend API Endpoints

### Auth & User Endpoints
- `POST /api/v1/auth/login` — Authenticate and receive session cookie / token.
- `POST /api/v1/auth/logout` — Revoke active session.
- `GET /api/v1/auth/me` — Retrieve current authenticated user profile and role.

### Meme Templates Endpoints
- `GET /api/v1/templates?q=&tag=&sort=popular|newest&page=&limit=` — List public templates.
- `GET /api/v1/templates/{slug}` — Retrieve template details.
- `POST /api/v1/templates` — (Admin only) Upload clean uncaptioned base template with title and ≥ 3 tags.

### Community Memes Endpoints (Phase 2)
- `GET /api/v1/memes?q=&tag=&template_id=&sort=trending|newest&page=&limit=` — Community memes feed.
- `GET /api/v1/memes/{slug}` — Single published meme.
- `POST /api/v1/memes` — (Auth required) Publish rendered meme.

### WhatsApp Sticker Packs Endpoints (Authenticated)
- `GET /api/v1/me/packs` — List owned packs.
- `GET /api/v1/packs/{id}` — Pack details and sticker list (owner or public).
- `POST /api/v1/packs` — Create new owned sticker pack with 96×96 tray icon.
- `POST /api/v1/packs/{id}/stickers` — Upload client-rendered 512×512 WebP sticker into an owned pack.

### System & Moderation Endpoints
- `GET /health` — Service healthcheck.
- `POST /api/v1/reports` — Report inappropriate content (Phase 2).
- `GET /uploads/*` or `/media/*` — Serve or proxy media; private media requires auth or signed URL.

---

## 9. Template Submission & Studio Workflow Architecture

1. **Admin Upload**:
   - Admin logs into the web app and uploads a clean uncaptioned image/GIF via `POST /api/v1/templates`.
   - Media is validated, stored in public R2, and metadata saved to `meme_templates`.
2. **Public Catalog (`/templates`)**:
   - Lists public templates sorted by recency and popularity.
   - Each card features **"Use this Template"**, routing to `/studio?template=:slug`.
3. **Studio Flow**:
   - The studio loads the clean base image and lets anonymous users caption and export locally.
   - No account is required for local creation.
4. **Sticker Cloud Save (Flutter)**:
   - Admin logs in, generates a compliant sticker, and explicitly saves it to an owned cloud pack.
   - Media is validated and stored in private R2; the pack can later be retrieved and injected into WhatsApp.

## 10. Production Deployment

See `docs/PRODUCTION.md` for step-by-step instructions on provisioning a VPS, installing Go and PostgreSQL, configuring Cloudflare R2, running migrations, creating the first admin, and serving the API behind Nginx with HTTPS.
