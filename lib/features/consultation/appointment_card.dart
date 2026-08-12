import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum AppointmentStatus { upcoming, completed, cancelled }

class AppointmentCard extends StatefulWidget {
  final String title; // e.g. 'استشارة قانونية'
  final String date; // e.g. '11-10-2022'
  final String time; // e.g. '9:00 AM'
  final int hours;
  final int minutes;
  final double price;
  final AppointmentStatus status;
  final VoidCallback onDetailsTap;
  final VoidCallback onCallTap;

  const AppointmentCard({
    super.key,
    required this.title,
    required this.date,
    required this.time,
    required this.hours,
    required this.minutes,
    required this.price,
    required this.status,
    required this.onDetailsTap,
    required this.onCallTap,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  double _scale = 1.0;
  void _setScale(double v) => setState(() => _scale = v);

  @override
  Widget build(BuildContext context) {
    final isUpcoming = widget.status == AppointmentStatus.upcoming;

    return GestureDetector(
      onTapDown: (_) => _setScale(0.985),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      onTap: widget.onDetailsTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardCream,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duration chips + title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('${widget.hours.toString().padLeft(2, '0')} ساعة'),
                        _chip('${widget.minutes} دقيقة'),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppTheme.goldText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Date / time row + "تاريخ الموعد" label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.date,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 6),
                        const Icon(Icons.access_time, size: 14, color: AppTheme.mutedText),
                        const SizedBox(width: 4),
                        Text(widget.time,
                            style: const TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                      ],
                    ),
                  ),
                  const Text('تاريخ الموعد',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                ],
              ),
              const SizedBox(height: 6),
              // Price row + "رسوم الاستشارة" label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.price.toStringAsFixed(0)} SAR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Text('رسوم الاستشارة',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                ],
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDetailsTap,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryNavy),
                        foregroundColor: AppTheme.primaryNavy,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('تفاصيل الاستشارة',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  if (isUpcoming) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onCallTap,
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('إجراء مكالمة',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: AppTheme.secondaryGold,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.chipCream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldText.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: AppTheme.goldText, fontWeight: FontWeight.w600)),
    );
  }
}
