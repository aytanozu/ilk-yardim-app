import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';

const REGION = 'europe-west3';

interface BadgeRule {
  id: string;
  label: string;
  /** Returns true iff the stats snapshot satisfies the award threshold. */
  qualifies: (stats: { interventions: number; educationPoints: number }) => boolean;
}

/**
 * Badge definitions must mirror the display catalog in
 * `lib/features/profile/widgets/badge_row.dart`. If you add one here,
 * add it there too (and vice versa).
 */
const BADGE_RULES: BadgeRule[] = [
  {
    id: 'life_saver',
    label: 'Hayat Kurtaran',
    qualifies: (s) => s.interventions >= 1,
  },
  {
    id: 'rapid_response',
    label: 'Hızlı Müdahale',
    qualifies: (s) => s.interventions >= 10,
  },
  {
    id: 'trainer',
    label: 'Eğitmen',
    qualifies: (s) => s.educationPoints >= 100,
  },
  {
    id: 'trainer_plus',
    label: 'Uzman Eğitmen',
    qualifies: (s) => s.educationPoints >= 500,
  },
];

interface Streak {
  weeklyActiveWeeks: number;
  lastActiveWeekIso: string;
}

function toStreak(
  data: admin.firestore.DocumentData | undefined,
): Streak {
  const s = (data?.streaks ?? {}) as Record<string, unknown>;
  return {
    weeklyActiveWeeks: Number(s.weeklyActiveWeeks ?? 0),
    lastActiveWeekIso: String(s.lastActiveWeekIso ?? ''),
  };
}

/// True if `next` is exactly one ISO week after `prev`. Empty `prev`
/// (first activity ever) is treated as non-consecutive, so the counter
/// starts at 1 on the very first qualifying action.
function isConsecutiveIsoWeek(prev: string, next: string): boolean {
  if (!prev) return false;
  // Parse "YYYY-Www" back into a monday-of-week Date and diff by 7 days.
  const parsePrev = parseIsoWeek(prev);
  const parseNext = parseIsoWeek(next);
  if (parsePrev == null || parseNext == null) return false;
  const diffDays =
    (parseNext.getTime() - parsePrev.getTime()) / 86400000;
  return diffDays === 7;
}

function parseIsoWeek(key: string): Date | null {
  const m = /^(\d{4})-W(\d{2})$/.exec(key);
  if (!m) return null;
  const year = Number(m[1]);
  const week = Number(m[2]);
  // Jan 4th is always in ISO week 1.
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const jan4Day = jan4.getUTCDay() || 7;
  const week1Monday = new Date(jan4);
  week1Monday.setUTCDate(jan4.getUTCDate() - (jan4Day - 1));
  const targetMonday = new Date(week1Monday);
  targetMonday.setUTCDate(week1Monday.getUTCDate() + (week - 1) * 7);
  return targetMonday;
}

function isoWeekKey(date: Date): string {
  // ISO week-date format YYYY-Www. Good enough for bucketing — no DST
  // edge-cases matter at week granularity.
  const tmp = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  const dayNum = tmp.getUTCDay() || 7;
  tmp.setUTCDate(tmp.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(tmp.getUTCFullYear(), 0, 1));
  const week = Math.ceil(
    ((tmp.getTime() - yearStart.getTime()) / 86400000 + 1) / 7,
  );
  return `${tmp.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

function toStats(data: admin.firestore.DocumentData | undefined): {
  interventions: number;
  educationPoints: number;
} {
  const stats = (data?.stats ?? {}) as Record<string, unknown>;
  return {
    interventions: Number(stats.interventions ?? 0),
    educationPoints: Number(stats.educationPoints ?? 0),
  };
}

/**
 * On every user doc update, diff stats thresholds and award any newly
 * qualified badges via `arrayUnion`. Idempotent — already-earned badges
 * are filtered out. A `case_updated`-style data FCM ping could be added
 * later to surface a toast client-side.
 */
export const onUserStatsUpdate = onDocumentUpdated(
  { region: REGION, document: 'users/{uid}' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    const beforeStats = toStats(before);
    const afterStats = toStats(after);

    // Short-circuit if no stat counter moved forward.
    const statsAdvanced =
      afterStats.interventions > beforeStats.interventions ||
      afterStats.educationPoints > beforeStats.educationPoints;
    if (!statsAdvanced) return;

    // --- Streak maintenance ---
    // If this update represents a "fresh" activity (intervention or
    // education gain), bump the weekly streak counter when the ISO week
    // changed since last activity. Reset to 1 if the gap is more than
    // one week.
    const beforeStreak = toStreak(before);
    const nowIso = isoWeekKey(new Date());
    let afterStreak = beforeStreak;
    if (beforeStreak.lastActiveWeekIso !== nowIso) {
      const consecutive = isConsecutiveIsoWeek(
        beforeStreak.lastActiveWeekIso,
        nowIso,
      );
      afterStreak = {
        weeklyActiveWeeks: consecutive
          ? beforeStreak.weeklyActiveWeeks + 1
          : 1,
        lastActiveWeekIso: nowIso,
      };
    }

    const existingBadges = new Set<string>(
      Array.isArray(after.badges) ? (after.badges as string[]) : [],
    );
    const newlyEarned: string[] = [];
    for (const rule of BADGE_RULES) {
      if (existingBadges.has(rule.id)) continue;
      if (!rule.qualifies(beforeStats) && rule.qualifies(afterStats)) {
        newlyEarned.push(rule.id);
      }
    }

    // Streak-based badge: crosses 4 weeks for the first time.
    if (
      !existingBadges.has('streak_4w') &&
      afterStreak.weeklyActiveWeeks >= 4 &&
      beforeStreak.weeklyActiveWeeks < 4
    ) {
      newlyEarned.push('streak_4w');
    }

    const needsWrite =
      newlyEarned.length > 0 ||
      afterStreak.lastActiveWeekIso !== beforeStreak.lastActiveWeekIso ||
      afterStreak.weeklyActiveWeeks !== beforeStreak.weeklyActiveWeeks;
    if (!needsWrite) return;

    const writePayload: Record<string, unknown> = {
      streaks: {
        weeklyActiveWeeks: afterStreak.weeklyActiveWeeks,
        lastActiveWeekIso: afterStreak.lastActiveWeekIso,
      },
    };
    if (newlyEarned.length > 0) {
      writePayload.badges =
        FieldValue.arrayUnion(...newlyEarned);
    }
    await event.data!.after.ref.update(writePayload);

    if (newlyEarned.length === 0) return;

    logger.info('Awarded badges', {
      uid: event.params.uid,
      badges: newlyEarned,
    });

    // Surface to the user via FCM data push if any tokens exist.
    const tokens = (after.fcmTokens as string[] | undefined) ?? [];
    if (tokens.length === 0) return;
    try {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: 'Yeni rozet kazandınız',
          body: newlyEarned
            .map((id) => BADGE_RULES.find((r) => r.id === id)?.label ?? id)
            .join(', '),
        },
        data: {
          type: 'badge_earned',
          badges: newlyEarned.join(','),
        },
        android: { priority: 'normal' },
      });
    } catch (e) {
      logger.warn('badge push failed', { err: (e as Error).message });
    }
  },
);
