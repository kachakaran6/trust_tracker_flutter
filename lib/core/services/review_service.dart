import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class ReviewService {
  final Ref ref;
  final InAppReview _inAppReview = InAppReview.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static const String _prefReviewRequested = 'reviewRequested';
  static const String _prefReviewCompleted = 'reviewCompleted';
  static const String _prefLastReviewPromptDate = 'lastReviewPromptDate';
  static const String _prefAppOpenCount = 'appOpenCount';

  static const int _minAppOpens = 5;
  static const int _daysBetweenPrompts = 90;

  ReviewService(this.ref);

  /// Call this when the app starts up
  Future<void> logAppOpen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int openCount = prefs.getInt(_prefAppOpenCount) ?? 0;
    openCount++;
    await prefs.setInt(_prefAppOpenCount, openCount);

    if (openCount >= _minAppOpens) {
      await _checkAndShowReviewPrompt(context, trigger: 'app_open');
    }
  }

  /// Call this after a meaningful action (e.g., save link, create category)
  Future<void> logMeaningfulAction(BuildContext context, {required String action}) async {
    await _checkAndShowReviewPrompt(context, trigger: 'action_$action');
  }

  Future<void> _checkAndShowReviewPrompt(BuildContext context, {required String trigger}) async {
    final prefs = await SharedPreferences.getInstance();
    
    final bool reviewCompleted = prefs.getBool(_prefReviewCompleted) ?? false;
    if (reviewCompleted) return; // User already reviewed

    final String? lastPromptStr = prefs.getString(_prefLastReviewPromptDate);
    if (lastPromptStr != null) {
      final DateTime lastPromptDate = DateTime.parse(lastPromptStr);
      final DateTime now = DateTime.now();
      final difference = now.difference(lastPromptDate).inDays;
      
      // Maximum 1 prompt every 90 days
      if (difference < _daysBetweenPrompts) return;
    }

    await prefs.setString(_prefLastReviewPromptDate, DateTime.now().toIso8601String());
    await prefs.setBool(_prefReviewRequested, true);

    _analytics.logEvent(name: 'review_prompt_shown', parameters: {'trigger': trigger});

    if (!context.mounted) return;
    await _launchGooglePlayReview();
  }

  Future<void> _launchGooglePlayReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return;
      } else {
        await _inAppReview.openStoreListing(appStoreId: '', microsoftStoreId: '');
      }
    } catch (e) {
      debugPrint('Error launching review: $e');
    }
  }

  /// For testing or manual triggers in settings
  Future<void> forceShowReviewPrompt(BuildContext context) async {
    await _checkAndShowReviewPrompt(context, trigger: 'manual_force');
  }
}

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService(ref);
});
