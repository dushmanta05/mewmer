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
  - Movable, colored, permanent branding watermark: Non-deletable `mewmer.com` branding with direct canvas dragging clamped strictly within the cropped image area (`[4%, 96%]`), 6 position presets (`Bottom Right`, `Bottom Left`, `Top Right`, `Top Left`, `Bottom Center`, `Top Center`), custom hex color picker + palette chips, and opacity adjustment.
  - Sleek Obsidian Dark font dropdown: Custom interactive dropdown replacing unstyled native select, showcasing live typeface rendering for `Impact`, `Bebas Neue`, `Poppins`, `Inter`, and `Caveat` with category badges, sample glyphs, descriptions, and click-outside dismissal.
  - Studio Canvas Header Toolbar: Dedicated status header toolbar positioned outside the canvas frame containing dimensions badge, GIF tag, aspect ratio label, and contextual action guides (`RotateCw`, `Maximize2`, `Move` via `@lucide/svelte`), resolving all image overlap and text clipping issues on widescreen and custom crops.
  - Custom Stepper Pixel Dimension Controls: Replaced browser default number spin buttons with custom Obsidian Dark `[-]` and `[+]` ±50px steppers (`Minus` / `Plus`), aspect ratio lock with `Lock` / `Unlock` icons, and one-tap quick size presets (`512×512`, `1080×1080`, `1200×630`, `1920×1080`, `1080×1920`, `Original`).
  - Razor-sharp Vector Canvas Handles: Replaced blurry OS emoji glyphs (`🔄` and `⤡`) on `<canvas>` with custom anti-aliased 2D vector path primitives matching Lucide `RotateCw` and `Maximize2` iconography with drop shadow.
  - Animated GIF cropping: Real-time animated GIF playback within cropped aspect ratio viewport on web, with backend worker pool FFmpeg cropping pipeline (`crop=w:h:x:y,scale=outW:outH`) and mobile frame-by-frame crop boundary clamping.
  - Full responsive layout: Mobile-first layout with canvas pinned on top, 2-row adaptive headers and source/crop info preventing text collisions on mobile devices, single-line tabs with `whitespace-nowrap`, 2-column mobile aspect ratio grid (`9:16 Story`), authentic curved vector rotation handle on canvas, complete removal of OS emojis in favor of Lucide SVG icons, and elimination of all Svelte 5 `$state` and accessibility compiler warnings.
  - Streamlined Font Selector & Canvas Handle Consistency: Simplified font family dropdown to show only typeface icon preview and name in its font without bulky descriptions or pills; rendered the exact Lucide `RotateCw` SVG icon directly on the canvas text rotate handle using `Path2D`; removed redundant rotate/resize/pan badges from the top toolbar to keep mobile studio view clean and single-row; and added Lucide `RotateCw` and `Maximize2` icons to text tab rotation and scale controls.
  - Compact Studio Headers & Branding: Renamed tab to punchy "Crop", streamlined section headers with uppercase "OUTPUT", shortened aspect ratio button to "Locked" / "Unlocked", reduced footer spacing to py-8 mt-10, aligned "Create. Caption. Chaos." under brand title across mobile and desktop, and replaced OS emoji with custom vector CatIcon SVG and favicon.
- Built `PackViewer.svelte` and `/packs/[id].astro`: Dynamic sticker pack viewer featuring full pack inspection, individual sticker downloading, single-sticker WhatsApp chat share, and native mobile app deep links (`mewmer://pack/:id`).
- Wired Vite proxy in `astro.config.mjs` forwarding `/api/*` and `/uploads/*` to Go backend (`http://localhost:3030`).
- Updated `index.astro` to dynamically load public packs from `GET /api/v1/packs` with seamless fallback.
- Built `Layout.astro` and landing page `index.astro` with 3-step WhatsApp sharing walkthrough, feature highlights, and SEO tags.
- Built dedicated `/studio` page (renamed from `/create` with 301 redirect).
- Overhauled landing page (`index.astro`) and navbar (`Layout.astro`): Clean `🐱` brand without background box, streamlined navbar with direct `Open Studio` action, updated hero copy with Lucide icons (`Sparkles`, `ArrowRight`, `Upload`, `Crop`, `Download`, `Zap`, `Film`, `Layers`, `Type`, `FileImage`, `ChevronDown`), concise glassy pills, single-line step numbering and icon headers (`01` + `Upload` in one row), concise feature descriptions, and punchy collapsible FAQ answers.
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
  - Minimum 3 stickers check and strict non-mixed static/animated validation with explicit type selector during pack creation (`Static` vs `Animated`), type badges across home/details pages, and auto-filtering of incompatible packs during sticker save.
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

