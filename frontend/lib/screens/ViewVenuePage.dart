import 'package:flutter/material.dart';
import '../services/venue_service.dart';

class ViewVenuePage extends StatefulWidget {

  final Map venue;

  const ViewVenuePage({super.key, required this.venue});

  @override
  State<ViewVenuePage> createState() => _ViewVenuePageState();
}

class _ViewVenuePageState extends State<ViewVenuePage> {

  Map venue = {};
  List images = [];
  List reviews = [];

  bool loading = true;

  int currentImage = 0;

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color background = Color(0xFFF6F4EE);

  PageController controller = PageController();

  @override
  void initState() {
    super.initState();
    loadVenue();
  }

  Future loadVenue() async {

    final data = await VenueService.getVenueDetails(widget.venue["id"]);

    setState(() {

      venue = data["venue"];
      images = data["images"];
      reviews = data["reviews"];

      loading = false;

    });

  }

  void nextImage(){
    if(currentImage < images.length-1){
      controller.nextPage(
        duration: const Duration(milliseconds:300),
        curve: Curves.easeInOut
      );
    }
  }

  void prevImage(){
    if(currentImage > 0){
      controller.previousPage(
        duration: const Duration(milliseconds:300),
        curve: Curves.easeInOut
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    if(loading){
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(

      backgroundColor: background,

      appBar: AppBar(

        backgroundColor: background,
        elevation: 0,

        title: Text(
          venue["name"] ?? "",
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black
          ),
        ),

        iconTheme: const IconThemeData(color: Colors.black),

      ),

      body: ListView(

        children: [

          /// IMAGE SLIDER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:16),
            child: Container(

              height:260,

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow:[
                  BoxShadow(
                    color: Colors.black.withOpacity(.15),
                    blurRadius:12
                  )
                ]
              ),

              child: ClipRRect(

                borderRadius: BorderRadius.circular(20),

                child: Stack(

                  children: [

                    PageView.builder(

                      controller: controller,

                      itemCount: images.length,

                      onPageChanged:(i){
                        setState(()=>currentImage=i);
                      },

                      itemBuilder:(context,index){

                        return Image.network(
                          images[index]["image_url"],
                          fit: BoxFit.cover,
                        );

                      },

                    ),

                    /// LEFT ARROW
                    Positioned(

                      left:10,
                      top:100,

                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.3),
                          shape: BoxShape.circle
                        ),
                        child: IconButton(

                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size:20
                          ),

                          onPressed: prevImage,

                        ),
                      ),

                    ),

                    /// RIGHT ARROW
                    Positioned(

                      right:10,
                      top:100,

                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.3),
                          shape: BoxShape.circle
                        ),
                        child: IconButton(

                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size:20
                          ),

                          onPressed: nextImage,

                        ),
                      ),

                    ),

                    /// DOTS
                    Positioned(

                      bottom:15,
                      left:0,
                      right:0,

                      child: Row(

                        mainAxisAlignment: MainAxisAlignment.center,

                        children: List.generate(

                          images.length,

                          (i)=>AnimatedContainer(

                            duration: const Duration(milliseconds:300),

                            margin: const EdgeInsets.symmetric(horizontal:4),

                            width: currentImage==i ? 14 : 8,
                            height:8,

                            decoration: BoxDecoration(

                              color: currentImage==i
                              ? Colors.white
                              : Colors.white54,

                              borderRadius: BorderRadius.circular(20),

                            ),

                          )

                        ),

                      ),

                    )

                  ],

                ),

              ),

            ),
          ),

          const SizedBox(height:20),

          /// INFO CARD
          Container(

            margin: const EdgeInsets.symmetric(horizontal:16),

            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(

              color: Colors.white,
              borderRadius: BorderRadius.circular(18),

              boxShadow:[
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius:10
                )
              ]

            ),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  venue["name"] ?? "",

                  style: const TextStyle(
                    fontSize:22,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Montserrat",
                    color: primaryGreen
                  ),

                ),

                const SizedBox(height:10),

                Row(

                  children:[

                    const Icon(Icons.location_on,
                      size:18,
                      color: Colors.grey
                    ),

                    const SizedBox(width:4),

                    Text(
                      venue["location"] ?? "",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: primaryGreen
                      ),
                    )

                  ]

                ),

                const SizedBox(height:10),

                Text(

                  "\$${venue["price_per_hour"]} / hour",

                  style: const TextStyle(
                    fontSize:18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Montserrat"
                  ),

                ),

              ],

            ),

          ),

          const SizedBox(height:20),

          /// DESCRIPTION CARD
          Container(

            margin: const EdgeInsets.symmetric(horizontal:16),

            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(

              color: Colors.white,
              borderRadius: BorderRadius.circular(18),

              boxShadow:[
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius:10
                )
              ]

            ),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Text(

                  "Description",

                  style: TextStyle(
                    fontSize:20,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Montserrat",
                    color: primaryGreen

                  ),

                ),

                const SizedBox(height:10),

                Text(

                  venue["description"] ?? "",

                  style: const TextStyle(
                    fontSize:18,
                    fontFamily: "Montserrat",
                  ),

                )

              ],

            ),

          ),

          const SizedBox(height:20),

          /// REVIEWS CARD
          Container(

            margin: const EdgeInsets.symmetric(horizontal:16),

            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(

              color: Colors.white,
              borderRadius: BorderRadius.circular(18),

              boxShadow:[
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius:10
                )
              ]

            ),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Text(

                  "Reviews",

                  style: TextStyle(
                    fontSize:20,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Montserrat",
                    color: primaryGreen
                  ),

                ),

                const SizedBox(height:10),

                if(reviews.isEmpty)
                  const Text(
                    "No reviews yet",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.grey
                    ),
                  ),

                ...reviews.map((r){

                  return Container(

                    margin: const EdgeInsets.only(top:10),

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(12)
                    ),

                    child: Row(

                      children: [

                        const CircleAvatar(
                          child: Icon(Icons.person),
                        ),

                        const SizedBox(width:10),

                        Expanded(

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              Text(
                                r["full_name"] ?? "",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "Montserrat"
                                ),
                              ),

                              const SizedBox(height:4),

                              Text(
                                r["comment"] ?? "",
                                style: const TextStyle(
                                  fontFamily: "Montserrat"
                                ),
                              )

                            ],

                          ),

                        ),

                        Row(

                          children: [

                            const Icon(Icons.star,
                              color: Colors.amber,
                              size:18
                            ),

                            Text(
                              r["rating"].toString(),
                              style: const TextStyle(
                                fontFamily: "Montserrat"
                              ),
                            )

                          ],

                        )

                      ],

                    ),

                  );

                }).toList()

              ],

            ),

          ),

          const SizedBox(height:30)

        ],

      ),

    );

  }

}