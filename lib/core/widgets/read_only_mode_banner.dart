import 'package:flutter/material.dart';

import '../di/injection_container.dart';
import '../migration/data_access_mode.dart';

class ReadOnlyModeBanner extends StatelessWidget {
  const ReadOnlyModeBanner({super.key});

  static const String message =
      'Data dibuat oleh versi aplikasi yang lebih baru. Mode baca saja.';

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<DataAccessMode>()) {
      return const SizedBox.shrink();
    }
    final mode = sl<DataAccessMode>();
    return AnimatedBuilder(
      animation: mode,
      builder: (context, _) {
        if (!mode.isReadOnly) {
          return const SizedBox.shrink();
        }
        return Container(
          key: const Key('read_only_mode_banner'),
          width: double.infinity,
          color: const Color(0xFFFFF4E5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: Color(0xFFB45309),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
