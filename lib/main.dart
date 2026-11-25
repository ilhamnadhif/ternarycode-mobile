import 'package:flutter/material.dart';

import 'app.dart';
import 'services/companion_api.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(
    api: CompanionApi(),
    storage: DeviceStorageService(),
    notifications: AndroidNotificationService(),
    autoCheckUpdates: true,
    loadPlatformInfo: true,
  );
  await controller.init();

  runApp(TernaryCodeApp(controller: controller));
}
