# MEWMER — PROJECT SPECIFICATION & ARCHITECTURE

Mewmer is an all-in-one web and mobile platform for creating, customizing, and sharing WhatsApp stickers and memes.

---

## 1. Project Vision & Phased Roadmap

### Phase 1: High-Performance Sticker Generator (Current)
- Web-based 512×512 sticker generator running client-side on HTML5 Canvas.
- Instant single sticker sharing to WhatsApp chats via Web Share API (`image/webp`) and clipboard copying.
- Public sticker pack discovery directory with SEO-optimized landing pages.
- Lightweight Go backend handling PostgreSQL storage and FFmpeg-based animated sticker conversions.

### Phase 2: User Accounts & Community Packs
- User authentication (Email/Password, OAuth).
- Anonymous packs default to public (SEO/UGC booster).
- Logged-in creators can save packs as private or public, manage packs, and edit their collections.
- Creator profile pages (`/creator/[username]`).

### Phase 3: Complete Meme Platform & Monetization
- Template library (popular meme templates, trending formats, custom text overlays).
- Video and animated GIF meme creation.
- Monetization layer: Google AdSense / high-performance display ads, premium templates, and custom sticker exports.

---

## 2. Tech Stack

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Frontend** | Astro 5 + Svelte 5 | Islands architecture, zero-JS page shells, 100/100 Core Web Vitals, SSR/SSG. |
| **Styling** | Tailwind CSS | Custom Mewmer Obsidian Dark palette. |
| **Package Manager** | `pnpm` | Required across all frontend tooling. |
| **Backend** | Go (Golang 1.23+) | Chi v5 router, PGX v5 connection pool, native Goroutine worker pool. |
| **Media Processing**| Browser Canvas + FFmpeg | Client-side 512×512 WebP for static stickers; Go FFmpeg queue for animated WebP. |
| **Database** | PostgreSQL 17 | Relational tables with `pg_trgm` full-text search and JSONB support. |
| **Mobile App** | Flutter | Located in `app/`, handles Android/iOS native WhatsApp pack injection. |

---

## 3. WhatsApp Sticker Technical Specifications

- **Dimensions**: Strictly 512×512 pixels.
- **Format**: WebP format with alpha channel (transparency).
- **Static Stickers**: File size must be under 100 KB.
- **Animated Stickers**: File size must be under 500 KB, frame rate 8–20 fps, duration ≤ 5 seconds, looping continuously (`-loop 0`).
- **Packs vs. Single Stickers**:
  - **Adding to WhatsApp Drawer**: Official WhatsApp protocol requires **3 to 30 stickers** per pack plus a 96×96 tray icon.
  - **Direct Chat Sharing**: A single sticker can be sent directly into any WhatsApp chat as `image/webp`. Senders and recipients can tap the sticker and select "Add to Favorites" (⭐) to save it permanently.

---

## 4. Design System & Color Palette

- **Background Canvas**: Deep Obsidian (`#0B0F17`)
- **Card Surfaces**: Dark Navy Charcoal (`#131B2E`)
- **Card Hover / Accent Surfaces**: (`#1A243D`)
- **Borders**: Slate Navy (`#1F2B48`)
- **Primary Brand Accent**: Electric Violet (`#8B5CF6` / `#7C3AED`)
- **WhatsApp Action CTA**: WhatsApp Emerald (`#25D366`)
- **Trending & Badges**: Fire Amber (`#F59E0B`)

---

## 5. Database Schema (`mewmer`)

### `users`
- `id` (UUID, Primary Key)
- `email` (VARCHAR, Unique)
- `username` (VARCHAR, Unique)
- `password_hash` (TEXT)
- `is_admin` (BOOLEAN)
- `created_at` (TIMESTAMP)

### `sticker_packs`
- `id` (VARCHAR(64), Primary Key, e.g. `cats-chaotic-a1b2`)
- `title` (VARCHAR(100))
- `publisher` (VARCHAR(100))
- `tray_image_url` (TEXT)
- `is_animated` (BOOLEAN)
- `is_public` (BOOLEAN, default TRUE)
- `user_id` (UUID, Foreign Key → `users.id`)
- `downloads_count` (INTEGER)
- `created_at` (TIMESTAMP)

### `stickers`
- `id` (UUID, Primary Key)
- `pack_id` (VARCHAR(64), Foreign Key → `sticker_packs.id`)
- `image_url` (TEXT)
- `emojis` (TEXT[])
- `file_size` (INTEGER)
- `is_animated` (BOOLEAN)
- `created_at` (TIMESTAMP)

---

## 6. API Endpoints

- `GET /health` — Service healthcheck
- `GET /api/v1/packs?q=&page=` — Paginated public pack listing with search
- `GET /api/v1/packs/{id}` — Pack details and sticker list
- `POST /api/v1/packs` — Save sticker pack
- `POST /api/v1/stickers/upload` — Upload client-generated 512×512 WebP sticker
- `POST /api/v1/stickers/process-animated` — Transcode GIF/video to animated WebP via FFmpeg queue
- `GET /uploads/*` — Static asset delivery
