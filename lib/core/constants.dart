class AppConstants {
  AppConstants._();

  static const String appName = 'SoViCut';
  static const String appVersion = '2.0.0';

  static const double minClipDuration = 0.5;
  static const double defaultTrimSeconds = 10.0;
  static const int defaultAudioBitrate = 192000;
  static const int defaultSampleRate = 48000;
  static const int defaultChannels = 2;

  static const double scrubThumbnailInterval = 1.0;
  static const int scrubThumbnailWidth = 320;
  static const int scrubThumbnailHeight = 180;

  static const double lufsTargetYoutube = -14.0;
  static const double lufsTargetTv = -23.0;
  static const double lufsTargetPodcast = -16.0;

  static const int batchMaxConcurrentJobs = 4;
  static const int batchMaxFiles = 1000;
}
