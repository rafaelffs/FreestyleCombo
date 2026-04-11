class TrickSubmissionDto {
  final String id;
  final String name;
  final String abbreviation;
  final bool crossOver;
  final bool knee;
  final double revolution;
  final int difficulty;
  final int commonLevel;
  final String status;
  final DateTime submittedAt;
  final String submittedByUserName;
  final DateTime? reviewedAt;

  const TrickSubmissionDto({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.crossOver,
    required this.knee,
    required this.revolution,
    required this.difficulty,
    required this.commonLevel,
    required this.status,
    required this.submittedAt,
    required this.submittedByUserName,
    this.reviewedAt,
  });

  factory TrickSubmissionDto.fromJson(Map<String, dynamic> json) =>
      TrickSubmissionDto(
        id: json['id'] as String,
        name: json['name'] as String,
        abbreviation: json['abbreviation'] as String,
        crossOver: json['crossOver'] as bool,
        knee: json['knee'] as bool,
        revolution: (json['revolution'] as num).toDouble(),
        difficulty: json['difficulty'] as int,
        commonLevel: json['commonLevel'] as int,
        status: json['status'] as String,
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        submittedByUserName: json['submittedByUserName'] as String,
        reviewedAt: json['reviewedAt'] == null
            ? null
            : DateTime.parse(json['reviewedAt'] as String),
      );
}
