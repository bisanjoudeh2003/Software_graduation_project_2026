import 'package:flutter/material.dart';

class ClientNotificationsPage extends StatelessWidget {

  const ClientNotificationsPage({super.key});

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color background = Color(0xFFF6F4EE);

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: background,

      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontFamily: "Montserrat"),
        ),
        backgroundColor: primaryGreen,
      ),

      body: ListView(

        padding: const EdgeInsets.all(16),

        children: [

          _notificationTile(
            "Booking Confirmed",
            "Your booking at Sunset Studio is confirmed",
            Icons.check_circle
          ),

          _notificationTile(
            "New Message",
            "You received a message from Lina Photographer",
            Icons.message
          ),

        ],

      ),

    );

  }

  Widget _notificationTile(
    String title,
    String message,
    IconData icon
  ){

    return Container(

      margin: const EdgeInsets.only(bottom:12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),

      child: Row(

        children: [

          CircleAvatar(
            backgroundColor: primaryGreen,
            child: Icon(icon,color:Colors.white),
          ),

          const SizedBox(width:12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold
                  ),
                ),

                const SizedBox(height:4),

                Text(
                  message,
                  style: const TextStyle(fontFamily: "Montserrat"),
                ),

              ],
            ),
          )

        ],

      ),

    );

  }

}