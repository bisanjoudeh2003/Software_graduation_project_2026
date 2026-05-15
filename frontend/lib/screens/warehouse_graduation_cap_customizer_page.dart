import 'package:flutter/material.dart';
import '../services/warehouse_cart_service.dart';

class GraduationCapCustomizerPage extends StatefulWidget {
  final int productId;

  const GraduationCapCustomizerPage({
    super.key,
    required this.productId,
  });

  @override
  State<GraduationCapCustomizerPage> createState() =>
      _GraduationCapCustomizerPageState();
}

class _GraduationCapCustomizerPageState
    extends State<GraduationCapCustomizerPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  static const Color blackCap = Color(0xFF171717);
  static const Color burgundyCap = Color(0xFF7A2230);
  static const Color darkBrownCap = Color(0xFF4C332B);
  static const Color beigeCap = Color(0xFFE4CCAF);
  static const Color pinkCap = Color(0xFFE7BDC8);

  static const Color champagne = Color(0xFFE6D2B3);
  static const Color softIvory = Color(0xFFF8F3EA);

  final TextEditingController mainTextController =
      TextEditingController(text: "I DID IT");
  final TextEditingController yearController =
      TextEditingController(text: "2025");
  final TextEditingController nameController =
      TextEditingController(text: "Ahmed Ali");

  Color capColor = blackCap;
  Color textColor = softIvory;
  Color tasselColor = burgundyCap;

  String selectedFont = "Classic";
  String tasselSide = "right";

  bool addingToCart = false;

  final Map<String, String> fonts = {
    "Classic": "Georgia",
    "Modern": "Montserrat",
    "Elegant": "Times New Roman",
    "Simple": "Arial",
  };

  final List<Color> capColors = const [
    blackCap,
    burgundyCap,
    darkBrownCap,
    beigeCap,
    pinkCap,
  ];

  final List<Color> textColors = const [
    softIvory,
    Colors.white,
    champagne,
    Color(0xFF1A1A1A),
    burgundyCap,
  ];

  final List<Color> tasselColors = const [
    burgundyCap,
    champagne,
    softIvory,
    blackCap,
    pinkCap,
  ];

  Map<String, dynamic> getCustomDetailsJson() {
    return {
      "template": "graduation_cap",
      "cap_text": mainTextController.text.trim(),
      "student_name": nameController.text.trim(),
      "graduation_year": yearController.text.trim(),
      "cap_color": _colorToHex(capColor),
      "text_color": _colorToHex(textColor),
      "tassel_color": _colorToHex(tasselColor),
      "font_style": selectedFont,
      "tassel_side": tasselSide,
    };
  }

  String _colorToHex(Color color) {
    return "#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}";
  }

  Future<void> _addCustomizedCapToCart() async {
    final mainText = mainTextController.text.trim();
    final year = yearController.text.trim();

    if (mainText.isEmpty || year.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill all cap details first.",
            style: TextStyle(fontFamily: "Montserrat"),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => addingToCart = true);

    try {
      final details = getCustomDetailsJson();

      await WarehouseCartService.addToCart(
        productId: widget.productId,
        quantity: 1,
        customDetails: details,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Customized cap added to cart",
            style: TextStyle(fontFamily: "Montserrat"),
          ),
          backgroundColor: primaryGreen,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll("Exception:", "").trim(),
            style: const TextStyle(fontFamily: "Montserrat"),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => addingToCart = false);
    }
  }

  @override
  void dispose() {
    mainTextController.dispose();
    yearController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = fonts[selectedFont] ?? "Montserrat";

    return Scaffold(
      backgroundColor: cream,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Graduation Cap",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Customize & preview your graduation cap",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.white.withOpacity(.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Live Preview"),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.06),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: GraduationCapPreview(
                      capText: mainTextController.text,
                      studentName: nameController.text,
                      year: yearController.text,
                      capColor: capColor,
                      textColor: textColor,
                      tasselColor: tasselColor,
                      fontFamily: fontFamily,
                      tasselSide: tasselSide,
                      availableColors: capColors,
                      selectedColor: capColor,
                      onColorTap: (color) {
                        setState(() => capColor = color);
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  _sectionTitle("Text Details"),
                  const SizedBox(height: 12),
                  _input(
                    label: "Main Cap Text",
                    hint: "I DID IT",
                    controller: mainTextController,
                    icon: Icons.text_fields_rounded,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    label: "Student Name",
                    hint: "Enter student name",
                    controller: nameController,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    label: "Graduation Year",
                    hint: "2025",
                    controller: yearController,
                    icon: Icons.event_outlined,
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 28),

                  _sectionTitle("Cap Color"),
                  const SizedBox(height: 12),
                  _colorPicker(
                    colors: capColors,
                    selected: capColor,
                    onSelect: (c) => setState(() => capColor = c),
                  ),

                  const SizedBox(height: 28),

                  _sectionTitle("Text Color"),
                  const SizedBox(height: 12),
                  _colorPicker(
                    colors: textColors,
                    selected: textColor,
                    onSelect: (c) => setState(() => textColor = c),
                  ),

                  const SizedBox(height: 28),

                  _sectionTitle("Tassel Color"),
                  const SizedBox(height: 12),
                  _colorPicker(
                    colors: tasselColors,
                    selected: tasselColor,
                    onSelect: (c) => setState(() => tasselColor = c),
                  ),

                  const SizedBox(height: 28),

                  _sectionTitle("Tassel Side"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _sideChip("left", "Left", Icons.keyboard_arrow_left),
                      const SizedBox(width: 12),
                      _sideChip("right", "Right", Icons.keyboard_arrow_right),
                    ],
                  ),

                  const SizedBox(height: 28),

                  _sectionTitle("Font Style"),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: fonts.keys.map((fontName) {
                      final selected = selectedFont == fontName;

                      return GestureDetector(
                        onTap: () => setState(() => selectedFont = fontName),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? primaryGreen : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: selected
                                  ? primaryGreen
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            fontName,
                            style: TextStyle(
                              fontFamily: fonts[fontName],
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lightGreen.withOpacity(.4),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: primaryGreen.withOpacity(.16)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: primaryGreen),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "The cap preview saves the selected colors, text, year, font style, and tassel side with the cart item.",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: primaryGreen,
                              fontSize: 12,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: addingToCart ? null : _addCustomizedCapToCart,
            icon: addingToCart
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_shopping_cart_rounded),
            label: Text(
              addingToCart ? "Adding..." : "Add Customized Cap to Cart",
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: "Montserrat",
        color: primaryGreen,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _input({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(
          Icons.edit_outlined,
          color: primaryGreen,
          size: 20,
        ),
        suffixIcon: Icon(icon, color: primaryGreen, size: 20),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.black54,
        ),
        hintStyle: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.black38,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: primaryGreen, width: 1.4),
        ),
      ),
    );
  }

  Widget _sideChip(String value, String label, IconData icon) {
    final selected = tasselSide == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tasselSide = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primaryGreen : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: selected ? Colors.white : primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorPicker({
    required List<Color> colors,
    required Color selected,
    required Function(Color) onSelect,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((color) {
        final isSelected = color.value == selected.value;

        return GestureDetector(
          onTap: () => onSelect(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? primaryGreen.withOpacity(.42)
                      : Colors.black.withOpacity(.08),
                  blurRadius: isSelected ? 10 : 4,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    color: color.computeLuminance() > 0.65
                        ? primaryGreen
                        : Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class GraduationCapPreview extends StatelessWidget {
  final String capText;
  final String studentName;
  final String year;
  final Color capColor;
  final Color textColor;
  final Color tasselColor;
  final String fontFamily;
  final String tasselSide;
  final List<Color> availableColors;
  final Color selectedColor;
  final ValueChanged<Color> onColorTap;

  const GraduationCapPreview({
    super.key,
    required this.capText,
    required this.studentName,
    required this.year,
    required this.capColor,
    required this.textColor,
    required this.tasselColor,
    required this.fontFamily,
    required this.tasselSide,
    required this.availableColors,
    required this.selectedColor,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final cleanText = capText.trim().isEmpty ? "I DID IT" : capText.trim();
    final cleanName =
        studentName.trim().isEmpty ? "Student Name" : studentName.trim();
    final cleanYear = year.trim().isEmpty ? "2025" : year.trim();

    return Container(
      width: double.infinity,
      height: 430,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFBFAF7),
            Color(0xFFF2EEE7),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CapBackgroundPainter(),
                ),
              ),

              Positioned.fill(
                child: CustomPaint(
                  painter: _GraduationCapPainter(
                    capColor: capColor,
                    tasselColor: tasselColor,
                    tasselSide: tasselSide,
                  ),
                ),
              ),

              Positioned(
                left: w * 0.18,
                right: w * 0.18,
                top: 120,
                child: Column(
                  children: [
                    Text(
                      cleanText.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: textColor,
                        fontSize: 25,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(.24),
                            blurRadius: 4,
                            offset: const Offset(0, 1.4),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 7),
                      width: 82,
                      height: 1.4,
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(.72),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Text(
                      cleanName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: textColor.withOpacity(.95),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(.18),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "CLASS OF $cleanYear",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: textColor.withOpacity(.95),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(.18),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 62,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: availableColors.map((color) {
                    final selected = color.value == selectedColor.value;

                    return GestureDetector(
                      onTap: () => onColorTap(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: selected ? 43 : 39,
                        height: selected ? 43 : 39,
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                selected ? .28 : .14,
                              ),
                              blurRadius: selected ? 10 : 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: selected
                            ? Icon(
                                Icons.check_rounded,
                                color: color.computeLuminance() > .65
                                    ? const Color(0xFF2F4F3E)
                                    : Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),

              Positioned(
                bottom: 17,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.95),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.black.withOpacity(.04),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.035),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      "Personalized graduation cap preview",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: Color(0xFF2F4F3E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withOpacity(.09),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * .70),
          radius: size.width * .34,
        ),
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * .70),
        width: size.width * .58,
        height: 42,
      ),
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GraduationCapPainter extends CustomPainter {
  final Color capColor;
  final Color tasselColor;
  final String tasselSide;

  _GraduationCapPainter({
    required this.capColor,
    required this.tasselColor,
    required this.tasselSide,
  });

  Color _darken(Color c, [double amount = .2]) {
    return Color.fromARGB(
      c.alpha,
      (c.red * (1 - amount)).round().clamp(0, 255),
      (c.green * (1 - amount)).round().clamp(0, 255),
      (c.blue * (1 - amount)).round().clamp(0, 255),
    );
  }

  Color _lighten(Color c, [double amount = .18]) {
    return Color.fromARGB(
      c.alpha,
      (c.red + (255 - c.red) * amount).round().clamp(0, 255),
      (c.green + (255 - c.green) * amount).round().clamp(0, 255),
      (c.blue + (255 - c.blue) * amount).round().clamp(0, 255),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    final boardTop = 62.0;
    final boardCenterY = 142.0;
    final boardHalfWidth = size.width * .44;
    const boardHalfHeight = 82.0;

    final boardPath = Path()
      ..moveTo(cx, boardTop)
      ..lineTo(cx + boardHalfWidth, boardCenterY)
      ..lineTo(cx, boardCenterY + boardHalfHeight)
      ..lineTo(cx - boardHalfWidth, boardCenterY)
      ..close();

    final boardShadow = Paint()
      ..color = Colors.black.withOpacity(.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.save();
    canvas.translate(4, 8);
    canvas.drawPath(boardPath, boardShadow);
    canvas.restore();

    final boardPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _lighten(capColor, .20),
          capColor,
          _darken(capColor, .26),
        ],
      ).createShader(
        Rect.fromLTWH(
          cx - boardHalfWidth,
          boardTop,
          boardHalfWidth * 2,
          boardHalfHeight * 2,
        ),
      );

    canvas.drawPath(boardPath, boardPaint);

    final border = Paint()
      ..color = _darken(capColor, .42)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(boardPath, border);

    final bottomLipPath = Path()
      ..moveTo(cx - boardHalfWidth * .62, boardCenterY + 37)
      ..quadraticBezierTo(
        cx,
        boardCenterY + 70,
        cx + boardHalfWidth * .62,
        boardCenterY + 37,
      )
      ..lineTo(cx + boardHalfWidth * .48, boardCenterY + 74)
      ..quadraticBezierTo(
        cx,
        boardCenterY + 101,
        cx - boardHalfWidth * .48,
        boardCenterY + 74,
      )
      ..close();

    final lipPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _lighten(capColor, .10),
          capColor,
          _darken(capColor, .32),
        ],
      ).createShader(
        Rect.fromLTWH(
          cx - boardHalfWidth * .7,
          boardCenterY + 30,
          boardHalfWidth * 1.4,
          100,
        ),
      );

    canvas.drawPath(bottomLipPath, lipPaint);
    canvas.drawPath(bottomLipPath, border);

    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(.10)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(
      Offset(cx - boardHalfWidth * .48, boardCenterY - 18),
      Offset(cx - boardHalfWidth * .10, boardCenterY - 48),
      shinePaint,
    );

    canvas.drawLine(
      Offset(cx + boardHalfWidth * .22, boardCenterY - 50),
      Offset(cx + boardHalfWidth * .62, boardCenterY - 18),
      shinePaint,
    );

    final centerButton = Paint()
      ..shader = RadialGradient(
        colors: [
          _lighten(capColor, .32),
          capColor,
          _darken(capColor, .33),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(cx, boardCenterY),
          radius: 19,
        ),
      );

    canvas.drawCircle(Offset(cx, boardCenterY), 18, centerButton);

    final buttonBorder = Paint()
      ..color = _darken(capColor, .50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawCircle(Offset(cx, boardCenterY), 18, buttonBorder);

    _drawTassel(canvas, size, Offset(cx, boardCenterY));
  }

  void _drawTassel(Canvas canvas, Size size, Offset start) {
    final isRight = tasselSide == "right";
    final side = isRight ? 1.0 : -1.0;

    final end = Offset(
      start.dx + side * size.width * .31,
      start.dy + 118,
    );

    final control = Offset(
      start.dx + side * size.width * .25,
      start.dy + 28,
    );

    final cordPaint = Paint()
      ..color = tasselColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cordPath = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas.drawPath(cordPath, cordPaint);

    final knotPaint = Paint()
      ..color = tasselColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(end, 8.5, knotPaint);

    final tasselMain = Paint()
      ..color = tasselColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final tasselTop = Offset(end.dx, end.dy + 8);
    final tasselBottomY = end.dy + 68;

    for (int i = -5; i <= 5; i++) {
      final dx = i * 3.0;
      canvas.drawLine(
        Offset(tasselTop.dx + dx * .35, tasselTop.dy),
        Offset(
          tasselTop.dx + dx,
          tasselBottomY - (i.abs() * 1.2),
        ),
        tasselMain,
      );
    }

    final tasselBand = Paint()
      ..color = _darken(tasselColor, .18)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(end.dx - 12, end.dy + 22),
      Offset(end.dx + 12, end.dy + 22),
      tasselBand,
    );

    final tasselCutPaint = Paint()
      ..color = Colors.white.withOpacity(.75)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(end.dx - 7, tasselBottomY - 2),
      Offset(end.dx - 1, tasselBottomY - 10),
      tasselCutPaint,
    );

    canvas.drawLine(
      Offset(end.dx + 7, tasselBottomY - 2),
      Offset(end.dx + 1, tasselBottomY - 10),
      tasselCutPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GraduationCapPainter oldDelegate) {
    return oldDelegate.capColor != capColor ||
        oldDelegate.tasselColor != tasselColor ||
        oldDelegate.tasselSide != tasselSide;
  }
}