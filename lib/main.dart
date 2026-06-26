import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'navigation/router.dart';
import 'theme/theme.dart';
import 'database/app_database.dart';
import 'providers/home_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await AppDatabase.getInstance();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PlantoDexApp());
}

class PlantoDexApp extends StatelessWidget {
  const PlantoDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        // Add future providers here (QuestProvider, BadgeProvider, etc.)
      ],
      child: MaterialApp.router(
        title: 'PlantoDex',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: router,
      ),
    );
  }
}
