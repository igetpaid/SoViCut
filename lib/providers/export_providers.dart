import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Fast Export (true) or Standard Export (false) is selected.
final fastExportProvider = StateProvider<bool>((ref) => true);

/// Whether the export mode should be persisted across app restarts.
final saveExportModeProvider = StateProvider<bool>((ref) => true);

/// Whether scrub thumbnails on the timeline are visible.
final showScrubThumbnailsProvider = StateProvider<bool>((ref) => true);
