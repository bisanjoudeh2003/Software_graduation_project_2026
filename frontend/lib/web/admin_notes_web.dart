import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';
import 'admin_web_shell.dart';

const Color adminNotesPrimaryGreen = Color(0xFF2F4F46);
const Color adminNotesLightCream = Color(0xFFF5F1EB);
const Color adminNotesSoftGreen = Color(0xFF3E6B5C);
const Color adminNotesGold = Color(0xFFC9A84C);
const Color adminNotesRed = Color(0xFFB84040);
const Color adminNotesGrey = Color(0xFF8A8A8A);
const Color adminNotesDarkText = Color(0xFF26352D);

class AdminNotesWeb extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final String userRole;

  const AdminNotesWeb({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<AdminNotesWeb> createState() => _AdminNotesWebState();
}

class _AdminNotesWebState extends State<AdminNotesWeb> {
  bool loading = true;
  bool saving = false;

  List<dynamic> notes = [];

  final TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await AdminService.getUserAdminNotes(widget.userId);

      if (!mounted) return;

      setState(() {
        notes = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _showMessage(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _addNote() async {
    final text = noteController.text.trim();

    if (text.isEmpty) {
      _showMessage("Write a note first");
      return;
    }

    if (text.length < 3) {
      _showMessage("Note is too short");
      return;
    }

    setState(() => saving = true);

    try {
      final createdNote = await AdminService.addUserAdminNote(
        userId: widget.userId,
        note: text,
      );

      if (!mounted) return;

      setState(() => saving = false);

      if (createdNote == null) {
        _showMessage("Failed to add note");
        return;
      }

      noteController.clear();
      FocusScope.of(context).unfocus();

      _showMessage("Admin note added");
      await _loadNotes();
    } catch (e) {
      if (!mounted) return;

      setState(() => saving = false);
      _showMessage(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _deleteNote(int noteId) async {
    if (noteId <= 0) {
      _showMessage("Invalid note id");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          "Delete Note",
          style: TextStyle(
            color: adminNotesPrimaryGreen,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        content: Text(
          "Are you sure you want to delete this admin note?",
          style: TextStyle(
            color: Colors.black.withOpacity(0.60),
            fontFamily: "Montserrat",
            fontSize: 13,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminNotesGrey,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: adminNotesRed,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final ok = await AdminService.deleteAdminNote(noteId);

      if (!mounted) return;

      if (ok) {
        _showMessage("Note deleted");
        await _loadNotes();
      } else {
        _showMessage("Failed to delete note");
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return fallback;
    return text;
  }

  String _formatDate(dynamic value) {
    final raw = _text(value, fallback: "");

    if (raw.isEmpty) return "";

    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat("MMM d, yyyy • h:mm a").format(date);
    } catch (_) {
      return raw;
    }
  }

  String _roleName(String role) {
    switch (role) {
      case "photographer":
        return "Photographer";
      case "venue_owner":
        return "Venue Owner";
      case "warehouse_owner":
        return "Warehouse Owner";
      case "admin":
        return "Admin";
      default:
        return "Client";
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case "photographer":
        return Icons.camera_alt_outlined;
      case "venue_owner":
        return Icons.location_city_outlined;
      case "warehouse_owner":
        return Icons.warehouse_outlined;
      case "admin":
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 1,
      showBackButton: true,
      pageTitle: "Admin Notes",
      child: Container(
        color: adminNotesLightCream,
        child: RefreshIndicator(
          color: adminNotesPrimaryGreen,
          onRefresh: _loadNotes,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1120;

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: _addNoteCard(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _sectionTitle(),
                                    const SizedBox(height: 14),
                                    _notesList(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _addNoteCard(),
                            const SizedBox(height: 22),
                            _sectionTitle(),
                            const SizedBox(height: 14),
                            _notesList(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminNotesSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminNotesPrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.sticky_note_2_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Admin Notes",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Private internal notes about this account.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _targetUserBadge(),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadNotes,
          ),
        ],
      ),
    );
  }

  Widget _targetUserBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _roleIcon(widget.userRole),
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              "${widget.userName} • ${_roleName(widget.userRole)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addNoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminNotesPrimaryGreen.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            title: "Add New Note",
            icon: Icons.edit_note_outlined,
            color: adminNotesPrimaryGreen,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: noteController,
            minLines: 6,
            maxLines: 10,
            style: const TextStyle(
              color: adminNotesPrimaryGreen,
              fontSize: 14,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: "Write an internal note about this account...",
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.35),
                fontFamily: "Montserrat",
                fontSize: 13,
              ),
              filled: true,
              fillColor: adminNotesLightCream.withOpacity(0.75),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(
                  color: adminNotesPrimaryGreen,
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _addNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: adminNotesPrimaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    adminNotesPrimaryGreen.withOpacity(0.55),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                saving ? "Saving..." : "Save Note",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle() {
    return Row(
      children: [
        const Text(
          "Notes History",
          style: TextStyle(
            color: adminNotesDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminNotesPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${notes.length} notes",
            style: const TextStyle(
              color: adminNotesPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _notesList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(
          child: CircularProgressIndicator(
            color: adminNotesPrimaryGreen,
          ),
        ),
      );
    }

    if (notes.isEmpty) {
      return _emptyCard();
    }

    return Column(
      children: notes.map((note) {
        return _noteCard(Map<String, dynamic>.from(note));
      }).toList(),
    );
  }

  Widget _noteCard(Map<String, dynamic> note) {
    final noteId = _toInt(note["id"]);
    final noteText = _text(note["note"], fallback: "");
    final adminName = _text(note["admin_name"], fallback: "Admin");
    final adminEmail = _text(note["admin_email"], fallback: "");
    final createdAt = _formatDate(note["created_at"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminNotesSoftGreen.withOpacity(0.06),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _adminIcon(),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: adminNotesPrimaryGreen,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Montserrat",
                      ),
                    ),
                    if (adminEmail.isNotEmpty)
                      Text(
                        adminEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.42),
                          fontSize: 11.5,
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Delete note",
                onPressed: () => _deleteNote(noteId),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: adminNotesRed,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: adminNotesLightCream.withOpacity(0.85),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.black.withOpacity(.035)),
            ),
            child: Text(
              noteText,
              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 14,
                height: 1.45,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.black.withOpacity(0.38),
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  createdAt,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.43),
                    fontSize: 11.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardTitle({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        _iconBox(icon, color),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: adminNotesDarkText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _adminIcon() {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: adminNotesPrimaryGreen.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.admin_panel_settings_outlined,
        color: adminNotesPrimaryGreen,
        size: 22,
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminNotesPrimaryGreen.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: adminNotesPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sticky_note_2_outlined,
              color: adminNotesPrimaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No notes yet",
            style: TextStyle(
              color: adminNotesPrimaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Add an internal admin note to keep track of important account information.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 12.5,
              height: 1.35,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminNotesPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}