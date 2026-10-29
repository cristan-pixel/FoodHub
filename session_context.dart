// lib/services/session_context.dart
//
// A dependency-free snapshot of "who is signed in right now". Other
// services (AppData's notification hooks, dashboards) read it without
// importing any auth service, which keeps the import graph acyclic.

enum SessionRole { customer, rider, restaurant, admin }

class SessionContext {
  SessionContext._();

  static SessionRole? role;
  static String? email;
  static String? name;

  static bool get isSignedIn => role != null && (email?.isNotEmpty ?? false);

  static void set({
    required SessionRole role,
    required String email,
    String? name,
  }) {
    SessionContext.role = role;
    SessionContext.email = email;
    SessionContext.name = name;
  }

  static void clear() {
    role = null;
    email = null;
    name = null;
  }
}
