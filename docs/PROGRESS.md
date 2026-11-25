# MEWMER — DEVELOPMENT PROGRESS LOG

This document tracks all completed milestones, current system status, mobile testing setup, and active roadmap tasks.

---

## Completed Milestones

### 1. Requirements, Constraints & Architecture Decisions
- WhatsApp sticker specs codified: Exactly 512×512 WebP, static < 100 KB, animated < 500 KB, pack requires 3–30 stickers + 96×96 tray icon.
- Dual distribution model established:
  - **Direct single sticker share**: Web & mobile via Web Share API (`image/webp`) or clipboard, allowing users to save to WhatsApp Favorites (⭐).
  - **Keyboard pack injection**: Mobile app (`app/`) using native Android/iOS ContentProvider via `whatsapp_stickers_injector`.
- Unified stack:
  - **Frontend**: Astro 5 + Svelte 5 + Tailwind CSS + `pnpm`.
  - **Backend**: Go 1.23+ (Chi router, PGX connection pool, bounded FFmpeg worker pool).
  - **Database**: PostgreSQL 17 with `uuid-ossp` and `pg_trgm` extensions.
  - **Cloud Storage**: Cloudflare R2 for binary media; PostgreSQL stores metadata and object keys.
  - **Mobile**: Flutter app for WhatsApp injection, local file storage, and Gboard GIF insertion.

### 2. Frontend Modernization (`frontend/`)
- Setup Astro 5 and Svelte 5 with Tailwind CSS and Obsidian Dark design system.
- Built `QuickSticker.svelte`: Instant hero-section single-sticker generator with template presets, custom file uploads, and Web Share API integration.
- Transformed web studio into a full responsive Image Resizer, Cropper & Caption Studio (`StickerEditor.svelte`):
  - Preserves natural dimensions of uploaded images without forced 512×512 square squishing.
  - Aspect ratio presets: `Original (Free)`, `1:1 (Square)`, `4:3 (Standard)`, `16:9 (Widescreen)`, `9:16 (Story/Reel)`, and `3:4 (Portrait)`.
  - Custom pixel dimension resizing inputs with aspect ratio lock toggle (`🔒 Locked Aspect`).
  - Dynamic multi-layer text system: Add unlimited captions, drag to position anywhere on canvas, circular 🔄 rotate handle for direct angle rotation, corner ⤡ scale handle for direct expansion, scale/rotation sliders with 0° reset.
  - Direct canvas gesture framing: Drag to pan/scroll images smoothly inside any chosen aspect ratio crop frame.
  - Multi-format exports: Export as **WebP**, **JPG / JPEG**, or **PNG** with adjustable compression quality slider.
  - Subtle `mewmer.com` watermark: Low-opacity text-only watermark with soft drop shadow (no background box), optional glassy pill toggle, and position presets.
  - Movable, colored, permanent branding watermark: Non-deletable `mewmer.com` branding with direct canvas dragging clamped strictly within the cropped image area (`[4%, 96%]`), 6 position presets (`Bottom Right`, `Bottom Left`, `Top Right`, `Top Left`, `Bottom Center`, `Top Center`), custom hex color picker + palette chips, and opacity adjustment.
  - Sleek Obsidian Dark font dropdown: Custom interactive dropdown replacing unstyled native select, showcasing live typeface rendering for `Impact`, `Bebas Neue`, `Poppins`, `Inter`, and `Caveat` with category badges, sample glyphs, descriptions, and click-outside dismissal.
  - Studio Canvas Header Toolbar: Dedicated status header toolbar positioned outside the canvas frame containing dimensions badge, GIF tag, aspect ratio label, and contextual action guides (`RotateCw`, `Maximize2`, `Move` via `@lucide/svelte`).
  - Custom Stepper Pixel Dimension Controls: Replaced browser default number spin buttons with custom Obsidian Dark `[-]` and `[+]` ±50px steppers (`Minus` / `Plus`), aspect ratio lock with `Lock` / `Unlock` icons, and one-tap quick size presets.
  - Razor-sharp Vector Canvas Handles: Replaced blurry OS emoji glyphs on `<canvas>` with custom anti-aliased 2D vector path primitives matching Lucide `RotateCw` and `Maximize2` iconography with drop shadow.
  - Animated GIF cropping: Real-time animated GIF playback within cropped aspect ratio viewport on web, with backend worker pool FFmpeg cropping pipeline and mobile frame-by-frame crop boundary clamping.
  - Full responsive layout: Mobile-first layout with canvas pinned on top, 2-row adaptive headers and source/crop info preventing text collisions on mobile devices, single-line tabs, 2-column mobile aspect ratio grid, authentic curved vector rotation handle on canvas, and elimination of all Svelte 5 `$state` compiler warnings.
  - Streamlined Font Selector & Canvas Handle Consistency: Simplified font family dropdown to show only typeface preview and name; rendered the exact Lucide `RotateCw` SVG icon directly on the canvas text rotate handle using `Path2D`.
  - Compact Studio Headers & Mobile Responsive Polish: Renamed tab to "Crop", uppercase "OUTPUT" header, shortened aspect ratio button to "Locked" / "Unlocked", reduced footer spacing, aligned "Create. Caption. Chaos." under brand title, normalized caption input size, and made navbar context-aware with live studio badge.
