import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../models/debrief_entry.dart';

class DebriefChecklistScreen extends StatefulWidget {
  const DebriefChecklistScreen({
    super.key,
    required this.emergencyId,
    required this.mood,
  });

  final String emergencyId;
  final DebriefMood mood;

  @override
  State<DebriefChecklistScreen> createState() =>
      _DebriefChecklistScreenState();
}

class _DebriefChecklistScreenState extends State<DebriefChecklistScreen> {
  final _wentWell = TextEditingController();
  final _wasHard = TextEditingController();
  final _nextTime = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _wentWell.dispose();
    _wasHard.dispose();
    _nextTime.dispose();
    super.dispose();
  }

  void _continue() {
    context.push(
      '/debrief/${widget.emergencyId}/resources',
      extra: {
        'mood': widget.mood,
        'skipChecklist': false,
        'wentWell': _wentWell.text,
        'wasHard': _wasHard.text,
        'nextTime': _nextTime.text,
        'selfRating': _rating == 0 ? null : _rating,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yansıtma',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Bu vaka ile ilgili kısa bir yansıtma yapın. Alanlar opsiyonel; '
            'yalnız kendiniz okuyabileceksiniz.',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Ne iyi gitti?',
            controller: _wentWell,
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Ne zordu?',
            controller: _wasHard,
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'Bir sonraki sefer ne yaparım?',
            controller: _nextTime,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Kendinizi nasıl değerlendirirsiniz?',
              style: AppTypography.titleSm.copyWith(
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                iconSize: 36,
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color:
                      filled ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryGradientButton(
            label: 'Devam Et',
            icon: Icons.arrow_forward_rounded,
            onPressed: _continue,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: _continue,
            child: const Text('Atla'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      decoration: InputDecoration(labelText: label),
    );
  }
}
