import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'appointment_card.dart';

class StatusTabBar extends StatelessWidget {
  final AppointmentStatus selected;
  final ValueChanged<AppointmentStatus> onChanged;

  const StatusTabBar({super.key, required this.selected, required this.onChanged});

  static const _labels = {
    AppointmentStatus.cancelled: 'تم الغائها',
    AppointmentStatus.completed: 'المكتملة',
    AppointmentStatus.upcoming: 'القادمة',
  };

  @override
  Widget build(BuildContext context) {
    // Reference layout order (RTL): cancelled, completed, upcoming (active, pill-highlighted)
    final order = [
      AppointmentStatus.cancelled,
      AppointmentStatus.completed,
      AppointmentStatus.upcoming,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: order.map((status) {
        final isActive = status == selected;
        return GestureDetector(
          onTap: () => onChanged(status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.cardCream : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: isActive
                  ? Border.all(color: AppTheme.goldText.withValues(alpha: 0.4))
                  : null,
            ),
            child: Text(
              _labels[status]!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppTheme.goldText : AppTheme.mutedText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