- Built `Layout.astro` and landing page `index.astro` with SEO tags and feature highlights.
- Built dedicated `/studio` page (renamed from `/create` with redirect).
- Wired Vite proxy in `astro.config.mjs` forwarding `/api/*` and `/uploads/*` to Go backend (`http://localhost:3030`).
- Added `check` script to `frontend/package.json` (`pnpm check` and `pnpm build` passing with 0 errors).

### 3. Backend Development (`server/`)
- Modular Go architecture:
  - `internal/config`: Environment loader.
  - `internal/models`: Data structures for users, sessions, packs, stickers, and processing jobs.
  - `internal/database`: PostgreSQL pool repository with user/session/pack operations.
  - `internal/auth`: Argon2id password hashing and opaque session-token generation.
  - `internal/middleware`: Chi authentication and admin-role middleware.
  - `internal/handlers`: Endpoints for `/health`, `/api/v1/auth/*`, `/api/v1/packs`, `/api/v1/stickers/upload`, and `/api/v1/stickers/process-animated`.
  - `cmd/create-admin`: CLI tool to seed the first admin account.
  - `internal/processor`: Concurrency-safe Goroutine worker pool wrapping FFmpeg for GIF/video to animated WebP transcoding.
  - Static file delivery via Chi router on `/uploads/*`.
- Added `002_identity_and_sessions.sql` migration for user profiles, roles, links, and sessions.
- Verified `gofmt`, `go test ./...`, `go vet ./...`, and `go build` clean.

### 4. Database Setup
- Local PostgreSQL instance (`mewmer`) configured and running (start before dev/testing).
- Applied migration `001_initial_schema.sql` creating `users`, `sticker_packs`, and `stickers` tables with trigram indexes.
- Migration `002_identity_and_sessions.sql` ready to apply when PostgreSQL is running.

### 5. Mobile Application (`app/`)
- Flutter codebase in `app/` supports:
  - Local sticker pack creation and editing.
  - Dynamic 96×96 tray icon generation.
  - Native WhatsApp sticker pack injection via `whatsapp_stickers_injector`.
  - Minimum 3 stickers check and strict non-mixed static/animated validation.
- Unified mobile design system with web (`MewmerTheme`):
  - Matched Obsidian Dark palette (`#0B0F17` background, `#131B2E` cards, `#1F2B48` borders).
  - Electric Violet (`#8B5CF6`) brand accents and WhatsApp Emerald (`#25D366`) export buttons.
  - Built custom `CatLogoMark` & `MewmerBrandHeader` (`app/lib/widgets/cat_branding.dart`).
  - Upgraded display typography to stylish `Space Grotesk`.
  - Locked app to pure dark mode and unified system notification/status bar.
  - Implemented Android Keyboard GIF / Sticker input via Commit Content API.
  - Implemented interactive GIF & image cropping, zooming, and panning with transparent/blur padding toggle.

