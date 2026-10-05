# AGENT INSTRUCTIONS: MEWMER

This file serves as strict operational guidelines for any AI agent working on the **Mewmer** codebase.

---

## 1. Code Generation Rules
- **Write Optimized Code Without Comments**: Do not add unnecessary comments, redundant docstrings, or inline narration. Code must be concise, idiomatic, self-documenting, and clean.
- **Package Manager**: Use `pnpm` exclusively across all frontend workflows. Never use `npm`, `npx`, or `yarn`.
- **Formatting**: Keep code clean, performant, and free of dead code or unused imports.

---

## 2. Mandatory Verification & Build Checks
Before concluding any task or reporting completion to the user, you **MUST** run the relevant build and check commands:

### Root Unified Dev Server:
```bash
pnpm dev
# or: make dev
```
Starts Go backend on `http://localhost:3030` and Astro frontend on `http://localhost:3031`.

### Frontend Check:
```bash
cd frontend
pnpm check
pnpm build
```
Ensure zero TypeScript, Svelte, or Astro build errors. Never leave the frontend in a broken build state.

### Backend Check:
```bash
cd server
go vet ./...
go build -o /dev/null .
```
Ensure the Go code compiles cleanly without unused imports or type errors.

---

## 3. Technology Stack & Architectural Standards

### Frontend (Astro 5 + Svelte 5 + Tailwind CSS):
- **Astro**: Use for all routing, page shells, SSR/SSG, SEO meta tags, OpenGraph previews, and sitemaps. Aim for 100/100 Core Web Vitals (zero client JS where possible).
- **Svelte 5**: Use runes (`$state`, `$derived`, `$effect`) for interactive islands like the sticker editor, canvas manipulators, and preview components.
- **Client vs. Server Generation**:
  - **Static stickers (photos, captions, text)**: Generate 100% in the client browser using HTML5 Canvas (`canvas.toBlob('image/webp', 0.85)`). Keep server CPU usage minimal.
  - **Animated stickers (GIF/Video)**: Offload conversion to the Go backend FFmpeg worker pool.

### Backend (Go + Chi + PGX):
- Go 1.23+ with standard library and minimal dependencies (`go-chi/chi/v5`, `jackc/pgx/v5`).
- CPU-intensive tasks (FFmpeg) **must** run through the bounded worker pool (`internal/processor/processor.go`) to prevent VPS overload. Never execute FFmpeg synchronously inside an HTTP request handler.
- Strictly adhere to WhatsApp sticker specifications:
  - Exact 512×512 dimensions.
  - Transparent background padding where needed.
  - Static WebP: < 100 KB.
  - Animated WebP: < 500 KB, max 20-30 fps, looping (`-loop 0`), no audio (`-an`).

### Database (PostgreSQL):
- Local database name: `mewmer`.
- Local connection string: `postgres://dushmanta:password@localhost:5432/mewmer?sslmode=disable`.
- All database modifications must be reflected in versioned migration files under `server/migrations/`.
- Leverage PostgreSQL's built-in `pg_trgm` for search queries.

---

## 4. Business & Product Logic
- **Anonymous Users**: Sticker packs created anonymously are **always public**. This provides free user-generated content (UGC) and indexable SEO landing pages.
- **Authenticated Users**: Can toggle between public and private visibility.
- **WhatsApp Packs vs. Single Stickers**:
  - Adding a pack to WhatsApp's keyboard tray requires **3 to 30 stickers** (WhatsApp restriction).
  - Single stickers can be sent directly to WhatsApp chats via Web Share API (`image/webp`) or clipboard, allowing users to save them to Favorites (⭐).
