/// Tracks whether the "Build combo" screen currently has an in-progress,
/// unsaved combo — so other navigation entry points (the bottom nav) can
/// warn before silently discarding it. A plain static flag, matching this
/// app's existing manual-singleton pattern (no state management library).
class UnsavedComboGuard {
  UnsavedComboGuard._();

  static int pendingTrickCount = 0;

  static bool get hasUnsavedWork => pendingTrickCount > 0;

  static void clear() => pendingTrickCount = 0;
}
