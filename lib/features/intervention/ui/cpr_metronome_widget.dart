import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 110 BPM CPR metronome — guides chest compressions at the AHA-recommended
/// rate. Emits a haptic pulse on each beat plus a synced visual pulse.
///
/// Compression cycle model:
///   - 30 compressions → "Nefes ver x2" prompt → 30 compressions → repeat
///   - BPM 110 → interval ≈ 545 ms
///   - During the 2-breath rest, the metronome pauses ~5 s before
///     resuming (the typical recovery window).
///
/// Audio is intentionally optional. Initial release is haptic + visual
/// only; an `assets/audio/metronome_click.mp3` can be wired to
/// `audioplayers` in a follow-up without changing this API.
class CprMetronomeWidget extends StatefulWidget {
  const CprMetronomeWidget({super.key});

  @override
  State<CprMetronomeWidget> createState() => _CprMetronomeWidgetState();
}

class _CprMetronomeWidgetState extends State<CprMetronomeWidget>
    with SingleTickerProviderStateMixin {
  static const _bpm = 110;
  static const _beatInterval = Duration(milliseconds: 545); // 60000/110
  static const _compressionsPerCycle = 30;
  static const _breathPause = Duration(seconds: 5);

  Timer? _beatTimer;
  int _beatCount = 0;
  bool _isRunning = false;
  bool _inBreathPause = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.95,
      upperBound: 1.15,
    );
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _start() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _beatCount = 0;
      _inBreathPause = false;
    });
    _scheduleBeat();
  }

  void _stop() {
    _beatTimer?.cancel();
    setState(() {
      _isRunning = false;
      _inBreathPause = false;
    });
  }

  void _scheduleBeat() {
    _beatTimer = Timer.periodic(_beatInterval, (_) {
      if (!_isRunning) return;
      _tick();
    });
  }

  Future<void> _tick() async {
    if (_inBreathPause) return;
    HapticFeedback.mediumImpact();
    // Fire-and-forget the pulse animation.
    _pulse.forward().then((_) => _pulse.reverse());
    setState(() => _beatCount++);
    if (_beatCount % _compressionsPerCycle == 0) {
      // Entering breath rest.
      setState(() => _inBreathPause = true);
      await Future<void>.delayed(_breathPause);
      if (!_isRunning) return;
      setState(() => _inBreathPause = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cyclePos = _beatCount % _compressionsPerCycle;
    final compressionNum = cyclePos == 0 && _beatCount > 0
        ? _compressionsPerCycle
        : cyclePos;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: AppSpacing.borderLg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text('CPR · $_bpm BPM',
                  style: AppTypography.titleMd.copyWith(
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                _inBreathPause
                    ? '2 nefes ver'
                    : '$compressionNum / $_compressionsPerCycle',
                style: AppTypography.titleSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _inBreathPause
                    ? AppColors.secondary.withOpacity(0.18)
                    : AppColors.primary.withOpacity(0.18),
                border: Border.all(
                  color: _inBreathPause
                      ? AppColors.secondary
                      : AppColors.primary,
                  width: 3,
                ),
              ),
              child: Icon(
                _inBreathPause
                    ? Icons.air_rounded
                    : Icons.compress_rounded,
                size: 48,
                color: _inBreathPause
                    ? AppColors.secondary
                    : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _inBreathPause
                ? 'Hastaya 2 kurtarıcı nefes verin, sonra 30 baskıya devam'
                : 'Göğüs kemiğine dik bastırın · sternum 5-6 cm derin',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(_isRunning ? 'DURDUR' : 'BAŞLAT'),
              onPressed: _isRunning ? _stop : _start,
              style: FilledButton.styleFrom(
                backgroundColor:
                    _isRunning ? AppColors.error : AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                textStyle: AppTypography.titleSm.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
