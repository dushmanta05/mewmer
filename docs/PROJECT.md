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

### Phase 2: Cloud Sync, Accounts & Community Packs
- Authentication (Email Magic Link / OAuth / Password).
- Privacy and visibility controls:
  - Anonymous packs default to `public` (provides free UGC and SEO landing pages).
  - Authenticated creators can choose `private` (creator only), `unlisted` (anyone with link), or `public` (listed in gallery).
  - "Delete account and all data" capability.
- Roles system: `user`, `staff`, `admin`. Staff/admin badges on pack pages and content moderation.
- Dynamic pack pages (`/packs/[id]`) with deep-link fallback to web or mobile app (`https://mewmer.com/p/:id`).
- Pack import in Flutter app: fetch pack metadata and WebP files from backend API and inject directly into WhatsApp.

### Phase 3: Meme Generator & Platform Monetization
- Meme generator supporting standard aspect ratios (PNG/JPEG) alongside 512×512 WebP sticker exports.
- Template library (popular meme formats, customizable text boxes).
- Community reporting system (`reports` table) and staff moderation dashboard.

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

## 5. Editor & Canvas Specifications

- **Dimensions**: Exactly 512×512 px canvas with transparent background.
- **Safe Margin Guide**: Visible ~16 px safe margin boundary guide.
- **Layers**:
  - Base image or animated GIF layer (move, scale, fit with transparent padding).
  - Caption text layers (font family, font size, text color, stroke outline color/width, move, rotate).
  - Brand mark layer: Movable "mewmer.com" brand mark. Default ON, rotatable and scalable, clamped inside the canvas (cannot be dragged out of frame), togglable off in settings.
- **Client-Side Generation**: 100% rendered locally on device/browser. User photos and GIFs are not uploaded for normal editing and export.

---

## 6. Privacy & Storage Rules

- **Not Logged In**: Nothing stored on the backend. All state lives exclusively in the browser or mobile app.
- **Cloud Saving**: Requires authentication.
- **Visibility Options**:
  - `private` (default for saved items in user library).
  - `unlisted` (accessible only via direct link).
  - `public` (listed in community gallery and indexed for SEO).
- **Deletion**: Deleting an item removes database records and storage files. "Delete my account and all data" must be provided.
- **Zero Raw Media Retention**: Never store original uploaded media unless explicitly opted in; store only the final 512×512 WebP.

---

## 7. Database Schema (`mewmer`)

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(64) UNIQUE NOT NULL,
  display_name VARCHAR(100) NOT NULL,
  password_hash TEXT,
  role VARCHAR(20) NOT NULL DEFAULT 'user', -- user | staff | admin
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sticker_packs (
  id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(100) NOT NULL,
  publisher VARCHAR(100) NOT NULL DEFAULT 'mewmer.com',
  tray_image_url TEXT NOT NULL,
  is_animated BOOLEAN DEFAULT FALSE,
  is_public BOOLEAN DEFAULT TRUE,
  visibility VARCHAR(20) NOT NULL DEFAULT 'public', -- private | unlisted | public
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  downloads_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE stickers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pack_id VARCHAR(64) REFERENCES sticker_packs(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  emojis TEXT[] DEFAULT '{}',
  file_size INTEGER NOT NULL,
  is_animated BOOLEAN DEFAULT FALSE,
  source VARCHAR(30) DEFAULT 'upload', -- upload | keyboard | template
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  target_type VARCHAR(20) NOT NULL, -- sticker | pack
  target_id VARCHAR(64) NOT NULL,
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_sticker_packs_public ON sticker_packs(is_public, created_at DESC);
CREATE INDEX idx_sticker_packs_title_trgm ON sticker_packs USING gin (title gin_trgm_ops);
CREATE INDEX idx_stickers_pack_id ON stickers(pack_id);
```

---

## 8. Backend API Endpoints

- `GET /health` — Service healthcheck
- `GET /api/v1/packs?q=&page=&limit=` — Paginated pack listing with fuzzy search
- `GET /api/v1/packs/{id}` — Pack details and sticker list
- `POST /api/v1/packs` — Create or update sticker pack
- `POST /api/v1/stickers/upload` — Upload client-generated 512×512 WebP sticker (< 100 KB)
- `POST /api/v1/stickers/process-animated` — Transcode GIF/video to animated WebP via FFmpeg worker pool (< 500 KB)
- `POST /api/v1/reports` — Submit report for content review
- `GET /uploads/*` — Serve public sticker images and tray icons
