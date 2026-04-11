import 'package:flutter/material.dart';

class VenueOwnerHome extends StatelessWidget {
  const VenueOwnerHome({super.key});

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color background = Color(0xFFF5F1E9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      /// Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined), label: "My Venues"),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined), label: "Bookings"),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: "Messages"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [

              /// Header
              Row(
                children: [

                  const CircleAvatar(
                    radius: 22,
                    backgroundImage: AssetImage("assets/images/profile.jpg"),
                  ),

                  const SizedBox(width: 12),

                  const Text(
                    "Raya",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {},
                  ),

                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () {},
                  )
                ],
              ),

              const SizedBox(height: 25),

              /// Welcome text
              const Text(
                "Welcome back, Raya",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "You have 4 upcoming bookings",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 25),

              /// Stats card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [

                    /// Bookings
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Bookings",
                            style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 6),
                        Text("4",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),

                    /// Revenue
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        "\$1,250",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),

                    /// Rating
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.star, color: Colors.amber),
                          SizedBox(width: 6),
                          Text("4.9")
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// Upcoming Bookings title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Upcoming Bookings",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16)
                ],
              ),

              const SizedBox(height: 15),

              /// Booking item 1
              bookingItem(
                venue: "Illumina Gardens",
                date: "April 25, 4:00 PM - 7 PM",
                price: "\$750",
              ),

              const Divider(),

              /// Booking item 2
              bookingItem(
                venue: "Crystal Manor",
                date: "April 27, 5:00 PM - 8 PM",
                price: "\$500",
              ),

              const SizedBox(height: 15),

              /// View all bookings
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    "View All Bookings",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              /// Management buttons
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 2.6,
                children: [

                  managementButton(Icons.add, "Add New Venue"),

                  managementButton(Icons.edit_calendar,
                      "Edit Availability"),

                  managementButton(Icons.location_on_outlined,
                      "Manage Locations"),

                  managementButton(Icons.bar_chart, "View Reports"),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Booking card
  Widget bookingItem(
      {required String venue,
      required String date,
      required String price}) {
    return Row(
      children: [

        const CircleAvatar(
          radius: 24,
          backgroundImage: AssetImage("assets/images/venue.jpg"),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                venue,
                style:
                    const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),

        Text(
          price,
          style: const TextStyle(fontWeight: FontWeight.bold),
        )
      ],
    );
  }

  /// Buttons
  Widget managementButton(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    );
  }
}