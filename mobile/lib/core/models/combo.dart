class TrickDto {
  final String id;
  final String name;
  final String abbreviation;
  final bool crossOver;
  final bool knee;
  final double revolution;
  final int difficulty;
  final int commonLevel;

  const TrickDto({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.crossOver,
    required this.knee,
    required this.revolution,
    required this.difficulty,
    required this.commonLevel,
  });

  factory TrickDto.fromJson(Map<String, dynamic> j) => TrickDto(
        id: j['id'] as String,
        name: j['name'] as String,
        abbreviation: j['abbreviation'] as String,
        crossOver: j['crossOver'] as bool,
        knee: j['knee'] as bool,
        revolution: (j['revolution'] as num).toDouble(),
        difficulty: j['difficulty'] as int,
        commonLevel: j['commonLevel'] as int,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'abbreviation': abbreviation,
        'crossOver': crossOver,
        'knee': knee,
        'revolution': revolution,
        'difficulty': difficulty,
        'commonLevel': commonLevel,
      };
}

class BuildComboTrickItem {
  final String trickId;
  final int position;
  final bool strongFoot;
  final bool noTouch;

  const BuildComboTrickItem({
    required this.trickId,
    required this.position,
    required this.strongFoot,
    required this.noTouch,
  });

  Map<String, dynamic> toJson() => {
        'trickId': trickId,
        'position': position,
        'strongFoot': strongFoot,
        'noTouch': noTouch,
      };
}

class ComboTrickDto {
  final String trickId;
  final String name;
  final String abbreviation;
  final int position;
  final bool strongFoot;
  final bool noTouch;
  final int difficulty;
  final double revolution;

  const ComboTrickDto({
    required this.trickId,
    required this.name,
    required this.abbreviation,
    required this.position,
    required this.strongFoot,
    required this.noTouch,
    required this.difficulty,
    required this.revolution,
  });

  factory ComboTrickDto.fromJson(Map<String, dynamic> j) => ComboTrickDto(
        trickId: j['trickId'] as String,
        name: j['name'] as String,
        abbreviation: j['abbreviation'] as String,
        position: j['position'] as int,
        strongFoot: j['strongFoot'] as bool,
        noTouch: j['noTouch'] as bool,
        difficulty: j['difficulty'] as int,
        revolution: (j['revolution'] as num).toDouble(),
      );
}

class ComboDto {
  final String id;
  final String ownerId;
  final String? ownerUserName;
  final String? name;
  final double averageDifficulty;
  final int trickCount;
  final bool? isPublic;
  final String? visibility;
  final String createdAt;
  final String displayText;
  final String? aiDescription;
  final List<ComboTrickDto>? tricks;
  final double averageRating;
  final int totalRatings;
  final bool isFavourited;
  final bool isCompleted;
  final int completionCount;

  const ComboDto({
    required this.id,
    required this.ownerId,
    this.ownerUserName,
    this.name,
    required this.averageDifficulty,
    required this.trickCount,
    this.isPublic,
    this.visibility,
    required this.createdAt,
    required this.displayText,
    this.aiDescription,
    this.tricks,
    required this.averageRating,
    required this.totalRatings,
    this.isFavourited = false,
    this.isCompleted = false,
    this.completionCount = 0,
  });

  factory ComboDto.fromJson(Map<String, dynamic> j) => ComboDto(
        id: j['id'] as String,
        ownerId: j['ownerId'] as String,
        ownerUserName: j['ownerUserName'] as String?,
        name: j['name'] as String?,
        averageDifficulty: (j['averageDifficulty'] as num).toDouble(),
        trickCount: j['trickCount'] as int,
        isPublic: j['isPublic'] as bool?,
        visibility: j['visibility'] as String?,
        createdAt: j['createdAt'] as String,
        displayText: j['displayText'] as String,
        aiDescription: j['aiDescription'] as String?,
        tricks: (j['tricks'] as List<dynamic>?)
            ?.map((t) => ComboTrickDto.fromJson(t as Map<String, dynamic>))
            .toList(),
        averageRating: (j['averageRating'] as num? ?? 0).toDouble(),
        totalRatings: j['totalRatings'] as int? ?? 0,
        isFavourited: j['isFavourited'] as bool? ?? false,
        isCompleted: j['isCompleted'] as bool? ?? false,
        completionCount: j['completionCount'] as int? ?? 0,
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

class PreviewTrickItem {
  final String trickId;
  final String trickName;
  final String abbreviation;
  final int position;
  final bool strongFoot;
  final bool noTouch;
  final int difficulty;
  final bool crossOver;
  final double revolution;

  const PreviewTrickItem({
    required this.trickId,
    required this.trickName,
    required this.abbreviation,
    required this.position,
    required this.strongFoot,
    required this.noTouch,
    required this.difficulty,
    required this.crossOver,
    required this.revolution,
  });

  factory PreviewTrickItem.fromJson(Map<String, dynamic> j) => PreviewTrickItem(
        trickId: j['trickId'] as String,
        trickName: j['trickName'] as String,
        abbreviation: j['abbreviation'] as String,
        position: j['position'] as int,
        strongFoot: j['strongFoot'] as bool,
        noTouch: j['noTouch'] as bool,
        difficulty: j['difficulty'] as int,
        crossOver: j['crossOver'] as bool,
        revolution: (j['revolution'] as num).toDouble(),
      );
}

class PreviewComboResponse {
  final List<PreviewTrickItem> tricks;
  final List<String> warnings;

  const PreviewComboResponse({required this.tricks, required this.warnings});

  factory PreviewComboResponse.fromJson(Map<String, dynamic> j) => PreviewComboResponse(
        tricks: (j['tricks'] as List<dynamic>)
            .map((t) => PreviewTrickItem.fromJson(t as Map<String, dynamic>))
            .toList(),
        warnings: (j['warnings'] as List<dynamic>).cast<String>(),
      );
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
