import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'utils/app_theme.dart';
import 'viewmodels/login_viewmodel.dart';
import 'viewmodels/register_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/add_password_viewmodel.dart';
import 'views/login_page.dart';
import 'views/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Supabase
  await Supabase.initialize(
    url: 'https://ndibzehsrtcyugmhjowm.supabase.co',
    anonKey: 'sb_publishable_ZKJOHeeA0Sd-VcHIjtMapw_B3oc4OKj',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => RegisterViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => AddPasswordViewModel()),
      ],
      child: const VaultApp(),
    ),
  );
}

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luxury Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.luxuryTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
      },
    );
  }
}