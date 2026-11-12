import 'dart:async';

import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/migration/data_access_mode.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notes/data/services/notification_service.dart';
import 'features/notes/domain/services/reminder_sync_service.dart';

class RemindingApp extends StatefulWidget {
  const RemindingApp({super.key});

  @override
  State<RemindingApp> createState() => _RemindingAppState();
}

class _RemindingAppState extends State<RemindingApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _notificationTapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (sl.isRegistered<NotificationService>()) {
      final notificationService = sl<NotificationService>();
      _notificationTapSub = notificationService.onNotificationTapStream.listen(
        _handleNotificationTap,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final launchPayload = notificationService.consumeLaunchPayload();
        if (launchPayload != null && launchPayload.isNotEmpty) {
          _handleNotificationTap(launchPayload);
        }
      });
    }
  }

  @override
  void dispose() {
    _notificationTapSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (sl.isRegistered<DataAccessMode>() &&
          sl<DataAccessMode>().hasMigrationError) {
        return;
      }
      if (sl.isRegistered<ReminderSyncService>()) {
        unawaited(sl<ReminderSyncService>().reconcileAllReminders());
      }
    }
  }

  Future<void> _handleNotificationTap(String payload) async {
    if (!sl.isRegistered<ReminderSyncService>()) return;
    if (sl.isRegistered<DataAccessMode>() &&
        sl<DataAccessMode>().hasMigrationError) {
      return;
    }
    final target = await sl<ReminderSyncService>().resolveNotificationPayload(
      payload,
    );
    if (target == null) return;
    final encodedId = Uri.encodeComponent(target.fileId);
    final encodedFolder = Uri.encodeComponent(target.folderRelativePath);
    unawaited(
      AppRouter.router.push('/list/$encodedId?folder=$encodedFolder'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataAccessMode =
        sl.isRegistered<DataAccessMode>() ? sl<DataAccessMode>() : null;

    if (dataAccessMode == null) {
      return _buildRouterApp();
    }

    return AnimatedBuilder(
      animation: dataAccessMode,
      builder: (context, _) {
        if (dataAccessMode.hasMigrationError) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: _MigrationErrorScreen(
              errorMessage: dataAccessMode.migrationError ??
                  'Terjadi kesalahan saat memigrasi data.',
            ),
          );
        }
        return _buildRouterApp();
      },
    );
  }

  Widget _buildRouterApp() {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = mediaQuery.textScaler.clamp(
          maxScaleFactor: AppConstants.maxTextScaleFactor,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _MigrationErrorScreen extends StatelessWidget {
  final String errorMessage;

  const _MigrationErrorScreen({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('migration_error_screen'),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gagal Memigrasi Data',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Proses pembaruan format data gagal. Seluruh berkas telah dikembalikan ke kondisi semula dan aplikasi tidak menimpa data apa pun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
