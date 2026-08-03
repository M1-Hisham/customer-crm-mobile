import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DocumentCard extends StatefulWidget {
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
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  double _scale = 1.0;

  void _setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setScale(0.97),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryNavy),
        ),
        title: Text(
          widget.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Text(widget.date, style: const TextStyle(fontSize: 12)),
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
