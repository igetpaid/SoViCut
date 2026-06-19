# SoViCut - Project Summary

## Goal
Flutter Windows desktop app for video/audio clipping. Load video, extract audio tracks, create clips (A-B segments), trim, export via FFmpeg.

## Stack
- Flutter (Dart) — Windows desktop target
- Riverpod — state management (ConsumerStatefulWidget)
- FFmpeg — audio extraction + export
- Material Design — custom dark theme (AppColors)

## Architecture
```
HomeScreen (ConsumerStatefulWidget)
  ├── Toolbar — mode switcher + file ops
  ├── MainLayout
  │   ├── Preview (Expanded)
  │   ├── Resizable Divider (draggable)
  │   └── Right Panel (SizedBox, 250-500px)
  └── Timeline — video timeline + clips display
```

Audio, Clips, Trim, Export tabs rendered as right panel content switched by `_appMode`.

## Key Decisions
- **Right panel width resizable**: 250-500px, global-position tracking with start-width capture for 1:1 drag response.
- **Export button**: split button (bolt icon + dropdown arrow) in bottom toolbar, right-aligned with Step controls. Two options: Fast Export / Standard Export.
- **Tab order**: Audio → Clips → Trim → Export (by frequency of use).
- **Russian locale**: `фрагмент` → `отрезок` (9 entries). English `clip` kept unchanged.
- **Fast start**: `startproject.bat` — incremental `flutter run -d windows` without `flutter clean`. Full clean in `restart project.bat`.
- **`ref.listen`** must be in `build()` on ConsumerStatefulWidget, not in `didChangeDependencies` (Flutter assertion error otherwise).
- **PopupMenuButton** inside bare Row needs menu items wrapped in `Material(color: Colors.transparent)` to avoid ink splash warning.

## Current State
- Audio extraction (FFmpeg) working
- Clip creation from video working
- Trim functionality working
- Export (fast FFmpeg preset / quality preset) working
- Locale switching (EN/RU) working
- Resizable divider between preview and right panel working (250-500px)
- `flutter analyze`: 0 errors, 0 warnings

## Next Steps
- (user will decide)

## Security Notes
- All file paths from user input
- FFmpeg CLI arguments — be careful with special chars
- Temporary files created in system temp dir
