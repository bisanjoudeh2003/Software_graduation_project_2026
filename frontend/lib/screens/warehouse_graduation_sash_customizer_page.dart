import 'package:flutter/material.dart';
import '../services/warehouse_cart_service.dart';

class GraduationSashCustomizerPage extends StatefulWidget {
  final int productId;

  const GraduationSashCustomizerPage({
    super.key,
    required this.productId,
  });

  @override
  State<GraduationSashCustomizerPage> createState() =>
      _GraduationSashCustomizerPageState();
}

class _GraduationSashCustomizerPageState
    extends State<GraduationSashCustomizerPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  static const Color burgundySash = Color(0xFF7A2230);
  static const Color blackSash = Color(0xFF171717);
  static const Color darkBrownSash = Color(0xFF4C332B);
  static const Color beigeSash = Color(0xFFE4CCAF);
  static const Color pinkSash = Color(0xFFE7BDC8);

  static const Color champagne = Color(0xFFE6D2B3);
  static const Color softIvory = Color(0xFFF8F3EA);

  final TextEditingController nameController =
      TextEditingController(text: "Ahmed Ali");
  final TextEditingController yearController =
      TextEditingController(text: "2025");
  final TextEditingController universityController =
      TextEditingController(text: "University Name");

  Color sashColor = burgundySash;
  Color textColor = softIvory;
  Color accentColor = champagne;

  String selectedFont = "Classic";
  bool addingToCart = false;

  final Map<String, String> fonts = {
    "Classic": "Georgia",
    "Modern": "Montserrat",
    "Elegant": "Times New Roman",
    "Simple": "Arial",
  };

  final List<Color> sashColors = const [
    burgundySash,
    blackSash,
    darkBrownSash,
    beigeSash,
    pinkSash,
  ];

  final List<Color> textColors = const [
    softIvory,
    Colors.white,
    Color(0xFF1A1A1A),
    burgundySash,
    darkBrownSash,
  ];

  final List<Color> trimColors = const [
    champagne,
    softIvory,
    Color(0xFF1A1A1A),
    Color(0xFFC49B73),
    burgundySash,
  ];

  Map<String, dynamic> getCustomDetailsJson() {
    return {
      "template": "graduation_sash_two_sides",
      "student_name": nameController.text.trim(),
      "university_name": universityController.text.trim(),
      "graduation_year": yearController.text.trim(),
      "sash_color": _colorToHex(sashColor),
      "text_color": _colorToHex(textColor),
      "accent_color": _colorToHex(accentColor),
      "font_style": selectedFont,
      "left_side": "name",
      "right_side": "class_of_year",
    };
  }

  String _colorToHex(Color color) {
    return "#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}";
  }

  Future<void> _addCustomizedSashToCart() async {
    final studentName = nameController.text.trim();
    final universityName = universityController.text.trim();
    final year = yearController.text.trim();

    if (studentName.isEmpty || universityName.isEmpty || year.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill all sash details first.",
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
            "Customized sash added to cart",
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
    nameController.dispose();
    yearController.dispose();
    universityController.dispose();
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
                        "Graduation Sash",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Customize & preview your sash",
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
                    child: GraduationSashPreview(
                      studentName: nameController.text,
                      universityName: universityController.text,
                      year: yearController.text,
                      sashColor: sashColor,
                      textColor: textColor,
                      accentColor: accentColor,
                      fontFamily: fontFamily,
                      availableColors: sashColors,
                      selectedColor: sashColor,
                      onColorTap: (color) {
                        setState(() => sashColor = color);
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  _sectionTitle("Text Details"),
                  const SizedBox(height: 12),
                  _input(
                    label: "Student Name",
                    hint: "Enter student name",
                    controller: nameController,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    label: "University Name",
                    hint: "Enter university name",
                    controller: universityController,
                    icon: Icons.school_outlined,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    label: "Class of / Year",
                    hint: "2025",
                    controller: yearController,
                    icon: Icons.event_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 28),
                  _sectionTitle("Sash Color"),
                  const SizedBox(height: 12),
                  _colorPicker(
                    colors: sashColors,
                    selected: sashColor,
                    onSelect: (c) => setState(() => sashColor = c),
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
                  _sectionTitle("Trim Color"),
                  const SizedBox(height: 12),
                  _colorPicker(
                    colors: trimColors,
                    selected: accentColor,
                    onSelect: (c) => setState(() => accentColor = c),
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
                            "Left side shows the student name and university.\nRight side shows Class of and graduation year.",
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
            onPressed: addingToCart ? null : _addCustomizedSashToCart,
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
              addingToCart ? "Adding..." : "Add Customized Sash to Cart",
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

class GraduationSashPreview extends StatelessWidget {
  final String studentName;
  final String universityName;
  final String year;
  final Color sashColor;
  final Color textColor;
  final Color accentColor;
  final String fontFamily;
  final List<Color> availableColors;
  final Color selectedColor;
  final ValueChanged<Color> onColorTap;

  const GraduationSashPreview({
    super.key,
    required this.studentName,
    required this.universityName,
    required this.year,
    required this.sashColor,
    required this.textColor,
    required this.accentColor,
    required this.fontFamily,
    required this.availableColors,
    required this.selectedColor,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final cleanName =
        studentName.trim().isEmpty ? "AHMED ALI" : studentName.trim();
    final cleanUniv = universityName.trim().isEmpty
        ? "University Name"
        : universityName.trim();
    final cleanYear = year.trim().isEmpty ? "2025" : year.trim();

    return Container(
      width: double.infinity,
      height: 470,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFBFAF7),
            Color(0xFFF3EFE8),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PreviewBackgroundPainter(),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _PremiumSashPainter(
                    sashColor: sashColor,
                    trimColor: accentColor,
                  ),
                ),
              ),

              // LEFT SIDE TEXT - moved more to center
              Positioned(
                left: w * 0.155,
                top: 176,
                width: w * 0.22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cleanName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: textColor,
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .25,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(.18),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      width: 48,
                      height: 1.2,
                      color: textColor.withOpacity(.7),
                    ),
                    Text(
                      cleanUniv,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: textColor.withOpacity(.95),
                        fontSize: 8.4,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(.14),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // RIGHT SIDE TEXT - moved more to center
              Positioned(
                right: w * 0.155,
                top: 174,
                width: w * 0.22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "CLASS OF",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: textColor,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(.18),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cleanYear,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: textColor,
                        fontSize: 25,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(.18),
                            blurRadius: 2,
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
                bottom: 66,
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
                                selected ? .25 : .14,
                              ),
                              blurRadius: selected ? 9 : 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.94),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.black.withOpacity(.04),
                      ),
                    ),
                    child: const Text(
                      "Two-sided realistic sash preview",
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

class _PreviewBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withOpacity(.085),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * .73),
          radius: size.width * .32,
        ),
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * .74),
        width: size.width * .55,
        height: 42,
      ),
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PremiumSashPainter extends CustomPainter {
  final Color sashColor;
  final Color trimColor;

  _PremiumSashPainter({
    required this.sashColor,
    required this.trimColor,
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

    final topY = 43.0;
    final shoulderY = 120.0;
    final bottomY = 365.0;

    // reduced center gap between both sash sides
    final leftPath = Path()
      ..moveTo(cx - 12, topY)
      ..quadraticBezierTo(cx - 34, topY + 3, cx - 58, shoulderY - 36)
      ..lineTo(cx - 152, shoulderY)
      ..quadraticBezierTo(cx - 182, shoulderY + 85, cx - 196, bottomY - 25)
      ..lineTo(cx - 100, bottomY + 8)
      ..quadraticBezierTo(cx - 86, bottomY - 6, cx - 80, bottomY - 28)
      ..lineTo(cx - 12, shoulderY - 15)
      ..quadraticBezierTo(cx + 2, 72, cx - 12, topY)
      ..close();

    final rightPath = Path()
      ..moveTo(cx + 12, topY)
      ..quadraticBezierTo(cx + 34, topY + 3, cx + 58, shoulderY - 36)
      ..lineTo(cx + 152, shoulderY)
      ..quadraticBezierTo(cx + 182, shoulderY + 85, cx + 196, bottomY - 25)
      ..lineTo(cx + 100, bottomY + 8)
      ..quadraticBezierTo(cx + 86, bottomY - 6, cx + 80, bottomY - 28)
      ..lineTo(cx + 12, shoulderY - 15)
      ..quadraticBezierTo(cx - 2, 72, cx + 12, topY)
      ..close();

    final neckPath = Path()
      ..moveTo(cx - 12, topY)
      ..quadraticBezierTo(cx, 8, cx + 12, topY)
      ..quadraticBezierTo(cx + 14, 78, cx + 4, 95)
      ..quadraticBezierTo(cx, 85, cx - 4, 95)
      ..quadraticBezierTo(cx - 14, 78, cx - 12, topY)
      ..close();

    final shadow = Paint()
      ..color = Colors.black.withOpacity(.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.save();
    canvas.translate(4, 8);
    canvas.drawPath(leftPath, shadow);
    canvas.drawPath(rightPath, shadow);
    canvas.drawPath(neckPath, shadow);
    canvas.restore();

    final leftFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _lighten(sashColor, .22),
          sashColor,
          _darken(sashColor, .16),
          _darken(sashColor, .28),
        ],
        stops: const [0, .35, .72, 1],
      ).createShader(Rect.fromLTWH(cx - 220, 30, 220, 360));

    final rightFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          _lighten(sashColor, .18),
          sashColor,
          _darken(sashColor, .15),
          _darken(sashColor, .26),
        ],
        stops: const [0, .36, .72, 1],
      ).createShader(Rect.fromLTWH(cx, 30, 220, 360));

    final neckFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _lighten(sashColor, .22),
          sashColor,
          _darken(sashColor, .30),
        ],
      ).createShader(Rect.fromLTWH(cx - 60, 5, 120, 105));

    canvas.drawPath(leftPath, leftFill);
    canvas.drawPath(rightPath, rightFill);
    canvas.drawPath(neckPath, neckFill);

    final borderPaint = Paint()
      ..color = _darken(sashColor, .38)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(leftPath, borderPaint);
    canvas.drawPath(rightPath, borderPaint);
    canvas.drawPath(neckPath, borderPaint);

    final trimPaint = Paint()
      ..color = trimColor.withOpacity(.96)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;

    final thinTrim = Paint()
      ..color = _lighten(trimColor, .18).withOpacity(.92)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx - 145, shoulderY + 8),
      Offset(cx - 189, bottomY - 29),
      trimPaint,
    );
    canvas.drawLine(
      Offset(cx - 133, shoulderY + 14),
      Offset(cx - 176, bottomY - 17),
      thinTrim,
    );
    canvas.drawLine(
      Offset(cx - 18, shoulderY + 4),
      Offset(cx - 84, bottomY - 28),
      thinTrim,
    );

    canvas.drawLine(
      Offset(cx + 145, shoulderY + 8),
      Offset(cx + 189, bottomY - 29),
      trimPaint,
    );
    canvas.drawLine(
      Offset(cx + 133, shoulderY + 14),
      Offset(cx + 176, bottomY - 17),
      thinTrim,
    );
    canvas.drawLine(
      Offset(cx + 18, shoulderY + 4),
      Offset(cx + 84, bottomY - 28),
      thinTrim,
    );

    final shine = Paint()
      ..color = Colors.white.withOpacity(.16)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(
      Offset(cx - 108, 160),
      Offset(cx - 155, 305),
      shine,
    );

    canvas.drawLine(
      Offset(cx + 108, 157),
      Offset(cx + 155, 302),
      shine,
    );

    final smallShine = Paint()
      ..color = Colors.white.withOpacity(.11)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawLine(
      Offset(cx - 63, 132),
      Offset(cx - 102, 262),
      smallShine,
    );

    canvas.drawLine(
      Offset(cx + 63, 132),
      Offset(cx + 102, 262),
      smallShine,
    );

    final seamPaint = Paint()
      ..color = _darken(sashColor, .45).withOpacity(.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(cx - 196, bottomY - 25),
      Offset(cx - 100, bottomY + 8),
      seamPaint,
    );
    canvas.drawLine(
      Offset(cx + 100, bottomY + 8),
      Offset(cx + 196, bottomY - 25),
      seamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumSashPainter oldDelegate) {
    return oldDelegate.sashColor != sashColor ||
        oldDelegate.trimColor != trimColor;
  }
}