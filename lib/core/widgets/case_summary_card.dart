import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class CaseSummaryCard extends StatelessWidget {
  final int activeCases;
  final String nextSessionDate;

  const CaseSummaryCard({
    super.key,
    required this.activeCases,
    required this.nextSessionDate,
  });

  String _formatSessionDate(String rawDate) {
    if (rawDate.isEmpty || rawDate == 'لا يوجد' || rawDate == 'غير مجدولة') {
      return 'لا توجد جلسات قادمة';
    }
    try {
      final dt = DateTime.parse(rawDate);
      final now = DateTime.now();
      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      
      final timeStr = DateFormat('hh:mm a', 'ar').format(dt);
      if (isToday) {
        return 'اليوم، $timeStr';
      }
      final dateStr = DateFormat('dd/MM', 'ar').format(dt);
      return '$dateStr | $timeStr';
    } catch (_) {
      if (rawDate.contains('T')) {
        return rawDate.split('T')[0];
      }
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatSessionDate(nextSessionDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: AppTheme.secondaryGold, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ملخص المكتب القانوني',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.secondaryGold, size: 12),
                    SizedBox(width: 4),
                    Text('نظام آمن', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('القضايا النشطة', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '$activeCases قضية',
                        style: const TextStyle(
                          color: AppTheme.secondaryGold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 36, width: 1, color: Colors.white24),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الجلسة القادمة', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 350.ms, curve: Curves.easeOut)
    .slideY(begin: 0.05, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}
