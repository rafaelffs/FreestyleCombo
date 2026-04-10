class ComboTrickDto {
  final String trickId;
  final String name;
  final String abbreviation;
  final int position;
  final bool strongFoot;
  final bool noTouch;
  final int difficulty;
  final double motion;

  const ComboTrickDto({
    required this.trickId,
    required this.name,
    required this.abbreviation,
    required this.position,
    required this.strongFoot,
    required this.noTouch,
    required this.difficulty,
    required this.motion,
  });

  factory ComboTrickDto.fromJson(Map<String, dynamic> j) => ComboTrickDto(
        trickId: j['trickId'] as String,
        name: j['name'] as String,
        abbreviation: j['abbreviation'] as String,
        position: j['position'] as int,
        strongFoot: j['strongFoot'] as bool,
        noTouch: j['noTouch'] as bool,
        difficulty: j['difficulty'] as int,
        motion: (j['motion'] as num).toDouble(),
      );
}

class ComboDto {
  final String id;
  final String ownerId;
  final String? ownerEmail;
  final double averageDifficulty;
  final int trickCount;
  final bool? isPublic;
  final String createdAt;
  final String displayText;
  final String? aiDescription;
  final List<ComboTrickDto>? tricks;
  final double averageRating;
  final int totalRatings;

  const ComboDto({
    required this.id,
    required this.ownerId,
    this.ownerEmail,
    required this.averageDifficulty,
    required this.trickCount,
    this.isPublic,
    required this.createdAt,
    required this.displayText,
    this.aiDescription,
    this.tricks,
    required this.averageRating,
    required this.totalRatings,
  });

  factory ComboDto.fromJson(Map<String, dynamic> j) => ComboDto(
        id: j['id'] as String,
        ownerId: j['ownerId'] as String,
        ownerEmail: j['ownerEmail'] as String?,
        averageDifficulty: (j['averageDifficulty'] as num).toDouble(),
        trickCount: j['trickCount'] as int,
        isPublic: j['isPublic'] as bool?,
        createdAt: j['createdAt'] as String,
        displayText: j['displayText'] as String,
        aiDescription: j['aiDescription'] as String?,
        tricks: (j['tricks'] as List<dynamic>?)
            ?.map((t) => ComboTrickDto.fromJson(t as Map<String, dynamic>))
            .toList(),
        averageRating: (j['averageRating'] as num? ?? 0).toDouble(),
        totalRatings: j['totalRatings'] as int? ?? 0,
      );
}

class PagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const PagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
}

class GenerateComboOverrides {
  final int? comboLength;
  final int? maxDifficulty;
  final int? strongFootPercentage;
  final int? noTouchPercentage;
  final int? maxConsecutiveNoTouch;
  final bool? includeCrossOver;
  final bool? includeKnee;

  const GenerateComboOverrides({
    this.comboLength,
    this.maxDifficulty,
    this.strongFootPercentage,
    this.noTouchPercentage,
    this.maxConsecutiveNoTouch,
    this.includeCrossOver,
    this.includeKnee,
  });

  Map<String, dynamic> toJson() => {
        if (comboLength != null) 'comboLength': comboLength,
        if (maxDifficulty != null) 'maxDifficulty': maxDifficulty,
        if (strongFootPercentage != null) 'strongFootPercentage': strongFootPercentage,
        if (noTouchPercentage != null) 'noTouchPercentage': noTouchPercentage,
        if (maxConsecutiveNoTouch != null) 'maxConsecutiveNoTouch': maxConsecutiveNoTouch,
        if (includeCrossOver != null) 'includeCrossOver': includeCrossOver,
        if (includeKnee != null) 'includeKnee': includeKnee,
      };
}
