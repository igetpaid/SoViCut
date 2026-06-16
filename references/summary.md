# SoViCut Project Summary

## Stack
- **Framework:** Flutter (Dart)
- **State:** Riverpod + Provider
- **UI:** Material, custom theme
- **Localization:** Custom `AppLocalizations.t('key')` via JSON assets (`assets/locales/*.json`)
- **Build:** Windows ✅ (`flutter build windows --debug`), Android ❌ (file_picker v1 embedding)
- **Analysis:** `flutter analyze` — 0 errors, 0 warnings, 8 info (pre-existing `avoid_print`)

## Recent Changes (2026-06-15)

### Bugfixes — P3
- **export.success text** — `"Exporting... 100%"` → `"Export complete"` / `"Экспорт завершён"` (`assets/locales/{en,ru}.json`)
- **Clip edge drag removed** — dead code that modified clip state without `setState()` (`timeline_bar.dart`, `_ScrubBarPainter`)
- **TextEditingController leaks fixed** — `export_settings_tab.dart` now stores controllers in state (init + dispose), `batch_screen.dart` extracted to `_PrecisionSlider` StatefulWidget

### Architecture — P0, P1, P4
- **Dual state fix** — `home_screen.dart` now listens to `audioProvider` + `clipsProvider` changes via `ref.listen` in `didChangeDependencies`. Provider mutations (from AudioTab, ClipsTab) propagate to local state immediately
- **Theme factory** — `app_theme.dart` collapsed from 324→112 lines. `_build(AppColorSet, Brightness, Color)` replaces 3 near-duplicate blocks

### Cleanup — P2
- **Deleted orphan files:**
  - `lib/core/localization/translations.dart` (barrel, unused)
  - `lib/core/theme/theme.dart` (barrel, unused)
  - `lib/core/localization/en.json`, `ru.json` (stale duplicates of `assets/locales/*`)
  - `lib/quick_commit.bat`, `lib/restart project.bat`
  - `allcode.txt` (added to `.gitignore`)
- `_labeledSlider` orphan body removed from `batch_screen.dart`
