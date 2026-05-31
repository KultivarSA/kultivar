import 'package:flutter/material.dart' show Color, IconData, Icons;
import '../theme/app_colors.dart';
import 'training_details.dart';
export 'training_details.dart';

enum NoteCategory {
  observation,
  issue,
  milestone,
  watering,
  feeding,
  ipm,
  training,
  measurement,
  transplant,
  other,
}

/// Colour and icon for each note category.
/// Single source of truth — used by both [PlantNote] and any widget
/// that needs to colour-code a category without an existing note instance.
extension NoteCategoryExt on NoteCategory {
  Color get color {
    switch (this) {
      case NoteCategory.observation:
        return AppColors.info;
      case NoteCategory.issue:
        return AppColors.danger;
      case NoteCategory.milestone:
        return AppColors.growing;
      case NoteCategory.watering:
        return AppColors.water;
      case NoteCategory.feeding:
        return AppColors.curing;
      case NoteCategory.ipm:
        return AppColors.ipmColor;
      case NoteCategory.training:
        return AppColors.training;
      case NoteCategory.measurement:
        return AppColors.secondary;
      case NoteCategory.transplant:
        return AppColors.growing;
      case NoteCategory.other:
        return AppColors.textMuted;
    }
  }

  IconData get icon {
    // Glyph pass — every category gets the rounded variant where one
    // exists, plus a couple of direct upgrades:
    //   • milestone  →  emoji_events (trophy).  The flag glyph read as
    //                   "report problem" to several test users, blunting
    //                   the celebratory intent.
    //   • watering   →  water_drop (was opacity — generic alpha glyph).
    //   • feeding    →  eco_rounded (was restaurant — wrong domain).
    //   • ipm        →  pest_control (literal Material icon for IPM).
    //   • issue      →  report_problem (was warning — too easily
    //                   confused with the "removed" lifecycle event).
    switch (this) {
      case NoteCategory.observation:
        return Icons.visibility_rounded;
      case NoteCategory.issue:
        return Icons.report_problem_rounded;
      case NoteCategory.milestone:
        return Icons.emoji_events_rounded;
      case NoteCategory.watering:
        return Icons.water_drop_rounded;
      case NoteCategory.feeding:
        return Icons.eco_rounded;
      case NoteCategory.ipm:
        return Icons.pest_control_rounded;
      case NoteCategory.training:
        return Icons.content_cut_rounded;
      case NoteCategory.measurement:
        return Icons.straighten_rounded;
      case NoteCategory.transplant:
        return Icons.move_up_rounded;
      case NoteCategory.other:
        return Icons.notes_rounded;
    }
  }

  String get categoryLabel {
    switch (this) {
      case NoteCategory.observation:
        return 'Observation';
      case NoteCategory.issue:
        return 'Issue';
      case NoteCategory.milestone:
        return 'Milestone';
      case NoteCategory.watering:
        return 'Watering';
      case NoteCategory.feeding:
        return 'Feeding';
      case NoteCategory.ipm:
        return 'IPM';
      case NoteCategory.training:
        return 'Training';
      case NoteCategory.measurement:
        return 'Measurement';
      case NoteCategory.transplant:
        return 'Transplant';
      case NoteCategory.other:
        return 'Other';
    }
  }
}

// ── Feeding log details ───────────────────────────

class FeedingDetails {
  final double? waterVolumeLitres;
  final double? phIn;
  final double? ecIn;
  final double? nitrogen;
  final double? phosphorus;
  final double? potassium;
  final String? productName;
  final String? amendments;

  const FeedingDetails({
    this.waterVolumeLitres,
    this.phIn,
    this.ecIn,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.productName,
    this.amendments,
  });

  Map<String, dynamic> toJson() => {
        'waterVolumeLitres': waterVolumeLitres,
        'phIn': phIn,
        'ecIn': ecIn,
        'nitrogen': nitrogen,
        'phosphorus': phosphorus,
        'potassium': potassium,
        'productName': productName,
        'amendments': amendments,
      };

