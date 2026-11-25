import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/database_helper.dart';
import 'data/stats_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbHelper = DatabaseHelper();
  ThemeMode initialThemeMode = ThemeMode.system;
  try {
    initialThemeMode = await StatsRepository(dbHelper).loadThemeMode();
  } catch (_) {
    initialThemeMode = ThemeMode.system;
  } finally {
    await dbHelper.close();
  }
  runApp(CantonesePronunciationApp(initialThemeMode: initialThemeMode));
}
