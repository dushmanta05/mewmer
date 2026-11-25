# AGENT INSTRUCTIONS: MEWMER

This file serves as strict operational guidelines for any AI agent working on the **Mewmer** codebase (`mewmer.com`).

---

## 1. Coding Standards

**Coding standard: do not add comments when generating code unless one is absolutely necessary.** The bar is a reader who knows the language and can see the code. A comment earns its place only by carrying something the code cannot: a schema trap, a constraint from the shared database, a decision that looks wrong until you know what broke last time. If it could be deleted without losing information, delete it.

These do not earn their place, and must never be added:
- Restating the next line (`// Loop over items`, `// Set the title`).
- Naming a function above its own declaration. The signature says it.
- Section banners inside a function (`// --- validation ---`). Extract or leave.
- Narrating a change (`// now uses the new helper`). That is what git is for.
- Explaining a language or library feature to a reader who is using it.

Prefer a clearer name or a smaller function over a comment explaining a murky one. When a comment is worth writing, write it once, at the highest point it applies to: a package or type doc rather than the same note repeated on multiple methods.

### General Code Guidelines
- **Package Manager**: Use `pnpm` exclusively across all frontend workflows. Never use `npm`, `npx`, or `yarn`.
- **TypeScript & Typing**: Use TypeScript with strict types in frontend code. Never use `any` unless strictly unavoidable.
- **Components**: Keep components small, modular, and focused on a single responsibility.
- **Svelte 5**: Use modern runes (`$state`, `$derived`, `$effect`) for interactive islands. Avoid legacy Svelte 3/4 reactive syntax.
- **Go Best Practices**: Keep Go code idiomatic, clean, error-checked, and minimal. Avoid heavyweight frameworks; use `net/http` and `chi`.
- **Formatting**: Keep code clean, performant, and completely free of dead code or unused imports.

---

## 2. Technology Stack & Architectural Standards

### Frontend (Astro 5 + Svelte 5 + Tailwind CSS):
- **Astro**: Use for all routing, page shells, SSR/SSG, SEO meta tags, OpenGraph previews, and sitemaps. Aim for 100/100 Core Web Vitals.
- **Svelte 5**: Use for interactive islands (sticker editor canvas, quick-generator, pack viewers).
- **Client vs. Server Generation**:
  - **Static stickers (photos, captions, text)**: Generate 100% in the client browser using HTML5 Canvas (`canvas.toBlob('image/webp', 0.85)`). Keep server CPU usage zero for static sticker creation.
  - **Animated stickers (GIF/Video)**: Offload conversion to the Go backend FFmpeg worker pool or process in Flutter mobile app.

### Backend (Go + Chi + PGX):
- Go 1.24+ with standard library and minimal dependencies (`go-chi/chi/v5`, `jackc/pgx/v5`, `golang.org/x/image/webp`, plus the AWS SDK only for R2 S3-compatible operations).
- CPU-intensive tasks (FFmpeg) **must** run through the bounded worker pool (`internal/processor/processor.go`) to prevent VPS overload. Never execute FFmpeg synchronously inside an HTTP request handler.
- Local database: PostgreSQL 17 (`mewmer`).
- Migrations in `server/migrations/`.
- **Cloud Storage**: All binary media lives in Cloudflare R2. PostgreSQL stores metadata and R2 object keys only. Use two buckets:
  - Public bucket for meme templates and public memes.
  - Private bucket for sticker packs/stickers; served through short-lived signed URLs.
- Never commit R2 credentials, session tokens, or passwords.

### Mobile (Flutter — `app/`):
- Native Android/iOS sticker pack integration using `whatsapp_stickers_injector`.
- Direct WhatsApp tray injection requires native platform support (content provider on Android).
- Gboard/keyboard GIF content insertion via `TextField.contentInsertionConfiguration`.
- Cloud sync is explicit after login; local editing remains first-class and works offline.

---

## 3. WhatsApp Sticker Technical Specifications

Meta / WhatsApp strictly enforces these rules:
- **Dimensions**: Strictly 512×512 pixels (square canvas with transparent padding; never crop non-square).
- **Format**: WebP format with alpha channel.
- **Static Stickers**: File size strictly under 100 KB.
- **Animated Stickers**: File size strictly under 500 KB, looping (`-loop 0`), no audio (`-an`).
- **Pack Requirements**:
  - Adding a pack to WhatsApp's keyboard tray requires **3 to 30 stickers** plus a 96×96 tray icon (≤ 50 KB).
  - Do not mix static and animated stickers in a single pack.
- **Single Stickers**:
  - Single stickers can be shared into WhatsApp chats via Web Share API (`image/webp`) or clipboard, allowing recipients/senders to tap and select "Add to Favorites" (⭐).

---

