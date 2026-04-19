import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../providers/quiz_session_provider.dart';
import '../widgets/answer_option_tile.dart';
import '../widgets/quiz_progress_bar.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key, required this.quizId});
  final String quizId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QuizSessionProvider(quizId: quizId)..load(),
      child: const _QuizBody(),
    );
  }
}

class _QuizBody extends StatelessWidget {
  const _QuizBody();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<QuizSessionProvider>();
    if (session.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (session.completed) {
      return _QuizResult(score: session.score, total: session.questions.length);
    }
    final question = session.current;
    if (question == null) {
      return const Scaffold(
        body: Center(child: Text('Sorular yüklenemedi')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'KLİNİK NABIZ',
          style: AppTypography.titleLg.copyWith(letterSpacing: 3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              QuizProgressBar(
                index: session.index,
                total: session.questions.length,
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  question.text,
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView.separated(
                  itemCount: question.options.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => Selector<QuizSessionProvider, int?>(
                    selector: (_, p) => p.selectedOption,
                    builder: (ctx, selected, __) => AnswerOptionTile(
                      text: question.options[i],
                      selected: selected == i,
                      onTap: () => ctx.read<QuizSessionProvider>().select(i),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryGradientButton(
                label: session.index == session.questions.length - 1
                    ? 'Bitir'
                    : 'Sonraki Soru',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: session.selectedOption == null
                    ? null
                    : () => context.read<QuizSessionProvider>().next(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  const _QuizResult({required this.score, required this.total});
  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : ((score / total) * 100).round();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.emoji_events_rounded,
                  color: AppColors.tertiary, size: 80),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Quiz Tamamlandı',
                style: AppTypography.displaySm.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$score / $total doğru · $pct%',
                style: AppTypography.titleLg.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppSpacing.borderLg,
                ),
                child: Text(
                  '+${score * 10} Eğitim Puanı',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              PrimaryGradientButton(
                label: 'Eğitim Merkezine Dön',
                onPressed: () => context.go('/training'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
