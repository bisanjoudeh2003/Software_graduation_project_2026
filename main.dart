import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'theme.dart';
import 'screens/welcome.dart';
import 'screens/reset_password_screen.dart';
import 'services/auth_service.dart';
import 'screens/loading_screen.dart';
import 'responsive/responsive_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    Stripe.publishableKey =
        "pk_test_51TC2if4t47OxRIeEd647jAiHcCyYh6SVT3jxOI3t0974Wj5UQ0IulWU3i74nQ0MyuNspwdOvcVsSkMYbiHs0ONo800qtmBDycg";
    await Stripe.instance.applySettings();
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  AppLinks? _appLinks;
  Widget _home = const LoadingScreen();
  bool isDark = false;

  void updateTheme(bool value) {
    setState(() {
      isDark = value;
    });
  }

  @override
  void initState() {
    super.initState();
    _initApp();
    _setupDeepLinks();
  }

  void _setupDeepLinks() {
    if (kIsWeb) return;

    _appLinks = AppLinks();
    _appLinks!.uriLinkStream.listen((Uri? uri) {
      if (uri != null &&
          uri.scheme == "lensia" &&
          uri.host == "reset-password") {
        final token = uri.queryParameters['token'];
        if (token != null) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(token: token),
            ),
          );
        }
      }
    });
  }

  Future<void> _initApp() async {
    try {
      final user = await AuthService.getMe();
      print("USER DATA: $user");

      if (user == null) {
        _home = kIsWeb
            ? const ResponsiveLoginPage()
            : const WelcomeScreen();
      } else {
        isDark = user["dark_mode"] == 1 ||
            user["dark_mode"] == true ||
            user["dark_mode"]?.toString() == "1";

        final String role = user["role"];
if (role == "photographer") {
  _home = const ResponsivePhotographerDashboardPage();
} else if (role == "venue_owner") {
  _home = const ResponsiveVenueOwnerHomePage();
} else {
  _home = const ResponsiveClientHomePage();
}
      }
    } catch (e) {
      print("INIT ERROR: $e");
      _home = kIsWeb
          ? const ResponsiveLoginPage()
          : const WelcomeScreen();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Lensia',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: _home,
      routes: {
        '/login': (_) => const ResponsiveLoginPage(),
        '/signup': (_) => const ResponsiveSignupPage(),
      },
    );
  }
}