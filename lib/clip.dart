class Clip {
  final int id;
  final String sourcePath;
  double startTime;   // секунды от начала исходного видео
  double endTime;     // секунды
  bool isVisible;     // видим ли на таймлайне (false = удалён, серый)
  bool isSelected;    // выбран ли для операций

  Clip({
    required this.id,
    required this.sourcePath,
    required this.startTime,
    required this.endTime,
    this.isVisible = true,
    this.isSelected = false,
  });

  double get duration => endTime - startTime;

  Clip copyWith({
    int? id,
    String? sourcePath,
    double? startTime,
    double? endTime,
    bool? isVisible,
    bool? isSelected,
  }) {
    return Clip(
      id: id ?? this.id,
      sourcePath: sourcePath ?? this.sourcePath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isVisible: isVisible ?? this.isVisible,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}