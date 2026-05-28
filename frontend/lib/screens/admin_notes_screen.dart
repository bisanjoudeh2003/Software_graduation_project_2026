import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';

const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminNotesScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final String userRole;

  const AdminNotesScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<AdminNotesScreen> createState() => _AdminNotesScreenState();
}

class _AdminNotesScreenState extends State<AdminNotesScreen> {
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
    setState(() => loading = true);

    final result = await AdminService.getUserAdminNotes(widget.userId);

    if (!mounted) return;

    setState(() {
      notes = result;
      loading = false;
    });
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
  }

  Future<void> _deleteNote(int noteId) async {
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
            color: adminPrimaryGreen,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        content: Text(
          "Are you sure you want to delete this admin note?",
          style: TextStyle(
            color: Colors.black.withOpacity(0.60),
            fontFamily: "Playfair",
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminGrey,
                fontFamily: "Playfair",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: adminRed,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await AdminService.deleteAdminNote(noteId);

    if (!mounted) return;

    if (ok) {
      _showMessage("Note deleted");
      await _loadNotes();
    } else {
      _showMessage("Failed to delete note");
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
    return Scaffold(
      backgroundColor: adminLightCream,
      body: RefreshIndicator(
        color: adminPrimaryGreen,
        onRefresh: _loadNotes,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 265,
              pinned: true,
              elevation: 0,
              backgroundColor: adminPrimaryGreen,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: _header(),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  height: 26,
                  decoration: const BoxDecoration(
                    color: adminLightCream,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _addNoteCard(),
                  const SizedBox(height: 20),
                  _sectionTitle(),
                  const SizedBox(height: 12),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 45),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: adminPrimaryGreen,
                        ),
                      ),
                    )
                  else if (notes.isEmpty)
                    _emptyCard()
                  else
                    ...notes.map((note) {
                      return _noteCard(Map<String, dynamic>.from(note));
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), adminSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.sticky_note_2_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Admin Notes",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Private internal notes about this account",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  fontFamily: "Playfair",
                ),
              ),
              const SizedBox(height: 12),
              _targetUserBadge(),
            ],
          ),
        ),
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
                fontWeight: FontWeight.w600,
                fontFamily: "Playfair",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addNoteCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: adminPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.edit_note_outlined,
                color: adminPrimaryGreen,
                size: 23,
              ),
              SizedBox(width: 8),
              Text(
                "Add New Note",
                style: TextStyle(
                  color: adminPrimaryGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(
              color: adminPrimaryGreen,
              fontSize: 14,
              fontFamily: "Playfair",
            ),
            decoration: InputDecoration(
              hintText: "Write an internal note about this account...",
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.35),
                fontFamily: "Playfair",
                fontSize: 13,
              ),
              filled: true,
              fillColor: adminLightCream.withOpacity(0.75),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(
                  color: adminPrimaryGreen,
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _addNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: adminPrimaryGreen,
                foregroundColor: Colors.white,
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
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
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
            color: Color(0xFF1E1E1E),
            fontSize: 19,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${notes.length} notes",
            style: const TextStyle(
              color: adminPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: adminSoftGreen.withOpacity(0.06),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: adminPrimaryGreen,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Playfair",
                      ),
                    ),
                    if (adminEmail.isNotEmpty)
                      Text(
                        adminEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.38),
                          fontSize: 11.5,
                          fontFamily: "Playfair",
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteNote(noteId),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: adminRed,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: adminLightCream.withOpacity(0.85),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              noteText,
              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 14,
                height: 1.45,
                fontFamily: "Playfair",
              ),
            ),
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.black.withOpacity(0.35),
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  createdAt,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.40),
                    fontSize: 11.5,
                    fontFamily: "Playfair",
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _adminIcon() {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: adminPrimaryGreen.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.admin_panel_settings_outlined,
        color: adminPrimaryGreen,
        size: 22,
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: adminPrimaryGreen.withOpacity(0.05),
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
              color: adminPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sticky_note_2_outlined,
              color: adminPrimaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No notes yet",
            style: TextStyle(
              color: adminPrimaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
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
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminPrimaryGreen,
        content: Text(message),
      ),
    );
  }
}