  factory FeedingDetails.fromJson(Map<String, dynamic> json) => FeedingDetails(
        waterVolumeLitres: (json['waterVolumeLitres'] as num?)?.toDouble(),
        phIn: (json['phIn'] as num?)?.toDouble(),
        ecIn: (json['ecIn'] as num?)?.toDouble(),
        nitrogen: (json['nitrogen'] as num?)?.toDouble(),
        phosphorus: (json['phosphorus'] as num?)?.toDouble(),
        potassium: (json['potassium'] as num?)?.toDouble(),
        productName: json['productName'],
        amendments: json['amendments'],
      );
}

// ── Watering log details ──────────────────────────

class WateringDetails {
  final double? volumeLitres;
  final double? phIn;
  final double? runoffPh;

  const WateringDetails({
    this.volumeLitres,
    this.phIn,
    this.runoffPh,
  });

  Map<String, dynamic> toJson() => {
        'volumeLitres': volumeLitres,
        'phIn': phIn,
        'runoffPh': runoffPh,
      };

  factory WateringDetails.fromJson(Map<String, dynamic> json) =>
      WateringDetails(
        volumeLitres: (json['volumeLitres'] as num?)?.toDouble(),
        phIn: (json['phIn'] as num?)?.toDouble(),
        runoffPh: (json['runoffPh'] as num?)?.toDouble(),
      );
}

// ── IPM log details ───────────────────────────────

class IpmDetails {
  final String? product;
  final String? targetPest;
  final String? method; // spray | drench | foliar
  final double? dilutionRatio;

  const IpmDetails({
    this.product,
    this.targetPest,
    this.method,
    this.dilutionRatio,
  });

  Map<String, dynamic> toJson() => {
        'product': product,
        'targetPest': targetPest,
        'method': method,
        'dilutionRatio': dilutionRatio,
      };

  factory IpmDetails.fromJson(Map<String, dynamic> json) => IpmDetails(
        product: json['product'],
        targetPest: json['targetPest'],
        method: json['method'],
        dilutionRatio: (json['dilutionRatio'] as num?)?.toDouble(),
      );
}

// ── PlantNote ─────────────────────────────────────

class PlantNote {
  final String id;
  final String plantId;
  final DateTime createdAt;
  final String content;
  final NoteCategory category;
  final String? issueName;
  final List<String> photoUrls;
  final bool isResolved; // ✅ new
  final DateTime? resolvedAt; // ✅ new

  final FeedingDetails? feedingDetails;
  final WateringDetails? wateringDetails;
  final IpmDetails? ipmDetails;
  final TrainingDetails? trainingDetails;

  /// Height measurement in centimetres. Set when category == measurement
  /// (or optionally alongside any other note type).
  final double? heightCm;

  /// New pot size in litres. Set when category == transplant.
  /// Also triggers an update to Plant.potSizeLitres when saved.
  final double? newPotSizeLitres;

  /// F7 — voice memo attachments.  Stored as bare filenames under the
  /// app's Documents directory (same pattern as [photoUrls]).  The
  /// `record` package writes m4a/AAC on mobile and WAV on desktop; the
  /// extension is preserved so playback can pick the right codec.
  final List<String> audioUrls;

  /// F8 — free-form labels.  Lower-cased, dedup'd, no leading `#`.
  /// Examples: `mother`, `test-pheno`, `sog-trial`.  Used by the
  /// search screen and the Notes tab filter chips.
  final List<String> tags;

  PlantNote({
    required this.id,
    required this.plantId,
    required this.createdAt,
    required this.content,
    required this.category,
    this.issueName,
    List<String>? photoUrls,
    this.isResolved = false,
    this.resolvedAt,
    this.feedingDetails,
    this.wateringDetails,
    this.ipmDetails,
    this.trainingDetails,
    this.heightCm,
    this.newPotSizeLitres,
    List<String>? audioUrls,
    List<String>? tags,
  })  : photoUrls = photoUrls ?? [],
        audioUrls = audioUrls ?? [],
        tags = tags ?? [];

