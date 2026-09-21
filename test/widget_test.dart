import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZayanPhotoAlbumApp());
}

class ZayanPhotoAlbumApp extends StatelessWidget {
  const ZayanPhotoAlbumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Zayan's Photo Album",
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAFA),
      ),
      home: const AlbumHomeScreen(),
    );
  }
}

class AlbumItem {
  final String id;
  String imagePath;
  String title;
  String date;

  AlbumItem({
    required this.id,
    required this.imagePath,
    required this.title,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'title': title,
      'date': date,
    };
  }

  factory AlbumItem.fromMap(Map<String, dynamic> map) {
    return AlbumItem(
      id: map['id'] ?? '',
      imagePath: map['imagePath'] ?? '',
      title: map['title'] ?? '',
      date: map['date'] ?? '',
    );
  }
}

class AlbumHomeScreen extends StatefulWidget {
  const AlbumHomeScreen({super.key});

  @override
  State<AlbumHomeScreen> createState() => _AlbumHomeScreenState();
}

class _AlbumHomeScreenState extends State<AlbumHomeScreen> {
  final ImagePicker _picker = ImagePicker();

  List<AlbumItem> _items = [];
  List<AlbumItem> _filteredItems = [];

  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  // ============================================================
  // STEP 9 - SAVE DATA
  // ============================================================

  Future<void> _saveAlbum() async {
    final prefs = await SharedPreferences.getInstance();

    final data = _items
        .map((item) => jsonEncode(item.toMap()))
        .toList();

    await prefs.setStringList('zayan_album_items', data);
  }

  Future<void> _loadAlbum() async {
    final prefs = await SharedPreferences.getInstance();

    final savedData =
        prefs.getStringList('zayan_album_items') ?? [];

    final loadedItems = <AlbumItem>[];

    for (final item in savedData) {
      try {
        loadedItems.add(
          AlbumItem.fromMap(jsonDecode(item)),
        );
      } catch (_) {}
    }

    setState(() {
      _items = loadedItems;
      _filteredItems = List.from(_items);
      _loading = false;
    });
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _search(String query) {
    final text = query.toLowerCase().trim();

    setState(() {
      if (text.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        _filteredItems = _items.where((item) {
          return item.title.toLowerCase().contains(text) ||
              item.date.toLowerCase().contains(text);
        }).toList();
      }
    });
  }

  // ============================================================
  // STEP 3 + STEP 8
  // GALLERY থেকে ছবি নেওয়া
  // ============================================================

  Future<void> _addPhoto() async {
    try {
      final List<XFile> pickedImages =
          await _picker.pickMultiImage(
        imageQuality: 90,
      );

      if (pickedImages.isEmpty) return;

      for (final image in pickedImages) {
        final savedPath = await _copyImageToAppStorage(image);

        final titleController =
            TextEditingController(text: 'Zayan-এর স্মৃতি');

        final dateController =
            TextEditingController(text: _todayDate());

        final result = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text(
                '📷 ছবির তথ্য',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'ছবির নাম / ক্যাপশন',
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: 'তারিখ',
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('বাতিল'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('যোগ করুন'),
                ),
              ],
            );
          },
        );

        if (result == true &&
            titleController.text.trim().isNotEmpty) {
          final newItem = AlbumItem(
            id: DateTime.now()
                .microsecondsSinceEpoch
                .toString(),
            imagePath: savedPath,
            title: titleController.text.trim(),
            date: dateController.text.trim(),
          );

          setState(() {
            _items.insert(0, newItem);
          });
        } else {
          try {
            await File(savedPath).delete();
          } catch (_) {}
        }
      }

