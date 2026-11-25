# MEWMER — PRODUCTION & RELEASE GUIDE

This document tracks production deployment configuration, release builds, and asset generation workflows for Mewmer.

---

## 1. Mobile App Icons & Splash Screen (`app/`)

### Current Setup
- **Launcher Icon**: Generated from `scripts/generate-app-icons.py` into `app/assets/icon/mewmer.png` (`1024×1024` transparent PNG) and compiled into Android mipmaps/drawables via `flutter_launcher_icons` (configured in `app/pubspec.yaml` with `adaptive_icon_background: "#131B2E"`).
- **Splash Screen**: Uses `#0B0F17` (`MewmerTheme.background`) with the centered `app/android/app/src/main/res/drawable-xhdpi/splash_icon.png` (`192×192`), configured in `app/android/app/src/main/res/drawable/launch_background.xml`, `app/android/app/src/main/res/drawable-v21/launch_background.xml`, and `app/android/app/src/main/res/values/styles.xml`.

### Regenerating the Default Cat Icons
Run from the repository root:
```bash
pnpm icons:app
```
This executes `python3 scripts/generate-app-icons.py` and `cd app && dart run flutter_launcher_icons`.

### Using a Custom Image Instead
If you want to replace the generated cat mark with a custom image (for example, a designer-exported PNG):
1. Prepare a **`1024×1024` transparent PNG** and save it to `app/assets/icon/mewmer.png`.
   - Keep roughly **10%–18% transparent padding** around the artwork so Android's circular/squircle adaptive icon mask does not clip the edges.
2. Optionally update the adaptive background color in `app/pubspec.yaml` under `flutter_launcher_icons.adaptive_icon_background`.
3. For the splash screen, save a **`192×192` transparent PNG** to `app/android/app/src/main/res/drawable-xhdpi/splash_icon.png`.
4. Run **only** the Flutter icon generator (do **not** run `pnpm icons:app`, as `generate-app-icons.py` would overwrite your custom PNGs):
   ```bash
   cd app && dart run flutter_launcher_icons
   ```
5. Reinstall the app (`pnpm dev:app` or `pnpm build:app`) so Android picks up the updated native resources (hot reload does not update native icons/splash).

---

## 2. Mobile Production Builds

### API Base URL
`MewmerApiClient` defaults to `http://localhost:3030/api/v1` (which works in local USB dev via `adb reverse tcp:3030 tcp:3030` in `scripts/dev-app.sh`).

For production or staging builds, pass `API_BASE_URL` at compile time:
```bash
cd app
flutter build apk --release --dart-define=API_BASE_URL=https://api.mewmer.com/api/v1
```
For Play Store App Bundles:
```bash
cd app
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.mewmer.com/api/v1
```

---

## 3. Backend, Frontend & Storage Deployment (Checklist)

- **Backend (`server/`)**:
  - Build binary: `pnpm build:backend`
  - Configure `DATABASE_URL`, `STORAGE_TYPE=r2`, `R2_PUBLIC_BUCKET`, `R2_PRIVATE_BUCKET`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_PUBLIC_BASE_URL`, `SECURE_COOKIE=true`, and `COOKIE_DOMAIN`.
  - Apply SQL migrations in `server/migrations/` and seed admin via `pnpm create:admin`.
- **Frontend (`frontend/`)**:
  - Build static/SSR bundle: `pnpm build:frontend`
- **Cloudflare R2**:
  - Public bucket (`mewmer-public-media`) mapped to public CDN domain for templates.
  - Private bucket (`mewmer-private-media`) served only via short-lived presigned URLs.
