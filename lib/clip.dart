class Clip {
  final int id;
  final String sourcePath;
  double startTime;   // секунды от начала исходного видео
  double endTime;     // секунды
  bool isVisible;     // видим ли на таймлайне

  Clip({
    required this.id,
    required this.sourcePath,
    required this.startTime,
    required this.endTime,
    this.isVisible = true,
  });

  double get duration => endTime - startTime;

  Clip copyWith({
    int? id,
    String? sourcePath,
    double? startTime,
    double? endTime,
    bool? isVisible,
  }) {
    return Clip(
      id: id ?? this.id,
      sourcePath: sourcePath ?? this.sourcePath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}