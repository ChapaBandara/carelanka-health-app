class GreetingHelper {
  static String timeGreeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  static String dashboardTitle(String firstName, [DateTime? now]) {
    return '${timeGreeting(now)}, $firstName';
  }
}
