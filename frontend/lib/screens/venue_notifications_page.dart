import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color background = Color(0xFFF6F4EE);

  List notifications = [
    {
      "title": "New Booking Request",
      "message": "A client requested booking for Lake Como",
      "time": "2 min ago",
      "type": "booking"
    },
    {
      "title": "Booking Cancelled",
      "message": "A client cancelled the booking",
      "time": "10 min ago",
      "type": "cancel"
    },
    {
      "title": "New Review",
      "message": "You received a 5 star review",
      "time": "1 hour ago",
      "type": "review"
    }
  ];

  IconData getIcon(String type){

    switch(type){

      case "booking":
        return Icons.event_available;

      case "cancel":
        return Icons.cancel;

      case "review":
        return Icons.star;

      default:
        return Icons.notifications;

    }

  }

  Color getColor(String type){

    switch(type){

      case "booking":
        return primaryGreen;

      case "cancel":
        return Colors.red;

      case "review":
        return Colors.amber;

      default:
        return primaryGreen;

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: background,

      appBar: AppBar(

        backgroundColor: background,
        elevation: 0,

        iconTheme: const IconThemeData(color: primaryGreen),

        title: const Text(
          "Notifications",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: primaryGreen
          ),
        ),

      ),

      body: notifications.isEmpty

      ? const Center(
          child: Text(
            "No notifications",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.grey
            ),
          ),
        )

      : ListView.builder(

          padding: const EdgeInsets.all(20),

          itemCount: notifications.length,

          itemBuilder: (context,index){

            final n = notifications[index];

            return notificationCard(n);

          }

        ),

    );

  }

  Widget notificationCard(Map n){

    return Container(

      margin: const EdgeInsets.only(bottom:14),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8
          )
        ]

      ),

      child: Row(

        children: [

          Container(

            width:42,
            height:42,

            decoration: BoxDecoration(

              color: getColor(n["type"]).withOpacity(.15),

              shape: BoxShape.circle

            ),

            child: Icon(
              getIcon(n["type"]),
              color: getColor(n["type"]),
              size:22,
            ),

          ),

          const SizedBox(width:14),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(
                  n["title"],
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    fontSize:15
                  ),
                ),

                const SizedBox(height:4),

                Text(
                  n["message"],
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.grey[600],
                    fontSize:13
                  ),
                ),

                const SizedBox(height:6),

                Text(
                  n["time"],
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.grey[500],
                    fontSize:12
                  ),
                )

              ],

            ),

          )

        ],

      ),

    );

  }

}