import 'package:flutter/material.dart';
import '../../core/widgets/case_summary_card.dart';
import '../../core/widgets/document_card.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/staggered_list_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;

  // Placeholder docs — replace with real data from your API/DB.
  final _docs = [
    {'name': 'عقد إيجار - شركة النور.pdf', 'date': '2 أغسطس 2026'},
    {'name': 'مذكرة دفاع - قضية 245.pdf', 'date': '30 يوليو 2026'},
    {'name': 'إفادة شاهد.pdf', 'date': '28 يوليو 2026'},
  ];

  @override
  void initState() {
    super.initState();
    // Simulates a network/DB fetch — swap for your real data call.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CaseSummaryCard(activeCases: 12, nextSessionDate: '15 أغسطس'),
          const SizedBox(height: 24),
          const Text('أحدث المستندات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (_loading)
            const SkeletonList(count: 3)
          else
            ...List.generate(_docs.length, (index) {
              final d = _docs[index];
              return StaggeredListItem(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DocumentCard(
                    fileName: d['name']!,
                    fileType: 'pdf',
                    date: d['date']!,
                    onTap: () {},
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