  PlantNote copyWith({
    String? content,
    NoteCategory? category,
    String? issueName,
    List<String>? photoUrls,
    bool? isResolved,
    DateTime? resolvedAt,
    FeedingDetails? feedingDetails,
    WateringDetails? wateringDetails,
    IpmDetails? ipmDetails,
    TrainingDetails? trainingDetails,
    double? heightCm,
    double? newPotSizeLitres,
    List<String>? audioUrls,
    List<String>? tags,
  }) {
    return PlantNote(
      id: id,
      plantId: plantId,
      createdAt: createdAt,
      content: content ?? this.content,
      category: category ?? this.category,
      issueName: issueName ?? this.issueName,
      photoUrls: photoUrls ?? this.photoUrls,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      feedingDetails: feedingDetails ?? this.feedingDetails,
      wateringDetails: wateringDetails ?? this.wateringDetails,
      ipmDetails: ipmDetails ?? this.ipmDetails,
      trainingDetails: trainingDetails ?? this.trainingDetails,
      heightCm: heightCm ?? this.heightCm,
      newPotSizeLitres: newPotSizeLitres ?? this.newPotSizeLitres,
      audioUrls: audioUrls ?? this.audioUrls,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
        'category': category.name,
        'issueName': issueName,
        'photoUrls': photoUrls,
        'isResolved': isResolved,
        'resolvedAt': resolvedAt?.toIso8601String(),
        'feedingDetails': feedingDetails?.toJson(),
        'wateringDetails': wateringDetails?.toJson(),
        'ipmDetails': ipmDetails?.toJson(),
        'trainingDetails': trainingDetails?.toJson(),
        'heightCm': heightCm,
        'newPotSizeLitres': newPotSizeLitres,
        'audioUrls': audioUrls,
        'tags': tags,
      };

  factory PlantNote.fromJson(Map<String, dynamic> json) => PlantNote(
        id: json['id'],
        plantId: json['plantId'],
        createdAt: DateTime.parse(json['createdAt']),
        content: json['content'],
        category: NoteCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => NoteCategory.other,
        ),
        issueName: json['issueName'],
        photoUrls: (json['photoUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        isResolved: json['isResolved'] ?? false,
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'])
            : null,
        feedingDetails: json['feedingDetails'] != null
            ? FeedingDetails.fromJson(json['feedingDetails'])
            : null,
        wateringDetails: json['wateringDetails'] != null
            ? WateringDetails.fromJson(json['wateringDetails'])
            : null,
        ipmDetails: json['ipmDetails'] != null
            ? IpmDetails.fromJson(json['ipmDetails'])
            : null,
        trainingDetails: json['trainingDetails'] != null
            ? TrainingDetails.fromJson(json['trainingDetails'])
            : null,
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        newPotSizeLitres: (json['newPotSizeLitres'] as num?)?.toDouble(),
        audioUrls: (json['audioUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  // Category helpers unchanged below...
  String get categoryLabel {
    switch (category) {
      case NoteCategory.observation:
        return 'Observation';
      case NoteCategory.issue:
        return 'Issue';
      case NoteCategory.milestone:
        return 'Milestone';
      case NoteCategory.watering:
        return 'Watering';
      case NoteCategory.feeding:
        return 'Feeding';
      case NoteCategory.ipm:
        return 'IPM';
      case NoteCategory.training:
        return 'Training';
      case NoteCategory.measurement:
        return 'Measurement';
      case NoteCategory.transplant:
        return 'Transplant';
      case NoteCategory.other:
        return 'Other';
    }
  }

  Color get categoryColor => category.color;

  IconData get categoryIcon => category.icon;
}
