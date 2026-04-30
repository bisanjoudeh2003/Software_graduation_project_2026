import 'package:flutter/material.dart';

// mobile screens
import '../screens/login_screen.dart';
import '../screens/signup.dart';
import '../screens/client_home.dart';
import '../screens/photographer_dashboard.dart';
import '../screens/venue_owner_home.dart';
import '../screens/client_venues_page.dart';
/*import '../screens/all_photographers_page.dart';
import '../screens/client_bookings_page.dart';
import '../screens/client_profile.dart';*/
import '../screens/forgot_password_screen.dart';
/*import '../screens/client_notifications_page.dart';
import '../screens/client_messages_page.dart';
import '../screens/client_venue_details_page.dart';
import '../screens/client_public_profile_page.dart';
import '../screens/photographer_public_profile_page.dart';
import '../screens/client_Edit_profile_page.dart';
import '../screens/client_change_password_page.dart';
import '../screens/client_favorites_page.dart';*/

// web screens
import '../web/login.dart';
import '../web/signup.dart';
import '../web/client_home_web.dart';
import '../web/photographer_dashboard_web.dart';
import '../web/venue_owner_home_web.dart';
import '../web/client_venues_web.dart';
/*import '../web/client_photographers_web.dart';
import '../web/client_bookings_web.dart';
import '../web/client_profile_web.dart';*/
import '../web/forgot_password_screen_web.dart';
/*import '../web/client_notifications_web.dart';
import '../web/client_messages_web.dart';
import '../web/client_venue_details_web.dart';
import '../web/photographer_public_profile_web.dart';
import '../web/client_edit_profile_web.dart';
import '../web/client_change_password_web.dart';
import '../web/client_favorites_web.dart';
import '../web/client_public_profile_web.dart';*/

/*class ResponsiveClientEditProfilePage extends StatelessWidget {
  const ResponsiveClientEditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientEditProfileWebPage()
            : const ClientEditProfilePage();
      },
    );
  }
}

class ResponsiveClientChangePasswordPage extends StatelessWidget {
  const ResponsiveClientChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientChangePasswordWebPage()
            : const ClientChangePasswordPage();
      },
    );
  }
}

class ResponsiveClientFavoritesPage extends StatelessWidget {
  const ResponsiveClientFavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientFavoritesWebPage()
            : const ClientFavoritesPage();
      },
    );
  }
}*/

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
/*class ResponsiveClientPublicProfilePage extends StatelessWidget {
  final int clientId;
  final String clientName;
  final String? clientImage;

  const ResponsiveClientPublicProfilePage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.clientImage,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? ClientPublicProfileWebPage(
                clientId: clientId,
                clientName: clientName,
                clientImage: clientImage,
              )
            : ClientPublicProfilePage(
                clientId: clientId,
                clientName: clientName,
                clientImage: clientImage,
              );
      },
    );
  }
}
class ResponsiveClientNotificationsPage extends StatelessWidget {
  const ResponsiveClientNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientNotificationsWebPage()
            : const ClientNotificationsPage();
      },
    );
  }
}

class ResponsiveClientMessagesPage extends StatelessWidget {
  const ResponsiveClientMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientMessagesWebPage()
            : const ClientMessagesPage();
      },
    );
  }
}

class ResponsiveClientBookingsPage extends StatelessWidget {
  const ResponsiveClientBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientBookingsWebPage()
            : const ClientBookingsPage();
      },
    );
  }
}

class ResponsiveClientVenueDetailsPage extends StatelessWidget {
  final Map venue;

  const ResponsiveClientVenueDetailsPage({
    super.key,
    required this.venue,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? ClientVenueDetailsWebPage(venue: venue)
            : ClientVenueDetailsPage(venue: venue);
      },
    );
  }
}

class ResponsivePhotographerPublicProfilePage extends StatelessWidget {
  final int photographerId;
  final String photographerName;
  final String? photographerImage;

  const ResponsivePhotographerPublicProfilePage({
    super.key,
    required this.photographerId,
    required this.photographerName,
    this.photographerImage,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? PhotographerPublicProfileWebPage(
                photographerId: photographerId,
                photographerName: photographerName,
                photographerImage: photographerImage,
              )
            : PhotographerPublicProfilePage(
                photographerId: photographerId,
                photographerName: photographerName,
                photographerImage: photographerImage,
              );
      },
    );
  }
}*/

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



/*class ResponsiveClientPhotographersPage extends StatelessWidget {
  const ResponsiveClientPhotographersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientPhotographersWebPage()
            : const AllPhotographersPage();
      },
    );
  }
}*/



/*class ResponsiveClientProfilePage extends StatelessWidget {
  const ResponsiveClientProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebLayout = constraints.maxWidth >= 900;
        return isWebLayout
            ? const ClientProfileWebPage()
            : const ClientProfilePage();
      },
    );
  }
}
*/
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