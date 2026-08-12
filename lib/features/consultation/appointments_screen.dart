import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/staggered_list_item.dart';
import 'appointment_card.dart';
import 'status_tab_bar.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentModel {
  final String title;
  final String date;
  final String time;
  final int hours;
  final int minutes;
  final double price;
  final AppointmentStatus status;

  const _AppointmentModel({
    required this.title,
    required this.date,
    required this.time,
    required this.hours,
    required this.minutes,
    required this.price,
    required this.status,
  });
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  AppointmentStatus _selected = AppointmentStatus.upcoming;

  final _appointments = const [
    _AppointmentModel(
      title: 'استشارة قانونية',
      date: '11-10-2022',
      time: '9:00 AM',
      hours: 1,
      minutes: 14,
      price: 149,
      status: AppointmentStatus.upcoming,
    ),
    _AppointmentModel(
      title: 'استشارة قانونية',
      date: '11-10-2022',
      time: '9:00 AM',
      hours: 5,
      minutes: 14,
      price: 149,
      status: AppointmentStatus.upcoming,
    ),
    _AppointmentModel(
      title: 'استشارة قانونية',
      date: '11-10-2022',
      time: '9:00 AM',
      hours: 5,
      minutes: 14,
      price: 99,
      status: AppointmentStatus.completed,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _appointments.where((a) => a.status == _selected).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
        centerTitle: true,
        title: const Text('المواعيد',
            style: TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: StatusTabBar(
              selected: _selected,
              onChanged: (s) => setState(() => _selected = s),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('لا توجد مواعيد',
                        style: TextStyle(color: AppTheme.mutedText, fontSize: 14)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final a = filtered[index];
                      return StaggeredListItem(
                        index: index,
                        child: AppointmentCard(
                          title: a.title,
                          date: a.date,
                          time: a.time,
                          hours: a.hours,
                          minutes: a.minutes,
                          price: a.price,
                          status: a.status,
                          onDetailsTap: () {},
                          onCallTap: () {},
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
