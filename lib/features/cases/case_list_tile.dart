import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A tappable case row that Hero-morphs into [CaseDetailScreen]'s header.
class CaseListTile extends StatefulWidget {
  final String caseId;
  final String title;
  final String client;
  final String status;
  final VoidCallback onTap;

  const CaseListTile({
    super.key,
    required this.caseId,
    required this.title,
    required this.client,
    required this.status,
    required this.onTap,
  });

  @override
  State<CaseListTile> createState() => _CaseListTileState();
}

class _CaseListTileState extends State<CaseListTile> {
  double _scale = 1.0;
  void _setScale(double v) => setState(() => _scale = v);

  Color _statusColor() {
    switch (widget.status) {
      case 'جارية':
        return Colors.green;
      case 'معلقة':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

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
        child: Hero(
          tag: 'case-${widget.caseId}',
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor == const Color(0xFFFFFFFF)
                    ? Colors.white
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _statusColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(widget.client,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left, color: AppTheme.primaryNavy),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
