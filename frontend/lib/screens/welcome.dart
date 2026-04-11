import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
 State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {

  final PageController _controller = PageController();
  int currentPage = 0;

  late AnimationController _arrowController;

  final List<Map<String, String>> pages = [
    {
      "image": "images/p1.png",
      "title1": "Discover",
      "title2": "Local Talent",
      "desc": "Find professional photographers\nin your area"
    },
    {
      "image": "images/p2.png",
      "title1": "Build Your",
      "title2": "Portfolio",
      "desc": "Showcase your best work and\nattract your clients"
    },
    {
      "image": "images/p3.png",
      "title1": "Book & Connect",
      "title2": "Easily",
      "desc": "Manage bookings, chat clients\nand grow your business"
    },
  ];

  @override
  void initState() {
    super.initState();

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0,
      upperBound: 10,
    )..repeat(reverse: true);
  }

  void nextPage() {

    if (currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );

    }

  }

  Widget buildDot(int index) {

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: currentPage == index ? 18 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: currentPage == index
            ? const Color(0xFF2F4F3E)
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF5F1E9),

      body: SafeArea(

        child: Column(

          children: [

            const SizedBox(height: 35),

            /// LOGO
            Image.asset(
              "images/logo2.png",
              height: 80,
            ),

            const SizedBox(height: 5),

            /// PAGE VIEW
            Expanded(

              child: PageView.builder(

                controller: _controller,

                itemCount: pages.length,

                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },

                itemBuilder: (context, index) {

                  return AnimatedSwitcher(

                    duration: const Duration(milliseconds: 500),

                    child: Padding(

                      key: ValueKey(index),

                      padding: const EdgeInsets.symmetric(horizontal: 25),

                      child: Column(

                        children: [

                          const SizedBox(height: 0),

                          /// IMAGE
                          SizedBox(
                            height: 350,
                            child: Image.asset(
                              pages[index]["image"]!,
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 15),

                          /// TITLE
                          Text(
                            pages[index]["title1"]!,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Playfair_Display',
                              color: Color(0xFF2F4F3E),
                            ),
                          ),

                          Text(
                            pages[index]["title2"]!,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair_Display',
                              color: Color(0xFF2F4F3E),
                            ),
                          ),

                          const SizedBox(height: 15),

                          /// DESCRIPTION
                          Text(
                            pages[index]["desc"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontFamily: "Montserrat",
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2F4F3E),
                            ),
                          ),

                        ],

                      ),

                    ),

                  );

                },

              ),

            ),

            /// DOTS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildDot(0),
                buildDot(1),
                buildDot(2),
              ],
            ),

            const SizedBox(height: 30),

            /// BUTTON
            currentPage != 2

                ? AnimatedBuilder(

                    animation: _arrowController,

                    builder: (context, child) {

                      return Transform.translate(
                        offset: Offset(0, -_arrowController.value),
                        child: child,
                      );

                    },

                    child: GestureDetector(

                      onTap: nextPage,

                      child: Container(

                        width: 70,
                        height: 70,

                        decoration: BoxDecoration(

                          color: const Color(0xFF2F4F3E),

                          shape: BoxShape.circle,

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],

                        ),

                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 28,
                        ),

                      ),

                    ),

                  )

                : Padding(

                    padding: const EdgeInsets.symmetric(horizontal: 30),

                    child: SizedBox(

                      width: double.infinity,
                      height: 55,

                      child: ElevatedButton(

                        style: ElevatedButton.styleFrom(

                          backgroundColor: const Color(0xFF2F4F3E),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),

                        ),

                        onPressed: nextPage,

                        child: const Text(
                          "Get Started",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                      ),

                    ),

                  ),

            const SizedBox(height: 40),

          ],

        ),

      ),

    );

  }

}