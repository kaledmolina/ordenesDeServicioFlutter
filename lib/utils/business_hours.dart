class BusinessHours {
  // Hardcoded list of Colombian Holidays for 2024-2025 (Simplified)
  // Ideally this should come from an API or a more robust package.
  static final Set<int> _holidayKeys = {
    // 2025
    20250101, 20250106, 20250324, 20250417, 20250418, 20250501, 20250602, 20250623,
    20250630, 20250720, 20250807, 20250818, 20251013, 20251103, 20251117, 20251208, 20251225,
    // 2026
    20260101, 20260112, 20260323, 20260402, 20260403, 20260501, 20260518, 20260608,
    20260615, 20260720, 20260807, 20260817, 20261012, 20261102, 20261116, 20261208, 20261225,
    // 2027
    20270101, 20270111, 20270322, 20270325, 20270326, 20270501, 20270531, 20270621,
    20270628, 20270720, 20270807, 20270816, 20271018, 20271101, 20271115, 20271208, 20271225,
    // 2028
    20280101, 20280110, 20280320, 20280413, 20280414, 20280501, 20280529, 20280619,
    20280626, 20280703, 20280720, 20280807, 20280821, 20281016, 20281106, 20281113, 20281208, 20281225,
    // 2029
    20290101, 20290108, 20290319, 20290329, 20290330, 20290501, 20290514, 20290604,
    20290611, 20290702, 20290720, 20290807, 20290820, 20291015, 20291105, 20291112, 20291208, 20291225,
  };

  /// Adds [hours] business hours to the [startDate].
  static DateTime add(DateTime startDate, int hours) {
    DateTime result = startDate;
    int hoursAdded = 0;
    while (hoursAdded < hours) {
      result = result.add(const Duration(hours: 1));
      if (_isBusinessTime(result)) {
        hoursAdded++;
      }
    }
    return result;
  }

  static bool _isBusinessTime(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }
    return !_isHoliday(date);
  }

  static bool _isHoliday(DateTime date) {
    final key = date.year * 10000 + date.month * 100 + date.day;
    return _holidayKeys.contains(key);
  }

  /// Calculates business hours elapsed between two dates with O(1) checks
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
