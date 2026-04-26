import 'package:flutter/material.dart';

class FinancialUtils {
  /// Calculates the start and end dates of the current cycle based on a custom start day.
  static DateTimeRange getCurrentCycleRange(int startDay) {
    final now = DateTime.now();
    if (now.day >= startDay) {
      return getCycleRangeForMonth(now.year, now.month, startDay);
    } else {
      return getCycleRangeForMonth(now.year, now.month - 1, startDay);
    }
  }

  /// Calculates the start and end dates of a specific cycle based on a custom start day.
  /// Example: year=2024, month=3, startDay=5 -> Range(5 Mar 2024, 4 Apr 2024)
  static DateTimeRange getCycleRangeForMonth(int year, int month, int startDay) {
    // Normalize month in case it's 0 (January-1)
    DateTime baseDate = DateTime(year, month, 1);
    final startDate = DateTime(baseDate.year, baseDate.month, startDay);
    final endDate = _getEndOfCycle(baseDate.year, baseDate.month, startDay);
    return DateTimeRange(start: startDate, end: endDate);
  }

  static DateTime _getEndOfCycle(int year, int month, int startDay) {
    // The cycle ends on (startDay - 1) of the next month.
    // If we start on 5th March, we end on 4th April.
    // However, if startDay is 31 and next month has 30 days, we should adjust.
    
    DateTime nextMonth = DateTime(year, month + 1, 1);
    int daysInNextMonth = DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month);
    
    int endDay = startDay - 1;
    if (endDay < 1) {
      // If startDay is 1, endDay is technically the last day of the current month.
      // But our logic for startDay=1 should be 1st to end-of-month.
      // Actually, if startDay = 1, startDate = 1st, endDate = last day of same month.
      return DateTime(year, month, DateUtils.getDaysInMonth(year, month), 23, 59, 59);
    }
    
    // Clamp endDay to days in next month
    if (endDay > daysInNextMonth) endDay = daysInNextMonth;
    
    return DateTime(nextMonth.year, nextMonth.month, endDay, 23, 59, 59);
  }
}