### Immediate (Phase 1 — Templates, Publishing & Database Architecture):
1. **PostgreSQL Migration (`002_meme_templates_and_publishing.sql`)**:
   - Add `role`, `avatar_url`, and `bio` to `users` table.
   - Create `meme_templates` table with `slug`, `title`, clean uncaptioned `image_url`, `media_type`, `tags` (`CHECK cardinality >= 3`), `creator_id`, and `memes_count`.
   - Create `memes` table with `template_id` FK, `creator_id` FK, `title`, `layers_data` (JSONB for multi-layer text), `image_url`, `tags` (`CHECK cardinality >= 3`), and views/shares counters.
   - Setup GIN indexes on `tags` and trigram indexes on `title`.
2. **Go Backend Endpoints (`server/`)**:
   - `POST /api/v1/templates`: Authenticated upload of clean base templates with title and ≥ 3 tags.
   - `GET /api/v1/templates`: List templates with search, tag filters, and sorting by popularity (`memes_count DESC`) or recency.
   - `GET /api/v1/templates/:slug`: Template details + generated memes created under it.
   - `POST /api/v1/memes`: Authenticated publishing of captioned memes under a template with caption summary, `layers_data` JSONB, and ≥ 3 tags; auto-increments parent template `memes_count`.
   - `GET /api/v1/memes`: Community memes discovery feed.
   - `GET /api/v1/memes/:slug`: Single meme page with creator attribution, parent template link, and share cards.
3. **Studio Publishing & Ingestion Flow (`frontend/src/components/StickerEditor.svelte`)**:
   - "Submit as Template" option when an uncaptioned image/GIF is loaded into Studio (requests title + ≥ 3 tags).
   - "Publish to Community" action on meme export with title and ≥ 3 tags; automatically links to parent template when session started from a template.
   - Keep client-side captioning and direct export 100% free for anonymous users without mandatory login.
4. **Templates Catalog (`/templates`) & Meme Gallery**:
   - Build `/templates` page listing meme templates ranked by popularity (`memes_count`) with tag chips and search.
   - "Use this Template" CTA routing directly to `/studio?template=:slug`.
   - Dedicated template detail page `/templates/[slug].astro` showing clean base and gallery of generated memes.

### Mobile & WhatsApp Stickers (Phase 2):
5. **WhatsApp Sticker Packs (Mobile Only — Not on Web)**:
   - Stickers and sticker packs are strictly a native mobile feature (`app/` in Flutter) and are **not accessed or browsed on the web**.
   - Removed web `/packs` routes from `frontend/` to keep web dedicated 100% to Meme Studio, Templates, and Community Memes.
   - User ownership: Every sticker pack and sticker is strictly linked to an authenticated user (`user_id UUID NOT NULL REFERENCES users(id)`).
   - Strict identity constraints: `email` and `username` must be unique (`UNIQUE NOT NULL`).
   - Validate packs have 3 to 30 stickers + 96×96 tray icon before mobile WhatsApp injection.
6. **Flutter Mobile App Cloud Sync (`app/`)**:
   - Allow Flutter app to fetch packs from `GET /api/v1/packs/:id` and inject directly into WhatsApp tray via `whatsapp_stickers_injector`.
   - Deep-link support (`mewmer://pack/:id` / `https://mewmer.com/p/:id`).
7. **Keyboard GIF Input in Flutter (`app/`)**:
   - Implement `contentInsertionConfiguration` on `TextField` to receive GIFs from Gboard / Samsung Keyboard via Android Commit Content API.
   - Preserve animation and place as editable layer on 512×512 canvas.
