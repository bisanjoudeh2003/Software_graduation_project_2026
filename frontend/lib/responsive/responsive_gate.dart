import 'package:flutter/material.dart';

// mobile screens
import '../screens/login_screen.dart';
import '../screens/signup.dart';
import '../screens/client_home.dart';
import '../screens/photographer_dashboard.dart';
import '../screens/venue_owner_home.dart';
import '../screens/client_venues_page.dart';
import '../screens/warehouse_owner_home.dart';
import '../screens/forgot_password_screen.dart';


// web screens
import '../web/login.dart';
import '../web/signup.dart';
import '../web/client_home_web.dart';
import '../web/photographer_dashboard_web.dart';
import '../web/venue_owner_home_web.dart';
import '../web/client_venues_web.dart';
import '../web/forgot_password_screen_web.dart';
import '../web/warehouse_owner_home_web.dart';



class ResponsiveLoginPage extends StatelessWidget {
  const ResponsiveLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout ? const LoginWebScreen() : const LoginScreen();
      },
    );
  }
}

class ResponsiveSignupPage extends StatelessWidget {
  const ResponsiveSignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout ? const SignupWebScreen() : const SignupScreen();
      },
    );
  }
}


 



class ResponsiveForgotPasswordPage extends StatelessWidget {
  const ResponsiveForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ForgotPasswordScreenWeb()
            : const ForgotPasswordScreen();
      },
    );
  }
}

class ResponsiveClientHomePage extends StatelessWidget {
  const ResponsiveClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout ? const ClientHomeWeb() : const ClientHome();
      },
    );
  }
}

class ResponsiveClientVenuesPage extends StatelessWidget {
  const ResponsiveClientVenuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientVenuesWebPage()
            : const ClientVenuesPage();
      },
    );
  }
}
class ResponsiveWarehouseOwnerHomePage extends StatelessWidget {
  const ResponsiveWarehouseOwnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;

        return isWebLayout
            ? const WarehouseOwnerHomeWeb()
            : const WarehouseOwnerHome();
      },
    );
  }
}
class ResponsivePhotographerDashboardPage extends StatelessWidget {
  const ResponsivePhotographerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const PhotographerDashboardWeb()
            : const PhotographerDashboard();
      },
    );
  }
}

class ResponsiveVenueOwnerHomePage extends StatelessWidget {
  const ResponsiveVenueOwnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const VenueOwnerHomeWeb()
            : const VenueOwnerHome();
      },
    );
  }
}