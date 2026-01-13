class BusinessHours {
  // Hardcoded list of Colombian Holidays for 2024-2025 (Simplified)
  // Ideally this should come from an API or a more robust package.
  static final List<DateTime> _holidays = [
    // 2025
    DateTime(2025, 1, 1),
    DateTime(2025, 1, 6),
    DateTime(2025, 3, 24),
    DateTime(2025, 4, 17),
    DateTime(2025, 4, 18),
    DateTime(2025, 5, 1),
    DateTime(2025, 6, 2),
    DateTime(2025, 6, 23),
    DateTime(2025, 6, 30),
    DateTime(2025, 7, 20),
    DateTime(2025, 8, 7),
    DateTime(2025, 8, 18),
    DateTime(2025, 10, 13),
    DateTime(2025, 11, 3),
    DateTime(2025, 11, 17),
    DateTime(2025, 12, 8),
    DateTime(2025, 12, 25),

    // 2026
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 12),
    DateTime(2026, 3, 23),
    DateTime(2026, 4, 2),
    DateTime(2026, 4, 3),
    DateTime(2026, 5, 1),
    DateTime(2026, 5, 18),
    DateTime(2026, 6, 8),
    DateTime(2026, 6, 15),
    DateTime(2026, 7, 20),
    DateTime(2026, 8, 7),
    DateTime(2026, 8, 17),
    DateTime(2026, 10, 12),
    DateTime(2026, 11, 2),
    DateTime(2026, 11, 16),
    DateTime(2026, 12, 8),
    DateTime(2026, 12, 25),

    // 2027
    DateTime(2027, 1, 1),
    DateTime(2027, 1, 11),
    DateTime(2027, 3, 22),
    DateTime(2027, 3, 25),
    DateTime(2027, 3, 26),
    DateTime(2027, 5, 1),
    DateTime(2027, 5, 31),
    DateTime(2027, 6, 21),
    DateTime(2027, 6, 28),
    DateTime(2027, 7, 20),
    DateTime(2027, 8, 7),
    DateTime(2027, 8, 16),
    DateTime(2027, 10, 18),
    DateTime(2027, 11, 1),
    DateTime(2027, 11, 15),
    DateTime(2027, 12, 8),
    DateTime(2027, 12, 25),

    // 2028
    DateTime(2028, 1, 1),
    DateTime(2028, 1, 10),
    DateTime(2028, 3, 20),
    DateTime(2028, 4, 13),
    DateTime(2028, 4, 14),
    DateTime(2028, 5, 1),
    DateTime(2028, 5, 29),
    DateTime(2028, 6, 19),
    DateTime(2028, 6, 26),
    DateTime(2028, 7, 3),
    DateTime(2028, 7, 20),
    DateTime(2028, 8, 7),
    DateTime(2028, 8, 21),
    DateTime(2028, 10, 16),
    DateTime(2028, 11, 6),
    DateTime(2028, 11, 13),
    DateTime(2028, 12, 8),
    DateTime(2028, 12, 25),

    // 2029
    DateTime(2029, 1, 1),
    DateTime(2029, 1, 8),
    DateTime(2029, 3, 19),
    DateTime(2029, 3, 29),
    DateTime(2029, 3, 30),
    DateTime(2029, 5, 1),
    DateTime(2029, 5, 14),
    DateTime(2029, 6, 4),
    DateTime(2029, 6, 11),
    DateTime(2029, 7, 2),
    DateTime(2029, 7, 20),
    DateTime(2029, 8, 7),
    DateTime(2029, 8, 20),
    DateTime(2029, 10, 15),
    DateTime(2029, 11, 5),
    DateTime(2029, 11, 12),
    DateTime(2029, 12, 8),
    DateTime(2029, 12, 25),
  ];

  /// Adds [hours] business hours to the [startDate].
  /// Skips Saturdays, Sundays, and Holidays.
  /// Note: This adds *calendar time* until 48 business hours are accumulated.
  /// Simplification: We treat "Business Hours" as "Any time on a Business Day".
  /// So 48 business hours = 2 Business Days if we count 24h per day.
  /// BUT usually SLAs mean "Work hours" (8am-5pm). 
  /// The user said "48 hours", usually implying 2 full days.
  /// If I submit on Friday at 4PM, do I have until Tuesday 4PM?
  /// Yes, that is standard 48h SLA excluding weekends.
  static DateTime add(DateTime startDate, int hours) {
    DateTime result = startDate;
    int hoursAdded = 0;
    
    // Iterate hour by hour to be safe and accurate enough for this simple requirement
    // Optimization: we could jump by days, but iterating hours is cleaner to write for edge cases like starting on Sunday.
    // However, 48 hours is small enough to loop.
    
    while (hoursAdded < hours) {
      result = result.add(const Duration(hours: 1));
      if (_isBusinessTime(result)) {
        hoursAdded++;
      }
    }
    return result;
  }

  static bool _isBusinessTime(DateTime date) {
    // Check Weekend
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }
    
    // Check Holiday
    if (_isHoliday(date)) {
      return false;
    }
    
    return true;
  }

  static bool _isHoliday(DateTime date) {
    for (var holiday in _holidays) {
      if (date.year == holiday.year && 
          date.month == holiday.month && 
          date.day == holiday.day) {
        return true;
      }
    }
    return false;
  }

  /// Calculates business hours elapsed between two dates
  static int getElapsedHours(DateTime start, DateTime end) {
    if (start.isAfter(end)) return 0;
    
    int elapsed = 0;
    DateTime current = start;
    
    // Limit to prevent infinite loops if dates are far apart (safety)
    int safety = 0;
    while (current.isBefore(end) && safety < 10000) {
      current = current.add(const Duration(hours: 1));
      if (_isBusinessTime(current)) {
        elapsed++;
      }
      safety++;
    }
    return elapsed;
  }
}
