import 'package:flutter/material.dart';
import '../../core/widgets/staggered_list_item.dart';
import '../../core/navigation/page_transitions.dart';
import 'case_list_tile.dart';
import 'case_detail_screen.dart';

class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  // Placeholder data — replace with real cases from your API/DB.
  static final _cases = [
    {'id': '1', 'title': 'قضية عقارية - شركة النور', 'client': 'أحمد سالم', 'status': 'جارية'},
    {'id': '2', 'title': 'نزاع تجاري - مؤسسة الفا', 'client': 'سارة خالد', 'status': 'معلقة'},
    {'id': '3', 'title': 'قضية عمالية', 'client': 'محمد يوسف', 'status': 'جارية'},
    {'id': '4', 'title': 'استشارة عقود', 'client': 'ليلى عبدالله', 'status': 'مغلقة'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('القضايا')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cases.length,
        itemBuilder: (context, index) {
          final c = _cases[index];
          return StaggeredListItem(
            index: index,
            child: CaseListTile(
              caseId: c['id']!,
              title: c['title']!,
              client: c['client']!,
              status: c['status']!,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute.sharedAxis(
                    page: CaseDetailScreen(
                      caseId: c['id']!,
                      title: c['title']!,
                      client: c['client']!,
                      status: c['status']!,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