      await _saveAlbum();
      _search(_searchController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${pickedImages.length}টি ছবি album-এ যোগ হয়েছে ❤️',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ছবি যোগ করা যায়নি: $e'),
          ),
        );
      }
    }
  }

  Future<String> _copyImageToAppStorage(
      XFile image) async {
    final directory =
        await getApplicationDocumentsDirectory();

    final extension =
        image.path.split('.').last.toLowerCase();

    final fileName =
        'zayan_${DateTime.now().microsecondsSinceEpoch}.$extension';

    final destination =
        File('${directory.path}/$fileName');

    await File(image.path).copy(destination.path);

    return destination.path;
  }

  String _todayDate() {
    final now = DateTime.now();

    const months = [
      'জানুয়ারি',
      'ফেব্রুয়ারি',
      'মার্চ',
      'এপ্রিল',
      'মে',
      'জুন',
      'জুলাই',
      'আগস্ট',
      'সেপ্টেম্বর',
      'অক্টোবর',
      'নভেম্বর',
      'ডিসেম্বর',
    ];

    return '${now.day} ${months[now.month - 1]}, ${now.year}';
  }

  // ============================================================
  // STEP 5 - EDIT
  // ============================================================

  Future<void> _editItem(AlbumItem item) async {
    final titleController =
        TextEditingController(text: item.title);

    final dateController =
        TextEditingController(text: item.date);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '✏️ তথ্য পরিবর্তন',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'নাম / Caption',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'তারিখ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        item.title = titleController.text.trim();
        item.date = dateController.text.trim();
      });

      await _saveAlbum();
      _search(_searchController.text);
    }
  }

  // ============================================================
  // STEP 5 - DELETE
  // ============================================================

  Future<void> _deleteItem(AlbumItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🗑️ ছবি মুছে ফেলবেন?'),
          content: const Text(
            'এই ছবিটি album থেকে মুছে যাবে।',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('না'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('মুছে ফেলুন'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _items.removeWhere(
        (element) => element.id == item.id,
      );
    });

    try {
      final file = File(item.imagePath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    await _saveAlbum();
    _search(_searchController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ছবিটি মুছে ফেলা হয়েছে'),
        ),
      );
    }
  }

  // ============================================================
  // STEP 4 - FULL SCREEN IMAGE
  // ============================================================

  void _showFullScreenImage(AlbumItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenPhoto(
          item: item,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Zayan's Photo Album ❤️",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'নতুন ছবি',
            onPressed: _addPhoto,
            icon: const Icon(Icons.add_a_photo),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // ------------------------------------------------
                // BIRTHDAY HEADER
                // ------------------------------------------------

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.teal,
                        Colors.indigo,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                        color: Colors.black
                            .withOpacity(0.15),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '🎂',
                        style: TextStyle(fontSize: 45),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Zayan Chowdhury',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'আমাদের ছোট্ট রাজপুত্রের স্মৃতিগুলো ❤️',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),

                // ------------------------------------------------
                // SEARCH
                // ------------------------------------------------

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'ছবি খুঁজুন...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.teal,
                      ),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _search('');
                                  },
                                  icon:
                                      const Icon(Icons.clear),
                                )
                              : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ------------------------------------------------
                // PHOTO GRID
                // ------------------------------------------------

                Expanded(
                  child: _filteredItems.isEmpty
                      ? _emptyView()
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.70,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder:
                              (context, index) {
                            final item =
                                _filteredItems[index];

                            return _photoCard(item);
                          },
                        ),
                ),
              ],
            ),

      // ----------------------------------------------------------
      // ADD PHOTO BUTTON
      // ----------------------------------------------------------

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: _addPhoto,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('ছবি যোগ করুন'),
      ),
    );
  }

  // ============================================================
  // PHOTO CARD
  // ============================================================

  Widget _photoCard(AlbumItem item) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _showFullScreenImage(item);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(item.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.broken_image,
                          size: 60,
                        ),
                      );
                    },
                  ),

                  // Full screen icon
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black
                            .withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              10,
              8,
              4,
              2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),

                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editItem(item);
                    }

                    if (value == 'delete') {
                      _deleteItem(item);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              bottom: 10,
            ),
            child: Text(
              item.date,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Text(
              '📷',
              style: TextStyle(fontSize: 70),
            ),
            const SizedBox(height: 15),
            const Text(
              'এখনও কোনো ছবি নেই',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'নিচের "ছবি যোগ করুন" বাটনে চাপ দিয়ে\nZayan-এর ছবি যোগ করুন ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(
                Icons.add_photo_alternate,
              ),
              label: const Text('প্রথম ছবি যোগ করুন'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// FULL SCREEN PHOTO
// ================================================================

class FullScreenPhoto extends StatelessWidget {
  final AlbumItem item;

  const FullScreenPhoto({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(
            File(item.imagePath),
            fit: BoxFit.contain,
            errorBuilder:
                (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 80,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'ছবিটি পাওয়া যাচ্ছে না',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(15),
        color: Colors.black,
        child: SafeArea(
          child: Text(
            item.date,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}