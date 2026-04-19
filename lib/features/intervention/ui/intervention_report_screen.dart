import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../data/intervention_repo.dart';
import '../models/intervention_report.dart';

/// Form a responder fills out after arriving at a scene. Records what
/// interventions were performed + patient condition + optional notes.
/// Submits via the `recordIntervention` Cloud Function.
class InterventionReportScreen extends StatefulWidget {
  const InterventionReportScreen({
    super.key,
    required this.emergencyId,
  });

  final String emergencyId;

  @override
  State<InterventionReportScreen> createState() =>
      _InterventionReportScreenState();
}

class _InterventionReportScreenState extends State<InterventionReportScreen> {
  final _repo = InterventionRepo();
  final _notesCtrl = TextEditingController();
  PatientCondition _condition = PatientCondition.stable;
  final Set<String> _actions = {};
  bool _submitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      await _repo.submit(InterventionReport(
        emergencyId: widget.emergencyId,
        uid: uid,
        condition: _condition,
        actions: _actions,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapor kaydedildi. Kendinize iyi bakın.'),
          backgroundColor: AppColors.tertiary,
        ),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydedilemedi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Müdahale Raporu',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Olay yerinde neler yaptınız ve hastanın durumu ne? '
            'Bu rapor sadece ekipte tutulur ve müdahale kalitesinin '
            'iyileştirilmesine yardımcı olur.',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
              icon: Icons.medical_services_rounded, title: 'Uygulanan müdahaleler'),
          for (final (key, label) in kActionOptions)
            CheckboxListTile(
              value: _actions.contains(key),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _actions.add(key);
                } else {
                  _actions.remove(key);
                }
              }),
              title: Text(label),
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
              icon: Icons.monitor_heart_rounded, title: 'Hasta durumu'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: PatientCondition.values.map((c) {
              final selected = _condition == c;
              return ChoiceChip(
                label: Text(kConditionLabels[c]!),
                selected: selected,
                onSelected: (_) => setState(() => _condition = c),
                selectedColor: AppColors.primary.withOpacity(0.18),
                labelStyle: TextStyle(
                  color:
                      selected ? AppColors.primary : AppColors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(icon: Icons.notes_rounded, title: 'Notlar'),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Örn: Hasta bilinci açıldı · ambulans 8 dakikada ulaştı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryGradientButton(
            label: _submitting ? 'Gönderiliyor…' : 'Raporu Gönder',
            icon: Icons.send_rounded,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Şimdi değil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(title,
              style: AppTypography.titleSm.copyWith(
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}
