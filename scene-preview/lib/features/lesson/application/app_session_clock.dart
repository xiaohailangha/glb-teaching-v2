/// One authenticated app session; a reload or a new login starts a new clock.
class AppSessionClock {
  static String account = '';
  static DateTime? startedAt;
  static void begin(String id) {
    if (id.isEmpty || (account == id && startedAt != null)) return;
    account = id;
    startedAt = DateTime.now();
  }

  static Duration get elapsed =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);
  static void end() {
    account = '';
    startedAt = null;
  }
}
