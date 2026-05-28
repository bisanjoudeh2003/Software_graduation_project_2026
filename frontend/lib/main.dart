import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'theme.dart';
import 'screens/welcome.dart';
import 'screens/reset_password_screen.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'screens/loading_screen.dart';
import 'responsive/responsive_gate.dart';
import 'web/shared_gallery_web.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/account_deactivated_screen.dart';

import 'web/client_warehouse_orders_page.dart';
import 'web/client_bookings_page_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    Stripe.publishableKey =
        "pk_test_51TC2if4t47OxRIeEd647jAiHcCyYh6SVT3jxOI3t0974Wj5UQ0IulWU3i74nQ0MyuNspwdOvcVsSkMYbiHs0ONo800qtmBDycg";

    await Stripe.instance.applySettings();

    try {
      await PushNotificationService.init();
    } catch (e) {
      debugPrint("PUSH NOTIFICATION INIT ERROR: $e");
    }
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

  bool _isAccountActive(dynamic statusValue) {
    final status = statusValue?.toString().toLowerCase().trim();

    if (status == null || status.isEmpty || status == "null") {
      return true;
    }

    return status == "active";
  }

  Future<void> _initApp() async {
    try {
      if (kIsWeb) {
        final fragment = Uri.base.fragment;

        debugPrint("WEB INITIAL URL: ${Uri.base}");
        debugPrint("WEB INITIAL FRAGMENT: $fragment");

        if (fragment.startsWith("/shared-gallery/")) {
          final token = fragment.replaceFirst("/shared-gallery/", "");

          _home = SharedGalleryWeb(token: token);

          if (mounted) {
            setState(() {});
          }

          return;
        }

        if (fragment.startsWith("/warehouse-orders")) {
          _home = const ClientWarehouseOrdersPage();

          if (mounted) {
            setState(() {});
          }

          return;
        }

        if (fragment.startsWith("/client-bookings")) {
          _home = const ClientBookingsPageWeb();

          if (mounted) {
            setState(() {});
          }

          return;
        }
      }

      final user = await AuthService.getMe();

      debugPrint("USER DATA: $user");

      if (user == null) {
        _home = kIsWeb ? const ResponsiveLoginPage() : const WelcomeScreen();
      } else {
        isDark = user["dark_mode"] == 1 ||
            user["dark_mode"] == true ||
            user["dark_mode"]?.toString() == "1";

        final String role = user["role"]?.toString() ?? "client";
        final String status = user["status"]?.toString() ?? "active";

        debugPrint("INIT USER ROLE: $role");
        debugPrint("INIT USER EMAIL: ${user["email"]}");
        debugPrint("INIT USER STATUS: $status");

        if (role != "admin" && !_isAccountActive(status)) {
          _home = AccountDeactivatedScreen(
            userName: user["full_name"]?.toString(),
            email: user["email"]?.toString(),
          );
        } else if (role == "admin") {
          _home = const AdminDashboardScreen();
        } else if (role == "photographer") {
          _home = const ResponsivePhotographerDashboardPage();
        } else if (role == "venue_owner") {
          _home = const ResponsiveVenueOwnerHomePage();
        } else if (role == "warehouse_owner") {
          _home = const ResponsiveWarehouseOwnerHomePage();
        } else {
          _home = const ResponsiveClientHomePage();
        }
      }
    } catch (e) {
      debugPrint("INIT ERROR: $e");

      _home = kIsWeb ? const ResponsiveLoginPage() : const WelcomeScreen();
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
        '/warehouse-orders': (_) => const ClientWarehouseOrdersPage(),
        '/client-bookings': (_) => const ClientBookingsPageWeb(),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? "");

        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == "shared-gallery") {
          final token = uri.pathSegments[1];

          return MaterialPageRoute(
            builder: (_) => SharedGalleryWeb(token: token),
          );
        }

        if (uri.path == "/warehouse-orders") {
          return MaterialPageRoute(
            builder: (_) => const ClientWarehouseOrdersPage(),
          );
        }

        if (uri.path == "/client-bookings") {
          return MaterialPageRoute(
            builder: (_) => const ClientBookingsPageWeb(),
          );
        }

        return null;
      },
    );
  }
}