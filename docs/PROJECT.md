# MEWMER — PROJECT SPECIFICATION & ARCHITECTURE

Mewmer (`mewmer.com`) is an open-source, privacy-first web and mobile platform for creating, customizing, and sharing WhatsApp stickers and memes.

---

## 1. Project Vision & Phased Roadmap

### Phase 1: High-Performance Sticker Studio & Native Pack Export (Active)
- **Web App (`frontend/`)**:
  - 512×512 sticker studio running 100% client-side on HTML5 Canvas.
  - Transparent checkerboard preview, real-time caption dragging, custom fonts, stroke outline, zoom, and safe margin guides (~16 px safe boundary).
  - Movable, clamped "mewmer.com" brand mark layer (default ON, rotatable, scalable, clamped within canvas, togglable in settings).
  - Single sticker direct sharing to WhatsApp chats via Web Share API (`image/webp`) or clipboard (`image/png`).
  - High-converting, SEO-optimized marketing landing page and public pack discovery gallery.
- **Go Backend (`server/`)**:
  - High-throughput Go server (Chi + PGX + PostgreSQL 17).
  - Bounded FFmpeg worker pool for transcoding animated GIFs and videos into WhatsApp-compliant animated WebP (< 500 KB, looping, no audio).
  - REST API for pack listings, search, and sticker uploads with server-side validation.
- **Flutter Mobile App (`app/`)**:
  - Native WhatsApp sticker pack injection into the WhatsApp keyboard drawer (3–30 stickers + 96×96 tray icon) via `whatsapp_stickers_injector`.
  - Android Keyboard Content API (`TextField.contentInsertionConfiguration`) for directly inserting GIFs and stickers from Gboard, Samsung Keyboard, and SwiftKey without any third-party GIF search API (no Tenor/Giphy dependency; user queries stay private).
  - Auto-compress export for static (< 100 KB) and animated (< 500 KB) stickers.

### Phase 2: Cloud Accounts, Meme Templates & Community Publishing (Next)
- **Authentication & User Profiles**:
  - Email Magic Link / OAuth / session-based authentication in Go backend.
  - Role-based permissions (`user`, `creator`, `staff`, `admin`).
  - Anonymous users: Can freely crop, customize, rotate captions, and export/download (WebP, JPG, PNG) locally with zero server retention and no login required.
  - Logged-in users: Can publish memes to the public community feed and submit clean uncaptioned base images as community templates.
- **Meme Templates Domain (`meme_templates`)**:
  - Clean uncaptioned base image or animated GIF stored as a template.
  - Tagged with at least 3 descriptive tags for discovery and SEO.
  - Tracks `memes_count` (number of memes generated from this template).
  - Dedicated `/templates` directory page ranked by popularity (`memes_count` DESC), recency, and tags.
  - Template detail page (`/templates/:slug`) showcases the clean base template alongside a gallery of all generated memes created under it.
  - Studio integration: One-click "Use this Template" pre-loads the clean base into `/studio?template=:slug`.
- **Community Memes Domain (`memes`)**:
  - Published memes generated from a template (or custom base) linked to `template_id` and creator `user_id`.
  - Publishing requirements: Authenticated user, caption summary/title, and **at least 3 descriptive tags** (`cardinality(tags) >= 3`).
  - Stores rich multi-layer text coordinates, rotation, scaling, fonts, and colors in `layers_data` (JSONB) for future re-editing.
  - Permanent public URLs (`/memes/:slug`) with OpenGraph cards and creator attribution.
- **WhatsApp Sticker Packs Domain (`sticker_packs` & `stickers`) — Mobile Only**:
  - Kept strictly distinct and isolated from arbitrary aspect-ratio community memes.
  - **Platform Boundary**: Stickers and sticker packs are **strictly a native mobile feature (`app/`) and are NOT accessed or browsed on the web**. The web platform is exclusively focused on the Meme Studio, Templates, and Community Memes.
  - WhatsApp technical constraints strictly enforced: exactly 512×512 square WebP, static < 100 KB, animated < 500 KB.
  - Packs require 3 to 30 stickers + 96×96 tray icon for native keyboard drawer injection via Flutter mobile app (`app/`).
  - Every sticker pack and sticker is strictly owned by an authenticated user (`user_id UUID NOT NULL REFERENCES users(id)`).

