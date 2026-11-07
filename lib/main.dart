import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/seeder/demo_seeder.dart';
import 'features/explorer/domain/repositories/explorer_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  if (kDebugMode && DemoSeeder.isDemoFlagEnabled) {
    await DemoSeeder.seedIfEmpty(sl<ExplorerRepository>());
  }
  runApp(const RemindingApp());
}

