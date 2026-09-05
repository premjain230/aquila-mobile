# Aquila Mobile v1.4.1+9 — Ship-Ready Polish

### Syllabus — ROOT CAUSE & FIX
**Error:** `Upload failed: Missing or insufficient permissions.`
**Root cause:** Firestore writes used `auth.currentUser` synchronously without refreshing an expired ID token. After ~1 hour the token expired, `request.auth` became null, Firestore `isOwner` check (`request.auth.uid == userId`) failed, and the SDK threw `permission-denied`. Mobile had same issue plus dummy upload (no picker, no Storage) that created fake `120KB` docs.
**Fix:** `await user.getIdToken(true)` before every syllabus write on web (`home.html` etc 11 pages) and mobile (`home_screen.dart`). Created `storage.rules` (`users/{uid}/syllabus/{id}` owner-only, <8MB, pdf/image) and `firebase.json`. Mobile now uses `file_picker` + `firebase_storage` to pick real file, upload to `users/{uid}/syllabus/{id}/{name}`, store `storageUrl`/`storagePath` + snippet in `users/{uid}/syllabus/{id}` and mirror to `users/{uid}/learning/profile.syllabus`, emit `syllabus_uploaded` event. User-isolated paths, server-side rule enforcement, no public write.

### Web — Mobile-Friendly (320,360,375,390,412,430, tablet, desktop)
- `css/shell.css`: `body` 100vh→100dvh + safe-area insets, `html` overflow-x hidden, `sidebar` safe-area padding, `nav-item` 44px, `menu-btn` 44px, `sidebar-close` 44px, `.topbar` safe-area + hidden `topbar-center` at 880px (fixes planner/analyze topbar 175px overflow at 320px), added `firebase.json` indexes
- `css/base.css`: `.btn` 38→44px, `.btn-sm` 32→40px, `.btn-icon` 36→44px, `.field` 40→44px + 16px at 480px (prevents iOS zoom), input-area safe-area
- `css/nav.css`: created (hamburger 44px, overlay, panel 85vw, safe-area) — fixes missing 404 for `index.html`/`quiz.html`
- `index.html`: experience mock `150px` overflow at 320px → stacked flex at 560px, viewport-fit=cover on all pages (12 files), safe-area for topbar
- All pages: fixed horizontal scroll, grid stacking (4→2→1), touch targets 44px, chat composer safe-area, code `overflow-wrap:anywhere`

### Mobile — Production UX
- **Home syllabus** `home_screen.dart:1-256`: real picker + Storage upload + Firestore, loading spinner, permission/network error mapping, substring guard, `120KB` fake removed
- **Back handling** `main_shell.dart:32-70`: `PopScope` — tab back to Today then exit confirm, `resizeToAvoidBottomInset:false`, drawer `SafeArea`
- **Theme** `app.dart` + `theme_store.dart`: `ValueNotifier` live toggle (was save-only, required restart)
- **Quiz** `quiz_screen.dart:381-407`: Row overflow fixed with `Expanded` + `fullWidth:false`
- **Profile** `profile_screen.dart:298`: removed dead `Text(...?'' :'')`
- **Study session** `study_session_screen.dart:45-55`: `dispose` persists `abandoned` if active, prevents orphan `active` docs
- **Storage** `pubspec.yaml:18-20`: added `firebase_storage 12.3.0`, `file_picker 8.1.0`
- **Build** `android/app/build.gradle.kts`: minify flags documented, debug keystore comment, `isMinifyEnabled=false` for now

### Version
- Previous `1.4.0+8` → New `1.4.1+9`
- APK `build/app/outputs/flutter-apk/app-release.apk` 54MB, download `releases/download/v1.4.1/app-release.apk`
- Web `api/version.js`: `latestVersion 8→9`, notes updated to syllabus + responsive polish
