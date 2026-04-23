import 'package:flutter/material.dart';
import '../theme.dart';
import 'screens/welcome.dart';
import '../screens/reset_password_screen.dart';
import '../services/auth_service.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_stripe/flutter_stripe.dart'; 

import '../screens/client_home.dart';
import '../screens/photographer_dashboard.dart';
import '../screens/venue_owner_home.dart';
import '../screens/loading_screen.dart';

void main()async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  Stripe.publishableKey = "pk_test_51TC2if4t47OxRIeEd647jAiHcCyYh6SVT3jxOI3t0974Wj5UQ0IulWU3i74nQ0MyuNspwdOvcVsSkMYbiHs0ONo800qtmBDycg"; 
  await Stripe.instance.applySettings();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  late final AppLinks _appLinks;

  Widget _home = const LoadingScreen();

  @override
  void initState() {
    super.initState();

    _initApp();

    _appLinks = AppLinks();

    _appLinks.uriLinkStream.listen((Uri? uri) {

      if (uri != null) {

        if (uri.scheme == "lensia" &&
            uri.host == "reset-password") {

          final token = uri.queryParameters['token'];

          if (token != null) {

            _navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) =>
                    ResetPasswordScreen(token: token),
              ),
            );

          }

        }

      }

    });

  }

  Future<void> _initApp() async {

    try {

      final user = await AuthService.getMe();

      print("USER DATA: $user");

      if (user == null) {

        _home = const WelcomeScreen();

      } else {

        String role = user["role"];

        if (role == "photographer") {

         _home = PhotographerDashboard(
  photographerId: user["id"],
);

        }
        else if (role == "venue_owner") {

          _home = const VenueOwnerHome();

        }
        else {

          _home = const ClientHome();

        }

      }

    } catch (e) {

      print("INIT ERROR: $e");

      _home = const WelcomeScreen();

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
      theme: appTheme,
      home: _home,
    );

  }

}