### Phase 3: Moderation, Community Curation & Mobile Cloud Sync
- Community reporting system (`reports` table) and staff moderation dashboard for reported memes and sticker packs.
- Flutter mobile app cloud sync: Fetch sticker packs from `GET /api/v1/packs/:id` and inject directly into WhatsApp tray.
- Advanced tag autocomplete, trending memes feed, and creator profile showcases.

---

## 2. Technology Stack

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Web Frontend** | Astro 5 + Svelte 5 + Tailwind CSS | Islands architecture, zero-JS page shells, 100/100 Core Web Vitals, SSR/SSG. |
| **Package Manager** | `pnpm` | Mandatory package manager across all frontend tooling. |
| **Backend** | Go (Golang 1.23+) | Chi v5 router, PGX v5 connection pool, native bounded Goroutine worker pool. |
| **Media Processing**| Browser Canvas + Native FFmpeg | Static stickers generated client-side via HTML5 Canvas; animated GIF/video transcoding handled by Go FFmpeg worker pool. |
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
  - Cannot publish to public community gallery or submit new community templates.
- **Authenticated Users & Roles**:
  - Roles: `user` (default), `creator` (verified uploader), `staff` (moderator), `admin`.
  - Can submit clean uncaptioned images/GIFs as community templates.
  - Can publish generated memes under templates to the public community feed.
- **Publishing Requirements**:
  - **Meme Publishing**: Must be logged in, provide a meme title/caption summary, and **at least 3 descriptive tags** (`cardinality(tags) >= 3`).
  - **Template Submission**: Must be logged in, provide template name, clean uncaptioned media, and **at least 3 tags**.
  - **Creator Attribution**: Every published meme and template is attributed to `creator_id` (`users.id`).
- **Data Deletion**: Complete account and associated meme/pack deletion supported upon user request.

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
  password_hash TEXT,
  role VARCHAR(20) NOT NULL DEFAULT 'user', -- user | creator | staff | admin
  avatar_url TEXT,
  bio TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Meme Templates Table (Clean uncaptioned bases)
CREATE TABLE meme_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(100) UNIQUE NOT NULL,
  title VARCHAR(150) NOT NULL,
  description TEXT,
  image_url TEXT NOT NULL,
  thumbnail_url TEXT,
  media_type VARCHAR(20) NOT NULL DEFAULT 'image', -- image | animated_gif
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  aspect_ratio VARCHAR(20) DEFAULT 'original',
  tags TEXT[] NOT NULL DEFAULT '{}',
  creator_id UUID REFERENCES users(id) ON DELETE SET NULL,
  memes_count INTEGER NOT NULL DEFAULT 0,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT min_template_tags CHECK (cardinality(tags) >= 3)
);

-- 3. Generated Community Memes Table
CREATE TABLE memes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(100) UNIQUE NOT NULL,
  template_id UUID REFERENCES meme_templates(id) ON DELETE SET NULL,
  creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  caption_summary TEXT,
  layers_data JSONB NOT NULL DEFAULT '[]', -- caption layers: text, x, y, scale, rotation, font, colors
  image_url TEXT NOT NULL,
  media_type VARCHAR(20) NOT NULL DEFAULT 'image', -- image | animated_gif
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  tags TEXT[] NOT NULL,
  is_public BOOLEAN NOT NULL DEFAULT TRUE,
  views_count INTEGER NOT NULL DEFAULT 0,
  shares_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT min_meme_tags CHECK (cardinality(tags) >= 3)
);

