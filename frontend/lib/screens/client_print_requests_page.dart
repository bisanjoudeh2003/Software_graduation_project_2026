import 'package:flutter/material.dart';

import '../services/print_request_service.dart';

const _green = Color(0xFF2F4F46);
const _softGreen = Color(0xFF3E6B5C);
const _cream = Color(0xFFF6F4EE);
const _gold = Color(0xFFC9A84C);
const _blue = Color(0xFF2F6B9A);
const _red = Color(0xFFB84040);

class ClientPrintRequestsPage extends StatefulWidget {
  const ClientPrintRequestsPage({super.key});

  @override
  State<ClientPrintRequestsPage> createState() => _ClientPrintRequestsPageState();
}

class _ClientPrintRequestsPageState extends State<ClientPrintRequestsPage> {
  bool loading = true;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _border => _isDark ? Colors.white12 : _green.withOpacity(0.10);
  Color get _softSurface => _isDark ? Colors.white.withOpacity(0.05) : _cream;

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting for photographer';
      case 'accepted':
        return 'Accepted';
      case 'printed':
        return 'Printed';
      case 'ready_for_pickup':
        return 'Ready for pickup';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return _gold;
      case 'accepted':
        return _blue;
      case 'printed':
        return _softGreen;
      case 'ready_for_pickup':
        return _green;
      case 'completed':
        return _softGreen;
      case 'rejected':
        return _red;
      default:
        return _sub;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'printed':
        return Icons.local_printshop_rounded;
      case 'ready_for_pickup':
        return Icons.inventory_2_outlined;
      case 'completed':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _prettyDate(dynamic raw) {
    final value = (raw ?? '').toString();
    if (value.isEmpty || value == 'null') return 'Not set';

    try {
      final date = DateTime.parse(value);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return value.split('T').first;
    }
  }

  String _previewUrl(Map<String, dynamic> item) {
    final thumb = (item['thumbnail_url'] ?? '').toString();
    final media = (item['media_url'] ?? '').toString();
    if (thumb.trim().isNotEmpty) return thumb;
    return media;
  }

  Future<void> _loadRequests() async {
    setState(() => loading = true);

    try {
      final data = await PrintRequestService.getClientPrintRequests();
      if (!mounted) return;
      setState(() {
        requests = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), _red);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> request) async {
    final requestId = _toInt(request['id']);
    if (requestId == 0) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrintRequestDetailsSheet(
        requestId: requestId,
        isClientView: true,
        statusText: _statusText,
        statusColor: _statusColor,
        statusIcon: _statusIcon,
        previewUrl: _previewUrl,
      ),
    );
  }

  void _snack(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: _text,
        centerTitle: true,
        title: const Text(
          'Print Requests',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _green,
        onRefresh: _loadRequests,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : requests.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                    children: [_emptyState()],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                    itemCount: requests.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) return _introCard();
                      return _requestCard(requests[index - 1]);
                    },
                  ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green.withOpacity(_isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _green.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_printshop_rounded, color: _green, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track your photo print requests',
                  style: TextStyle(
                    color: _text,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Pickup or delivery is arranged directly with the photographer.',
                  style: TextStyle(
                    color: _sub,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final color = _statusColor(status);
    final itemsCount = _toInt(request['items_count']);
    final printSize = (request['print_size'] ?? '').toString();
    final quantity = _toInt(request['quantity']);
    final photographerName = (request['photographer_name'] ?? 'Photographer').toString();

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openDetails(request),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(_isDark ? 0.16 : 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(status), color: color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusText(status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _text,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'With $photographerName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _sub,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _green),
                ],
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(Icons.image_outlined, '$itemsCount photos', _green),
                  _pill(Icons.straighten_rounded, printSize, _blue),
                  _pill(Icons.copy_rounded, 'Qty $quantity', _gold),
                  _pill(Icons.event_rounded, _prettyDate(request['created_at']), _sub),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(Icons.local_printshop_outlined, color: _sub.withOpacity(0.65), size: 46),
          const SizedBox(height: 12),
          Text(
            'No print requests yet',
            style: TextStyle(
              color: _text,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'After requesting prints from a final gallery, you can track the status here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _sub,
              fontFamily: 'Montserrat',
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintRequestDetailsSheet extends StatefulWidget {
  final int requestId;
  final bool isClientView;
  final String Function(String status) statusText;
  final Color Function(String status) statusColor;
  final IconData Function(String status) statusIcon;
  final String Function(Map<String, dynamic> item) previewUrl;

  const _PrintRequestDetailsSheet({
    required this.requestId,
    required this.isClientView,
    required this.statusText,
    required this.statusColor,
    required this.statusIcon,
    required this.previewUrl,
  });

  @override
  State<_PrintRequestDetailsSheet> createState() => _PrintRequestDetailsSheetState();
}

class _PrintRequestDetailsSheetState extends State<_PrintRequestDetailsSheet> {
  bool loading = true;
  Map<String, dynamic>? request;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Color get _card => Theme.of(context).cardColor;
  Color get _text => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _border => Theme.of(context).brightness == Brightness.dark ? Colors.white12 : _green.withOpacity(0.10);

  Future<void> _loadDetails() async {
    try {
      final data = await PrintRequestService.getPrintRequestDetails(requestId: widget.requestId);
      if (!mounted) return;
      final rawRequest = data['request'];
      final rawItems = data['items'];
      setState(() {
        request = rawRequest is Map ? Map<String, dynamic>.from(rawRequest) : null;
        items = rawItems is List
            ? rawItems.map((item) => Map<String, dynamic>.from(item as Map)).toList()
            : [];
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (request?['status'] ?? 'pending').toString();
    final color = widget.statusColor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: loading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : request == null
                  ? Center(
                      child: Text(
                        'Unable to load request details.',
                        style: TextStyle(color: _sub, fontFamily: 'Montserrat'),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _sub.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(widget.statusIcon(status), color: color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.statusText(status),
                                    style: TextStyle(
                                      color: _text,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${request?['print_size']} • Qty ${request?['quantity']} • ${items.length} photos',
                                    style: TextStyle(
                                      color: _sub,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: _blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _blue.withOpacity(0.15)),
                          ),
                          child: Text(
                            'Pickup or delivery will be arranged directly with the photographer.',
                            style: TextStyle(
                              color: _sub,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                        if ((request?['notes'] ?? '').toString().trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Note',
                            style: TextStyle(color: _text, fontFamily: 'Montserrat', fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            request!['notes'].toString(),
                            style: TextStyle(color: _sub, fontFamily: 'Montserrat', height: 1.45),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          'Selected Photos',
                          style: TextStyle(
                            color: _text,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) {
                            final url = widget.previewUrl(items[index]);
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                color: _green.withOpacity(0.08),
                                child: url.isNotEmpty
                                    ? Image.network(url, fit: BoxFit.cover)
                                    : const Icon(Icons.image_outlined, color: _green),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
