import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const _viewCountKey = 'pdf_view_count';
  static const _hasRequestedReviewKey = 'has_requested_review';
  static const int _viewsBeforeReview = 5;

  /// Call this every time a user opens a PDF.
  /// After 5 views, prompts the in-app review dialog (once).
  static Future<void> trackViewAndMaybeRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRequested = prefs.getBool(_hasRequestedReviewKey) ?? false;
    if (hasRequested) return;

    final count = (prefs.getInt(_viewCountKey) ?? 0) + 1;
    await prefs.setInt(_viewCountKey, count);

    if (count >= _viewsBeforeReview) {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setBool(_hasRequestedReviewKey, true);
      }
    }
  }
}