-- 4. WhatsApp Sticker Packs Table (Mobile Only - Not accessible on Web)
CREATE TABLE sticker_packs (
  id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(100) NOT NULL,
  publisher VARCHAR(100) NOT NULL DEFAULT 'mewmer.com',
  tray_image_url TEXT NOT NULL,
  is_animated BOOLEAN DEFAULT FALSE,
  is_public BOOLEAN DEFAULT TRUE,
  visibility VARCHAR(20) NOT NULL DEFAULT 'public', -- private | unlisted | public
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  downloads_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- 5. Individual WhatsApp Stickers Table (512x512 WebP - Mobile Only)
CREATE TABLE stickers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_id VARCHAR(64) NOT NULL REFERENCES sticker_packs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  emojis TEXT[] DEFAULT ARRAY['✨']::TEXT[],
  file_size INTEGER NOT NULL,
  is_animated BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- 6. Content Moderation Reports Table
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
CREATE INDEX idx_meme_templates_memes_count ON meme_templates(memes_count DESC);
CREATE INDEX idx_meme_templates_tags ON meme_templates USING gin (tags);
CREATE INDEX idx_meme_templates_title_trgm ON meme_templates USING gin (title gin_trgm_ops);
CREATE INDEX idx_memes_template_id ON memes(template_id, created_at DESC);
CREATE INDEX idx_memes_creator_id ON memes(creator_id, created_at DESC);
CREATE INDEX idx_memes_tags ON memes USING gin (tags);
CREATE INDEX idx_memes_public ON memes(is_public, created_at DESC);
CREATE INDEX idx_sticker_packs_public ON sticker_packs(is_public, created_at DESC);
CREATE INDEX idx_sticker_packs_title_trgm ON sticker_packs USING gin (title gin_trgm_ops);
CREATE INDEX idx_stickers_pack_id ON stickers(pack_id);
```

---

## 8. Backend API Endpoints

### Auth & User Endpoints
- `POST /api/v1/auth/register` — Register new user account
- `POST /api/v1/auth/login` — Authenticate and receive session token / cookie
- `POST /api/v1/auth/logout` — Revoke active session
- `GET /api/v1/auth/me` — Retrieve current authenticated user profile and roles

### Meme Templates Endpoints
- `GET /api/v1/templates?q=&tag=&sort=popular|newest&page=&limit=` — List uncaptioned templates (ranked by `memes_count` or recency)
- `GET /api/v1/templates/{slug}` — Retrieve template details and top/recent memes generated under this template
- `GET /api/v1/templates/{slug}/memes?page=&limit=` — Paginated list of generated memes for this template
- `POST /api/v1/templates` — (Auth required) Upload clean uncaptioned base template with title and ≥ 3 tags

### Community Memes Endpoints
- `GET /api/v1/memes?q=&tag=&template_id=&sort=trending|newest&page=&limit=` — Community memes feed with tag and search filters
- `GET /api/v1/memes/{slug}` — Retrieve single published meme, creator attribution, parent template link, and share metadata
- `POST /api/v1/memes` — (Auth required) Publish rendered meme with caption summary, `layers_data` JSONB, and ≥ 3 tags; automatically increments parent template `memes_count`

### WhatsApp Sticker Packs Endpoints (Isolated)
- `GET /api/v1/packs?q=&page=&limit=` — List public WhatsApp sticker packs
- `GET /api/v1/packs/{id}` — Pack details and sticker list (3–30 stickers)
- `POST /api/v1/packs` — (Auth required) Create new sticker pack with 96×96 tray icon
- `POST /api/v1/stickers/upload` — Upload client-rendered 512×512 WebP sticker (< 100 KB)
- `POST /api/v1/stickers/process-animated` — Transcode GIF/video to animated WebP via FFmpeg worker pool (< 500 KB)

### System & Moderation Endpoints
- `GET /health` — Service healthcheck
- `POST /api/v1/reports` — Report inappropriate meme, template, or pack
- `GET /uploads/*` — Serve public media assets

---

## 9. Template Submission & Studio Workflow Architecture

### Studio Ingestion vs Dedicated Template Page:
1. **In-Studio Submission**:
   - When a user imports an image/GIF into `/studio`, if they have not added captions, an action button **"Save as Community Template"** is presented.
   - For authenticated users, clicking this opens a submission modal requesting:
     - Template Name (e.g., "Distracted Boyfriend")
     - At least 3 tags (e.g., `funny`, `relationship`, `choice`)
     - Category / Description (optional)
   - The uncaptioned original media is saved via `POST /api/v1/templates`.
2. **Dedicated `/templates` Catalog**:
   - The `/templates` page showcases community templates sorted by popularity (`memes_count DESC`), trending, or tags.
   - Includes a primary **"Upload New Template"** CTA that opens the template submission modal directly or routes to `/studio` in template ingestion mode.
   - Each template card features a **"Use this Template"** button that opens `/studio?template=:slug`, preloading the clean uncaptioned image and binding the `template_id` to the session.
3. **Meme Publishing Flow**:
   - When exporting in `/studio`, authenticated users see **"Publish to Community"**.
   - Requires: Meme Title / Caption summary, and **at least 3 tags**.
   - Saves final rendered WebP/JPG to `POST /api/v1/memes`, links to the template (if created from one), and increments `template.memes_count`.
   - Anonymous users are prompted to log in to publish, or can download/share locally without an account.
