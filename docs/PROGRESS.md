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
  - **Mobile**: Flutter app with WhatsApp injection and local metadata storage.

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
  - Animated GIF cropping: Real-time animated GIF playback within cropped aspect ratio viewport on web, with backend worker pool FFmpeg cropping pipeline (`crop=w:h:x:y,scale=outW:outH`) and mobile frame-by-frame crop boundary clamping.
  - Full responsive layout: Mobile-first layout with canvas pinned on top and tabbed control palette underneath (`Crop & Ratio`, `Captions`, `Export`), tablet dual-column workspace, and desktop 12-column studio.
- Built `PackViewer.svelte` and `/packs/[id].astro`: Dynamic sticker pack viewer featuring full pack inspection, individual sticker downloading, single-sticker WhatsApp chat share, and native mobile app deep links (`mewmer://pack/:id`).
- Wired Vite proxy in `astro.config.mjs` forwarding `/api/*` and `/uploads/*` to Go backend (`http://localhost:3030`).
- Updated `index.astro` to dynamically load public packs from `GET /api/v1/packs` with seamless fallback.
- Built `Layout.astro` and landing page `index.astro` with 3-step WhatsApp sharing walkthrough, feature highlights, and SEO tags.
- Built dedicated `/create` studio page.
- Configured Astro dev server with `host: true` on port `3031` for seamless mobile hotspot access.
- Added `check` script to `frontend/package.json` (`pnpm check` and `pnpm build` passing with 0 errors).

### 3. Backend Development (`server/`)
- Modular Go architecture:
  - `internal/config`: Environment loader.
  - `internal/models`: Data structures for packs, stickers, and processing jobs.
  - `internal/database`: PostgreSQL pool repository with pack listing, search, and creation.
  - `internal/processor`: Concurrency-safe Goroutine worker pool wrapping FFmpeg for GIF/video to animated WebP transcoding.
  - `internal/handlers`: Endpoints for `/health`, `/api/v1/packs`, `/api/v1/stickers/upload`, and `/api/v1/stickers/process-animated`.
  - Static file delivery via Chi router on `/uploads/*`.
- Verified Go build and `go vet` clean.

### 4. Database Setup
- Local PostgreSQL instance (`mewmer`) configured and running.
- Applied migration `001_initial_schema.sql` creating `users`, `sticker_packs`, and `stickers` tables with trigram indexes.

### 5. Mobile Application (`app/`)
- Flutter codebase in `app/` supports:
  - Local sticker pack creation and editing.
  - Dynamic 96×96 tray icon generation.
  - Native WhatsApp sticker pack injection via `whatsapp_stickers_injector`.
  - Minimum 3 stickers check and non-mixed static/animated validation.
- Unified mobile design system with web (`MewmerTheme`):
  - Matched Obsidian Dark palette (`#0B0F17` background, `#131B2E` cards, `#1F2B48` borders).
  - Electric Violet (`#8B5CF6`) brand accents and WhatsApp Emerald (`#25D366`) export buttons.
  - Built custom `CatLogoMark` & `MewmerBrandHeader` (`app/lib/widgets/cat_branding.dart`) featuring vector cat ears and whiskers.
  - Upgraded display typography to stylish `Space Grotesk` with tight modern tracking.
  - Locked app to pure dark mode (`ThemeMode.dark`) and unified system notification/status bar to `#0B0F17`.
  - Added dedicated full-width "Add to WhatsApp" bottom CTA in `pack_details_page.dart`.
  - Implemented Android Keyboard GIF / Sticker input via Commit Content API:
    - Wired `contentInsertionConfiguration` on `TextField` for `image/gif`, `image/webp`, `image/png`, and `image/jpeg`.
    - Added dedicated "Keyboard GIF" action and modal sheet in `meme_editor_page.dart` with user instructions.
    - Automatically copies incoming bytes to local app cache and places the media on the 512×512 canvas while preserving animation.
    - Supported double-tap text caption inline keyboard GIF insertion via `draggable_text.dart`.
    - Updated `home_page.dart` to allow opening the Studio directly without requiring an existing gallery photo.
  - Implemented interactive GIF & image cropping, zooming, and panning:
    - Added two-finger pinch-to-zoom and pan gestures directly on the 512×512 editor canvas.
    - Added Zoom slider and Reset framing button when editing image/GIF.
    - Toggleable transparent vs. blur padding with dark checkerboard preview.
    - Text captions freely positionable anywhere across canvas bounds and padding margins.
    - Preserved exact user crop, zoom, and offset transformations across all animated WebP frames and static exports.

### 6. Documentation & Guidelines Standardization
- Standardized `AGENTS.md` with:
  - Zero unwanted comments rule.
  - Strict TypeScript and Go guidelines.
  - Conventional Commits policy.
  - Verification checklist (`pnpm check`, `pnpm build`, `go vet`, comment audits).
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

---

## Active & Upcoming Roadmap Tasks

### Immediate (Phase 1 — Web & Editor):
1. **Mobile Export Verification**: Test Web Share API single-sticker export to WhatsApp on mobile via `http://10.42.0.1:3031`.
2. **Cloud Sync for Mobile App**:
   - Allow Flutter app to fetch packs from `GET /api/v1/packs/:id` and inject them directly into WhatsApp tray.
   - Deep link handling (`mewmer://pack/:id`).

### Mobile & Advanced (Phase 2):
6. **Keyboard GIF Input in Flutter (`app/`)**:
   - Implement `contentInsertionConfiguration` on `TextField` to receive GIFs from Gboard / Samsung Keyboard via Android Commit Content API.
   - Copy incoming bytes immediately to local cache, insert as an editable layer on the 512×512 canvas, and preserve animation.
7. **Cloud Sync for Mobile**:
   - Allow Flutter app to fetch packs from `GET /api/v1/packs/:id` and inject them directly into WhatsApp.
   - Deep-link support (`https://mewmer.com/p/:id`).
8. **Auth & Roles**:
   - Magic link / OAuth login for cloud saving.
   - User roles (`user`, `staff`, `admin`) with staff badges and moderation reports.
