import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';

class CustomPlayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool hasAudioChanges;
  final String? thumbnailPath;
  final VoidCallback? onTapEmpty;

  const CustomPlayer({
    super.key,
    this.controller,
    this.hasAudioChanges = false,
    this.thumbnailPath,
    this.onTapEmpty,
  });

  @override
  State<CustomPlayer> createState() => _CustomPlayerState();
}

class _CustomPlayerState extends State<CustomPlayer> {
  bool _showControls = true;
  bool _showWarning = true;

  @override
  void initState() {
    super.initState();
    _autoHideControls();
    if (widget.hasAudioChanges) {
      _autoHideWarning();
    }
  }

  void _autoHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _autoHideWarning() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _showWarning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.controller == null) {
          widget.onTapEmpty?.call();
          return;
        }
        setState(() {
          _showControls = !_showControls;
        });
        if (_showControls) {
          _autoHideControls();
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideo(),
            _buildPlaceholder(),
            _buildPlayOverlay(),
            if (widget.hasAudioChanges && _showWarning) _buildWarningBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (widget.controller == null || !widget.controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Center(
      child: AspectRatio(
        aspectRatio: widget.controller!.value.aspectRatio,
        child: VideoPlayer(widget.controller!),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.controller != null) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.video_library, size: 28, color: AppColors.textDim),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.t('player.dropVideo'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.t('player.toStart'),
            style: TextStyle(color: AppColors.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayOverlay() {
    if (!_showControls) return const SizedBox.shrink();
    if (widget.controller == null || !widget.controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final isPlaying = widget.controller!.value.isPlaying;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          if (isPlaying) {
            widget.controller!.pause();
          } else {
            widget.controller!.play();
          }
          setState(() {});
        },
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBadge() {
    return Positioned(
      left: 8,
      bottom: 8,
      child: Tooltip(
        message: AppLocalizations.t('player.audioWarningTooltip'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.t('player.audioWarning'),
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
