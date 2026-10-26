import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Premium-only features shown on the paywall.
enum PremiumFeature { aiTutor, scholarZone, analytics }

/// Reads the subscription fields of `users/{uid}`:
///   isPremium: bool, premiumUntil: Timestamp (optional expiry).
/// These fields are writable only by admins / Cloud Functions (see
/// firestore.rules), so a student cannot unlock premium from the client.
class SubscriptionService {
  SubscriptionService._();

  static bool statusFrom(Map<String, dynamic>? data, {DateTime? now}) {
    if (data?['isPremium'] != true) return false;
    final until = data?['premiumUntil'];
    if (until is Timestamp) return until.toDate().isAfter(now ?? DateTime.now());
    return true;
  }

  static DocumentReference<Map<String, dynamic>>? get _doc {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  /// Live status, so a purchase or admin grant unlocks features immediately.
  static Stream<bool> watch() {
    final doc = _doc;
    if (doc == null) return Stream.value(false);
    return doc.snapshots().map((s) => statusFrom(s.data()));
  }

  /// One-off check: server first, then the offline cache.
  /// Any failure counts as not subscribed (fail closed).
  static Future<bool> isUserSubscribed() async {
    final doc = _doc;
    if (doc == null) return false;
    try {
      final snap = await doc.get().timeout(const Duration(seconds: 10));
      return statusFrom(snap.data());
    } catch (_) {
      try {
        final cached = await doc.get(const GetOptions(source: Source.cache));
        return statusFrom(cached.data());
      } catch (_) {
        return false;
      }
    }
  }

  /// Runs [onAllowed] for subscribers, otherwise shows the upgrade dialog.
  /// [firebaseReady] false (local demo mode) leaves everything unlocked.
  static Future<void> guard(
    BuildContext context, {
    required PremiumFeature feature,
    required VoidCallback onAllowed,
    bool firebaseReady = true,
  }) async {
    if (!firebaseReady || await isUserSubscribed()) {
      onAllowed();
      return;
    }
    if (!context.mounted) return;
    await showUpgradeDialog(context, highlight: feature);
  }
}

/// Wraps premium content: shows [child] for subscribers, else a locked card
/// that opens the upgrade dialog.
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.feature,
    required this.child,
  });

  final PremiumFeature feature;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: SubscriptionService.watch(),
      builder: (context, snapshot) {
        if (snapshot.data == true) return child;
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Premium feature / प्रीमियम सुविधा',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      showUpgradeDialog(context, highlight: feature),
                  child: const Text('Upgrade to Premium'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const _benefits = <PremiumFeature, (IconData, String, String)>{
  PremiumFeature.aiTutor: (
    Icons.auto_awesome_rounded,
    'AI Tutor / एआय शिक्षक',
    'Ask doubts and get step-by-step help any time.',
  ),
  PremiumFeature.scholarZone: (
    Icons.emoji_events_rounded,
    'Scholar Zone / स्पर्धा परीक्षा',
    'Scholarship, Navodaya and Sainik School practice tests.',
  ),
  PremiumFeature.analytics: (
    Icons.insights_rounded,
    'Advanced Analytics / प्रगती अहवाल',
    'Detailed progress reports and weak-topic insights.',
  ),
};

/// "Upgrade to Premium" paywall. Textbooks and free content stay unlocked.
Future<void> showUpgradeDialog(
  BuildContext context, {
  PremiumFeature? highlight,
  VoidCallback? onUpgrade,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Upgrade to Premium')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in _benefits.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  selected: entry.key == highlight,
                  leading: Icon(entry.value.$1),
                  title: Text(entry.value.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(entry.value.$3),
                ),
              const SizedBox(height: 8),
              const Text(
                'Textbooks and free lessons stay free for everyone.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (onUpgrade != null) {
                onUpgrade();
              } else {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
                  content: Text(
                      'Contact your school to activate Premium for your account.'),
                ));
              }
            },
            child: const Text('Upgrade'),
          ),
        ],
      );
    },
  );
}
