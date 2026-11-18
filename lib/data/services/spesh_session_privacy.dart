/// Session-only identities must not leave credentials in disk image/queue caches.
class SpeshSessionPrivacy {
  static bool isManagedIdentity({
    required String? ownerId,
    required String? activeUserId,
  }) =>
      ownerId != null &&
      ownerId.isNotEmpty &&
      activeUserId != null &&
      activeUserId.isNotEmpty &&
      activeUserId != ownerId;
  static bool managed = false;
  static final Set<String> _tokens = {};
  static void activate(String? token) {
    managed = token != null;
    if (token != null && token.isNotEmpty) _tokens.add(token);
  }

  // Retain retired tokens in memory until process exit: late image requests
  // belonging to the old profile must still bypass disk caching.
  static bool containsToken(String url) => _tokens.any(
    (t) => url.contains(t) || url.contains(Uri.encodeComponent(t)),
  );
}
