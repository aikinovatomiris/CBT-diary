class PracticeModel {
  final String id;
  final String title;
  final int durationMinutes;
  final String category;
  final String description;
  final List<String> steps;
  final bool hasTimer;
  final int timerSeconds;

  const PracticeModel({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.category,
    required this.description,
    required this.steps,
    this.hasTimer = false,
    this.timerSeconds = 60,
  });
}