## 4. Business & Product Logic
- **Anonymous Users**: Can use the web studio locally to caption images and export/download them without any server retention or account. Cannot upload templates, create cloud sticker packs, or publish community content.
- **Authenticated Users**: Own their sticker packs and stickers. Packs are private by default for the authenticated owner.
- **Admin Accounts (Launch Mode)**: Only admins can upload public meme templates and publish public packs. Public registration is disabled until community publishing is ready.
- **Publisher Name**: Set to creator display name with brand attribution (e.g. `<creator> · mewmer.com`).

---

## 5. Mandatory Verification & Build Checks
Before concluding any task or reporting completion, you **MUST** run the relevant build and check commands:

### Root Unified Dev Server:
```bash
pnpm dev
# starts Go backend (:3030) and Astro frontend (:3031)
```

### Frontend Check:
```bash
cd frontend
pnpm check
pnpm build
```
Ensure zero TypeScript, Svelte, or Astro build errors.

### Backend Check:
```bash
cd server
gofmt -l .
go test ./...
go vet ./...
go build -o /dev/null .
```
Ensure Go code compiles cleanly, tests pass, and there are no formatting drift, unused imports, or type errors.

### Mobile Check:
```bash
cd app
flutter analyze
flutter test
```

### Zero Comment Check:
```bash
grep -rn "//" frontend/src/ | grep -v -E "https?://|xmlns=" || echo "No single-line comments found"
grep -rn "/\*" frontend/src/ || echo "No block comments found"
```

---

## 6. Git & Commits

- **Commit as Often as Possible with Meaningful Changes**: Never accumulate large, monolithic batches of changes. Commit as often as possible—immediately after every distinct, verified sub-task, component, bug fix, or UI tweak passes checks, rather than waiting until a whole feature or session finishes. Frequent, atomic commits ensure a granular history, straightforward rollbacks, and safe progress tracking.
- **One Distinct Change Per Commit**: Keep each commit focused on a single logical change or feature component.
- **Conventional Commits**: Format commit messages as `type(scope): subject` or `type: subject`, using `feat`, `fix`, `perf`, `refactor`, `docs`, `style`, `test`, or `chore`.
- **Concise Subject Line**: Keep the subject concise, in all lowercase, and without a trailing period.
- **No Body or Attribution**: The subject line is the complete commit message. Never add a commit description, `Co-Authored-By` line, or any AI/assistant trailer.
- **Pre-Commit Verification**: Run the relevant build/type check (`pnpm check && pnpm build` for frontend, `gofmt && go test && go vet && go build` for backend, `flutter analyze && flutter test` for mobile) and ensure clean output before committing. Every commit in history must build cleanly.

---

## 7. Session Workflow & Progress Tracking

1. **Start of Session**: Read `docs/PROGRESS.md` and `docs/PROJECT.md` to understand active state and immediate next tasks.
2. **Implementation**: Work on one distinct task or component at a time, strictly adhering to the no-comments rule.
3. **Mandatory Verification**: Run frontend checks (`pnpm check && pnpm build`), backend checks (`gofmt && go test && go vet && go build`), or mobile checks (`flutter analyze && flutter test`). Verify zero unwanted code comments exist.
4. **Immediate Commit**: Update `docs/PROGRESS.md` and commit the verified change immediately before moving to the next task—commit often, don't wait for session end.

---

## 8. Go Learning Notes

After completing each distinct Go backend task, include a concise **Go learning note** in the final response. Explain the concepts used in that change—such as interfaces, structs, methods, error wrapping, context cancellation, Chi middleware and routing, PGX connections and transactions, goroutines and channels, or testing—why they were chosen, and which files demonstrate them. Use a tiny example only when it clarifies the concept. Do not add tutorial comments to the code.

---

## 9. Directory Structure

```text
mewmer/
├── app/                 # Flutter mobile app (native WhatsApp pack injection)
│   ├── lib/             # Dart source (models, screens, widgets)
│   └── pubspec.yaml
├── docs/                # Project documentation and live tracking
│   ├── PROJECT.md       # Architecture specification, WhatsApp constraints & database schema
│   └── PROGRESS.md      # Live roadmap, milestone status & completed tasks
├── frontend/            # Astro 5 + Svelte 5 + Tailwind web app
│   ├── src/
│   │   ├── components/  # Svelte 5 islands (QuickSticker, StickerEditor)
│   │   ├── layouts/     # Astro layout shells
│   │   └── pages/       # Astro pages (/index, /templates, /studio)
│   ├── astro.config.mjs
│   └── package.json
├── server/              # Go 1.23+ backend
│   ├── internal/        # Handlers, database, processor worker pool, storage, auth
│   ├── migrations/      # PostgreSQL migrations
│   └── main.go
├── scripts/             # Dev scripts (dev.sh)
├── AGENTS.md            # Agent operational rules & standards
└── package.json         # Root workspace scripts
```
