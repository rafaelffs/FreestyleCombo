class UserPreference {
  final String id;
  final String userId;
  final int comboLength;
  final int maxDifficulty;
  final int strongFootPercentage;
  final int noTouchPercentage;
  final int maxConsecutiveNoTouch;
  final bool includeCrossOver;
  final bool includeKnee;
  final List<double> allowedMotions;

  const UserPreference({
    required this.id,
    required this.userId,
    required this.comboLength,
    required this.maxDifficulty,
    required this.strongFootPercentage,
    required this.noTouchPercentage,
    required this.maxConsecutiveNoTouch,
    required this.includeCrossOver,
    required this.includeKnee,
    required this.allowedMotions,
  });

  factory UserPreference.fromJson(Map<String, dynamic> j) => UserPreference(
        id: (j['id'] as String?) ?? '',
        userId: (j['userId'] as String?) ?? '',
        comboLength: j['comboLength'] as int,
        maxDifficulty: j['maxDifficulty'] as int,
        strongFootPercentage: j['strongFootPercentage'] as int,
        noTouchPercentage: j['noTouchPercentage'] as int,
        maxConsecutiveNoTouch: j['maxConsecutiveNoTouch'] as int,
        includeCrossOver: j['includeCrossOver'] as bool,
        includeKnee: j['includeKnee'] as bool,
        allowedMotions: ((j['allowedMotions'] as List<dynamic>?) ?? [])
            .map((m) => (m as num).toDouble())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'comboLength': comboLength,
        'maxDifficulty': maxDifficulty,
        'strongFootPercentage': strongFootPercentage,
        'noTouchPercentage': noTouchPercentage,
        'maxConsecutiveNoTouch': maxConsecutiveNoTouch,
        'includeCrossOver': includeCrossOver,
        'includeKnee': includeKnee,
        'allowedMotions': allowedMotions,
      };

  UserPreference copyWith({
    int? comboLength,
    int? maxDifficulty,
    int? strongFootPercentage,
    int? noTouchPercentage,
    int? maxConsecutiveNoTouch,
    bool? includeCrossOver,
    bool? includeKnee,
  }) =>
      UserPreference(
        id: id,
        userId: userId,
        comboLength: comboLength ?? this.comboLength,
        maxDifficulty: maxDifficulty ?? this.maxDifficulty,
        strongFootPercentage: strongFootPercentage ?? this.strongFootPercentage,
        noTouchPercentage: noTouchPercentage ?? this.noTouchPercentage,
        maxConsecutiveNoTouch: maxConsecutiveNoTouch ?? this.maxConsecutiveNoTouch,
        includeCrossOver: includeCrossOver ?? this.includeCrossOver,
        includeKnee: includeKnee ?? this.includeKnee,
        allowedMotions: allowedMotions,
      );
}
