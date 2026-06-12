class Clip {
  final int id;
  final String sourcePath;
  double startTime;
  double endTime;
  bool isVisible;
  bool isSelected;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'startTime': startTime,
        'endTime': endTime,
        'isVisible': isVisible,
        'isSelected': isSelected,
      };

  factory Clip.fromJson(Map<String, dynamic> json) => Clip(
        id: json['id'] as int,
        sourcePath: json['sourcePath'] as String,
        startTime: (json['startTime'] as num).toDouble(),
        endTime: (json['endTime'] as num).toDouble(),
        isVisible: json['isVisible'] as bool? ?? true,
        isSelected: json['isSelected'] as bool? ?? false,
      );
}
