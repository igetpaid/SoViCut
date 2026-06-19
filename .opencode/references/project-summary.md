# SoViCut - Project Summary

## Goal
Flutter Windows desktop app for video/audio clipping. Load video, extract audio tracks, create clips (A-B segments), trim, export via FFmpeg.

## Stack
- Flutter (Dart) — Windows desktop target
- Riverpod — state management (ConsumerStatefulWidget)
- FFmpeg — audio extraction + export + thumbnail generation
- Material Design — custom dark theme (AppColors)

## Architecture
```
HomeScreen (ConsumerStatefulWidget)
  ├── Toolbar — mode switcher + file ops
  ├── MainLayout
  │   ├── Preview (Expanded) + Stack(spinner overlay top-right)
  │   ├── Resizable Divider (draggable, 250-500px)
  │   └── Right Panel (SizedBox, tabbed: Audio/Clips/Trim/Export)
  └── Timeline — scrub bar + clip segments + thumbnail preview on drag only
      ├── Always-visible bar (disabled: gray 0.35 opacity + --:--)
      ├── Tick marks (9 interior lines) via _TicksPainter
      └── Time labels (11 labels) via _TimeLabelsPainter (TextPainter)
```

Audio, Clips, Trim, Export tabs rendered as right panel content switched by `_appMode`.

## Key Decisions
- **Settings persistence**: `%APPDATA%/SoViCut/settings.json` saves language, theme, export mode, scrub thumbnails toggle. Loaded before `runApp()` for zero-flash startup.
- **Export mode provider**: `fastExportProvider` + `saveExportModeProvider` + `showScrubThumbnailsProvider`. Initialized from settings in main.dart overrides.
- **Seek spinner**: 100ms delay on click (no spinner if seek < 100ms), 300ms minimum on drag. Differentiated via `fromDrag` parameter. Positioned top-right (24x24), no dark overlay.
- **Thumbnails**: single-pass `-vf fps=1,scale=320:180` with `-threads 2` to reduce CPU contention (not 3600 separate ffmpeg calls).
- **Right panel width resizable**: 250-500px, global-position tracking with start-width capture for 1:1 drag response independent of widget rebuilds.
- **Export button**: split button (bolt icon + dropdown arrow) in bottom toolbar, right-aligned with Step controls. Two options: Fast Export / Standard Export.
- **Tab order**: Audio → Clips → Trim → Export (by frequency of use).
- **Russian locale**: `фрагмент` → `отрезок` (9 entries). English `clip` kept unchanged. `1f` → `1 frame` / `1 кадр` (step.frame key).
- **`ref.listen`** must be in `build()` on ConsumerStatefulWidget, not in `didChangeDependencies` (Flutter assertion error otherwise).
- **PopupMenuButton** inside bare Row needs menu items wrapped in `Material(color: Colors.transparent)` to avoid ink splash warning.
- **Always-visible controls**: Split/Delete/Restore buttons always shown (disabled via `onTap: null` + 0.4 opacity when no clips). Layout never shifts.
- **Toolbar layout**: Step selector → Nav buttons (back/forward in circle, 6px spacing) → Action buttons. Icons: `chevron_left`/`chevron_right`.
- **Timeline disabled state**: gray background bar with 0.35 opacity, `AbsorbPointer`, time shows `--:--`. Always visible even without video.
- **Timeline bar dimensions**: container height 56px, scrub bar 12px thick. Tick marks (9 interior) below bar. Time labels (11) via TextPainter centered on tick positions.
- **Thumbnail preview on timeline**: shown only on drag (onHorizontalDragStart/Update), NOT on click (onTapDown).
- **Git workflow**: "сделай коммит" = commit only; "сделай коммит и пуш" = commit + push. Recorded in AGENTS.md.

## Current State
- Audio extraction (FFmpeg) working
- Clip creation from video working
- Trim functionality working
- Export (fast FFmpeg preset / quality preset) working
- Locale switching (EN/RU) working
- Resizable divider between preview and right panel working (250-500px)
- Settings persistence: theme, language, export mode, scrub thumbnails saved to AppData
- Thumbnails: single-pass FFmpeg fps=1 with thread limit (not 3600 separate processes)
- Seek spinner: top-right, 100ms delay click / 300ms min drag, no dark overlay
- Scrub thumbnails toggle: on/off in settings panel
- Timeline: always-visible disabled bar, tick marks + time labels via CustomPainter
- Toolbar: always-visible action buttons, nav icons in circle, stable layout
- `flutter analyze`: 0 errors, 0 warnings
- Better Program skill: updated with SoViCut lessons (6 new entries across all reference files)

## Next Steps
- (user will decide)

## Security Notes
- All file paths from user input
- FFmpeg CLI arguments — be careful with special chars
- Temporary files created in system temp dir
