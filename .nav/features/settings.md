<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `settings`

> `lib/features/settings/` · **4 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.settings` | `/settings` |  |
| `RouteNames.about` | `/settings/about` |  |
| `RouteNames.changePassword` | `/settings/change-password` |  |
| `RouteNames.notificationSettings` | `/settings/notifications` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/settings/presentation/pages/about_page.dart`
- `lib/features/settings/presentation/pages/change_password_page.dart`
- `lib/features/settings/presentation/pages/notifications_settings_screen.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`

## Backend surface
- **Firestore collections:** —
- **Cloud Functions:** —
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** —

## Tests
- `test/features/settings/notifications_settings_screen_test.dart`
- `test/settings_page_test.dart`

## Standard data flow (this feature follows the universal pattern)
```
UI (page/widget)
  → Cubit.method()            presentation/cubit/
    → UseCase.call()          domain/usecases/
      → Repository (contract) domain/repositories/
        → RepositoryImpl      data/repositories/
          → RemoteDatasource  data/datasources/   → Firestore/Functions/API
  ← Model.fromJson → Entity ← Stream/Future ← Cubit emits state → UI rebuilds
```

<!-- ═══════════════ HAND-AUTHORED INTELLIGENCE (edit freely) ═══════════════ -->

## Purpose
Presentation-only account hub: signed-in identity/profile access, password
security, the Cases workspace shortcut, product/support information, version and
sign-out. It owns no data; authentication state comes from the app-wide AuthCubit.

## ⚠️ Dangerous areas / invariants
Keep Profile, Change Password, Cases and About routed through RouteNames. Sign
out must continue through AuthCubit. Reuse the shared glass, avatar and motion
primitives; Settings must not become a second profile editor.

## 🧩 Extension points
Add account/workspace destinations as Settings rows. Product/support detail
belongs on AboutPage; security forms belong on their dedicated routed pages.

## 🔗 Related
`auth` supplies the session identity and sign-out; `profile` owns profile edits;
`cases` owns private operational conversations.
