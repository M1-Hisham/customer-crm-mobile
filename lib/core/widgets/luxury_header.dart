import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../main.dart';

class LuxuryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget>? actions;

  const LuxuryHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 18),
      decoration: const BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => MainAppController.scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  padding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.secondaryGold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryGold.withOpacity(0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.secondaryGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ],
      ),
    );
  }
}
