import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class CaseSummaryCard extends StatelessWidget {
  final int activeCases;
  final String nextSessionDate;

  const CaseSummaryCard({
    super.key,
    required this.activeCases,
    required this.nextSessionDate,
  });

  @override
  Widget build(BuildContext context) {
    return _content(context)
        .animate()
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }

  Widget _content(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ملخص المكتب القانوني',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Icon(Icons.gavel, color: AppTheme.secondaryGold),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('القضايا النشطة', '$activeCases'),
              Container(height: 30, width: 1, color: Colors.white24),
              _buildStatItem('الجلسة القادمة', nextSessionDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
