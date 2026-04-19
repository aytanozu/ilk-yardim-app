import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TrainingCategory {
  basic('basic', 'Temel İlk Yardım'),
  injuries('injuries', 'Yaralanmalar'),
  cardio('cardio', 'Kardiyovasküler'),
  poisoning('poisoning', 'Zehirlenmeler');

  const TrainingCategory(this.key, this.turkish);
  final String key;
  final String turkish;

  static TrainingCategory fromKey(String? key) => values.firstWhere(
        (c) => c.key == key,
        orElse: () => TrainingCategory.basic,
      );
}

enum TrainingType { video, card }

class TrainingItem extends Equatable {
  const TrainingItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    this.thumbnailUrl,
    this.videoUrl,
    this.duration,
    this.viewCount = 0,
    this.featured = false,
  });

  final String id;
  final String title;
  final String description;
  final TrainingCategory category;
  final TrainingType type;
  final String? thumbnailUrl;
  final String? videoUrl;
  final Duration? duration;
  final int viewCount;
  final bool featured;

  String get viewCountDisplay {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    }
    if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(viewCount >= 10000 ? 0 : 1)}B';
    }
    return '$viewCount';
  }

  String get durationDisplay {
    if (duration == null) return '';
    final m = duration!.inMinutes.toString().padLeft(2, '0');
    final s = (duration!.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  factory TrainingItem.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return TrainingItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: TrainingCategory.fromKey(data['category'] as String?),
      type: (data['type'] as String?) == 'card'
          ? TrainingType.card
          : TrainingType.video,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      videoUrl: data['videoUrl'] as String?,
      duration: (data['durationSeconds'] as num?) != null
          ? Duration(seconds: (data['durationSeconds'] as num).toInt())
          : null,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      featured: data['featured'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        type,
        thumbnailUrl,
        videoUrl,
        duration,
        viewCount,
        featured,
      ];
}
