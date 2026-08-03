import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DocumentCard extends StatelessWidget {
  final String fileName;
  final String fileType;
  final String date;
  final VoidCallback onTap;

  const DocumentCard({
    super.key,
    required this.fileName,
    required this.fileType,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryNavy),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Text(date, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            const Icon(Icons.lock_outline, size: 14, color: Colors.green),
            const SizedBox(width: 2),
            const Text(
              'مشفّر',
              style: TextStyle(fontSize: 11, color: Colors.green),
            ),
          ],
        ),
        trailing: const Icon(Icons.download_rounded, size: 20),
      ),
    );
  }
}
