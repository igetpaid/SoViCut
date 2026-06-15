# SoViCut Project Summary

## Stack
- **Framework:** Flutter (Dart)
- **State:** Riverpod + Provider
- **UI:** Material, custom theme, no AndroidX embedding issues
- **Localization:** Custom `AppLocalizations.t('key')` via JSON assets (`assets/locales/*.json`)
- **Build:** Windows ✅, Android ❌ (file_picker v1 embedding issue)
- **Analysis:** `flutter analyze` — 0 errors, 0 warnings, 8 info (pre-existing `avoid_print`)

## Architecture
- **Entry:** `main.dart` → `App` widget → `HomeScreen`
- **HomeScreen** is a stateful widget managing: audio, clips, export, FFmpeg pipeline
- **Audio:** `AudioState` / `AudioNotifier` (Riverpod) — tracks, muted, mixEnabled
- **Export:** FFmpeg strategy via `ExportSettingsTab` + `tool_panel.dart`
- **LocaleProvider:** Riverpod StateNotifier for language switching

## Recent Changes (2026-06-15)

### Audio UX overhaul
- **Removed** master "Configure audio" checkbox — audio panel always visible
- **Added** 2 general toggles below the audio track list:
  - "Export without audio" (`_muteAudio`) — muted tracks in export
  - "Mix tracks" (`mixEnabled`) — merge all tracks into one
- **Now audio is always enabled by default** (was opt-in, now opt-out)
- Fixed: removed duplicate `skip_previous` button in toolbar
- Fixed: added `TextDecoration.none` to toolbar text buttons (underlines)

### Settings / Localization
- **LocaleProvider** — manages `Locale` state, persists to shared_preferences
- **Language selector** in Settings panel (`ui/settings/settings_panel.dart`) — dropdown with en/ru
- Updated `assets/locales/en.json` and `ru.json` with new `audio.exportWithoutAudio` and `settings.language` keys

### Lint fixes
- Removed unused imports (`cupertino.dart`, etc.)
- Renamed deprecated `_withOpacity` → `withValues(alpha:)`
- Replaced deprecated `activeColor` → `activeThumbColor` on `SwitchListTile` widgets

## Remaining issues
- Android build broken: `file_picker` plugin uses v1 embedding (pre-existing, not caused by us)
- `lib/core/localization/en.json` / `ru.json` are stale duplicates of `assets/locales/*.json`
- 8 `avoid_print` info-level items in ffmpeg/service code