### 6. Documentation & Guidelines Standardization
- Standardized `AGENTS.md` with:
  - Zero unwanted comments rule.
  - Strict TypeScript and Go guidelines.
  - Cloudflare R2 storage rules and two-bucket design.
  - Conventional Commits policy.
  - Verification checklist (`pnpm check`, `pnpm build`, `gofmt`, `go test`, `go vet`, comment audits).
  - Go learning note rule after each backend task.
- Migrated documentation into `docs/` (`docs/PROJECT.md`, `docs/PROGRESS.md`).

---

## Current System Status & Mobile Access

- **Web Server**: Port `3031` (`host: true` enabled).
- **Backend Server**: Port `3030`.
- **Laptop Wi-Fi Hotspot IP**: `10.42.0.1`.
- **LAN IP**: `172.16.25.221`.
- **Mobile Access URL**: `http://10.42.0.1:3031`.

To launch the servers for mobile testing:
```bash
pnpm dev
# Or just frontend:
cd frontend && pnpm dev
```
Then on the mobile device connected to the laptop's Wi-Fi hotspot, navigate in the browser to:
**`http://10.42.0.1:3031`**

### Known Gaps
- `002_identity_and_sessions.sql` and `003_meme_templates.sql` have been applied.
- Admin user exists (`admin@mewmer.com` / `changeme123` in local dev).
- Cloudflare R2 abstraction is in place; filesystem mode is active locally and R2 mode activates when `STORAGE_TYPE=r2` and credentials are set.
- Flutter has no API client, login flow, or cloud save/restore.
- Web app has no template catalog, template detail, or admin upload UI.
- The modified `whatsapp_stickers_injector` dependency is patched in `.pub-cache`, which is not reproducible on a clean machine.

---

## Active & Upcoming Roadmap Tasks

### Phase 1 — Admin Auth, Templates & Sticker Cloud Sync

- [x] **Identity & Session Foundation (`server/`)**:
  - Migration `002_identity_and_sessions.sql`.
  - CLI admin-creation tool (`cmd/create-admin`).
  - Login/logout/me endpoints with cookie and bearer-token support.
  - Chi authentication and admin-role middleware.
  - Auth package unit tests.
- [x] **Cloudflare R2 Storage (`server/`)**:
  - Storage abstraction with filesystem (dev) and R2 (prod) implementations.
  - Media validation for templates and WebP stickers.
  - Public/private bucket config and signed URL support.
- [x] **Meme Template Backend (`server/`)**:
  - Migration `003_meme_templates.sql`.
  - Admin-only template upload and public list/detail endpoints.
  - Verified end-to-end with login, upload, list, and static file serving.
- [ ] **Sticker Cloud Backend (`server/`)**:
  - Authenticated owner endpoints for packs and stickers.
  - Replace old unauthenticated upload routes.
- [ ] **Flutter Cloud Sync (`app/`)**:
  - API client, secure session store, login screen, cloud save/restore.
- [ ] **Web Template Flow (`frontend/`)**:
  - Admin login, template upload, public catalog/detail pages, studio preloading.

### Phase 2 — Community Memes, Multi-User Publishing & Curation

- Public registration, OAuth, or magic-link authentication.
- `memes` table and community feed endpoints.
- Reports table and moderation dashboard.
- Creator/staff roles and profile link editing UI.

### Phase 3 — Moderation, Discovery & Mobile Polish

- Trending memes, tag autocomplete, creator profiles.
- Offline sync conflict resolution.
- iOS support and app-store release readiness.

---

## Immediate Next Task

Implement **Sticker Cloud Backend** and begin **Flutter Cloud Sync**.
