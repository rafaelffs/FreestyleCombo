class UserPreference {
  final String id;
  final String userId;
  final String name;
  final int comboLength;
  final int maxDifficulty;
  final int strongFootPercentage;
  final int noTouchPercentage;
  final int maxConsecutiveNoTouch;
  final bool includeCrossOver;
  final bool includeKnee;
  final List<double> allowedRevolutions;
  final int? maxHighRevolutionTricks;
  final List<String> allowedTrickIds;

  const UserPreference({
    required this.id,
    required this.userId,
    required this.name,
    required this.comboLength,
    required this.maxDifficulty,
    required this.strongFootPercentage,
    required this.noTouchPercentage,
    required this.maxConsecutiveNoTouch,
    required this.includeCrossOver,
    required this.includeKnee,
    required this.allowedRevolutions,
    this.maxHighRevolutionTricks,
    this.allowedTrickIds = const [],
  });

  factory UserPreference.fromJson(Map<String, dynamic> j) => UserPreference(
        id: (j['id'] as String?) ?? '',
        userId: (j['userId'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        comboLength: j['comboLength'] as int,
        maxDifficulty: j['maxDifficulty'] as int,
        strongFootPercentage: j['strongFootPercentage'] as int,
        noTouchPercentage: j['noTouchPercentage'] as int,
        maxConsecutiveNoTouch: j['maxConsecutiveNoTouch'] as int,
        includeCrossOver: j['includeCrossOver'] as bool,
        includeKnee: j['includeKnee'] as bool,
        allowedRevolutions:
          ((j['allowedRevolutions'] as List<dynamic>?) ??
              (j['allowedMotions'] as List<dynamic>?) ??
              [])
            .map((m) => (m as num).toDouble())
            .toList(),
        maxHighRevolutionTricks: j['maxHighRevolutionTricks'] as int?,
        allowedTrickIds: ((j['allowedTrickIds'] as List<dynamic>?) ?? [])
            .map((id) => id as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'comboLength': comboLength,
        'maxDifficulty': maxDifficulty,
        'strongFootPercentage': strongFootPercentage,
        'noTouchPercentage': noTouchPercentage,
        'maxConsecutiveNoTouch': maxConsecutiveNoTouch,
        'includeCrossOver': includeCrossOver,
        'includeKnee': includeKnee,
        'allowedRevolutions': allowedRevolutions,
        'maxHighRevolutionTricks': maxHighRevolutionTricks,
        'allowedTrickIds': allowedTrickIds,
      };

  UserPreference copyWith({
    String? name,
    int? comboLength,
    int? maxDifficulty,
    int? strongFootPercentage,
    int? noTouchPercentage,
    int? maxConsecutiveNoTouch,
    bool? includeCrossOver,
    bool? includeKnee,
    List<double>? allowedRevolutions,
    int? maxHighRevolutionTricks,
    List<String>? allowedTrickIds,
  }) =>
      UserPreference(
        id: id,
        userId: userId,
        name: name ?? this.name,
        comboLength: comboLength ?? this.comboLength,
        maxDifficulty: maxDifficulty ?? this.maxDifficulty,
        strongFootPercentage: strongFootPercentage ?? this.strongFootPercentage,
        noTouchPercentage: noTouchPercentage ?? this.noTouchPercentage,
        maxConsecutiveNoTouch: maxConsecutiveNoTouch ?? this.maxConsecutiveNoTouch,
        includeCrossOver: includeCrossOver ?? this.includeCrossOver,
        includeKnee: includeKnee ?? this.includeKnee,
        allowedRevolutions: allowedRevolutions ?? this.allowedRevolutions,
        maxHighRevolutionTricks: maxHighRevolutionTricks ?? this.maxHighRevolutionTricks,
        allowedTrickIds: allowedTrickIds ?? this.allowedTrickIds,
      );
}
