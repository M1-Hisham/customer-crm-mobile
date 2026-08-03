import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class CaseDetailScreen extends StatelessWidget {
  final String caseId;
  final String title;
  final String client;
  final String status;

  const CaseDetailScreen({
    super.key,
    required this.caseId,
    required this.title,
    required this.client,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppTheme.primaryNavy,
            flexibleSpace: FlexibleSpaceBar(
              // Same Hero tag as CaseListTile — the card morphs into this header.
              background: Hero(
                tag: 'case-$caseId',
                child: Container(
                  color: AppTheme.primaryNavy,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  alignment: Alignment.bottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(title,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(client, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionCard('الحالة', status, Icons.flag_outlined, 0),
                _sectionCard('آخر تحديث', 'منذ يومين', Icons.update, 1),
                _sectionCard('المستندات المرتبطة', '4 مستندات', Icons.folder_open, 2),
                _sectionCard('الجلسة القادمة', '15 أغسطس 2026', Icons.event, 3),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String label, String value, IconData icon, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.secondaryGold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: (100 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
