import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'add_edit_portfolio_item_screen.dart';

class ManagePortfolioScreen extends StatefulWidget {
  final int portfolioId;

  const ManagePortfolioScreen({
    super.key,
    required this.portfolioId,
  });

  @override
  State<ManagePortfolioScreen> createState() =>
      _ManagePortfolioScreenState();
}

class _ManagePortfolioScreenState
    extends State<ManagePortfolioScreen> {

  final String baseUrl = "http://10.0.2.2:3000/api";
  List items = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    try {
      final response = await http.get(
        Uri.parse(
            "$baseUrl/portfolio-items/${widget.portfolioId}"),
      );

      if (response.statusCode == 200) {
        setState(() {
          items = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      print("Load Items Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteItem(int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/portfolio-items/$id"),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Item deleted")),
      );
      loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Portfolio"),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddEditPortfolioItemScreen(
                portfolioId: widget.portfolioId,
              ),
            ),
          ).then((value) {
            if (value == true) loadItems();
          });
        },
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Text(
                      "No items yet. Add your first work."),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {

                    final item = items[index];

                    return Card(
                      margin:
                          const EdgeInsets.only(
                              bottom: 16),
                      child: ListTile(
                        leading: item[
                                    'media_type'] ==
                                'image'
                            ? const Icon(
                                Icons.image)
                            : const Icon(
                                Icons.videocam),
                        title: Text(
                            item['title'] ?? ""),
                        subtitle: Text(
                            item['description'] ??
                                ""),
                        trailing: Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [

                            /// ✏ Edit
                            IconButton(
                              icon: const Icon(
                                  Icons.edit),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddEditPortfolioItemScreen(
                                      portfolioId:
                                          widget
                                              .portfolioId,
                                      itemData:
                                          item,
                                    ),
                                  ),
                                ).then(
                                  (value) {
                                    if (value ==
                                        true) {
                                      loadItems();
                                    }
                                  },
                                );
                              },
                            ),

                            /// 🗑 Delete
                            IconButton(
                              icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red),
                              onPressed: () =>
                                  deleteItem(
                                      item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}