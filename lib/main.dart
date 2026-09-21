import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const ZayanMediaApp());
}

class ZayanMediaApp extends StatelessWidget {
  const ZayanMediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Zayan's Media Album",
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class MediaItem {
  final String path;
  final bool isVideo;
  String title;
  bool isFavorite;

  MediaItem({
    required this.path,
    required this.isVideo,
    this.title = 'Zayan-এর স্মৃতি',
    this.isFavorite = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<MediaItem> _mediaList = [];
  final List<MediaItem> _filteredList = [];
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlyFavorites = false;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() {
      for (var img in images) {
        _mediaList.add(MediaItem(path: img.path, isVideo: false));
      }
      _applyFilter();
    });
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    setState(() {
      _mediaList.add(MediaItem(path: video.path, isVideo: true));
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    _filteredList
      ..clear()
      ..addAll(_mediaList.where((item) {
        final matchesQuery = item.title.toLowerCase().contains(query);
        final matchesFav = _showOnlyFavorites ? item.isFavorite : true;
        return matchesQuery && matchesFav;
      }));
  }

  void _filterMedia(String query) {
    setState(() {
      _applyFilter();
    });
  }

  void _deleteMedia(int index) {
    if (index < 0 || index >= _filteredList.length) return;

    final itemToDelete = _filteredList[index];
    setState(() {
      _mediaList.remove(itemToDelete);
      _applyFilter();
    });
  }

  void _editTitle(MediaItem item) {
    final controller = TextEditingController(text: item.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ক্যাপশন পরিবর্তন করুন'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'স্মৃতির নাম লিখুন...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.title = controller.text.trim().isEmpty
                    ? 'Zayan-এর স্মৃতি'
                    : controller.text.trim();
                _applyFilter();
              });
              Navigator.pop(context);
              controller.dispose();
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  void _openImageViewer(int initialIndex) {
    if (initialIndex < 0 || initialIndex >= _filteredList.length) return;

    final controller = PageController(initialPage: initialIndex);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              _filteredList[initialIndex].title,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: PageView.builder(
            controller: controller,
            itemCount: _filteredList.length,
            itemBuilder: (context, index) {
              final item = _filteredList[index];
              if (item.isVideo) {
                return const Center(
                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 80),
                );
              }
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(File(item.path)),
                ),
              );
            },
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Zayan's Media Album ❤️",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
                _applyFilter();
              });
            },
            tooltip: 'পছন্দের তালিকা',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text("👑", style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                const Text(
                  "Zayan Chowdhury",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "আমাদের রাজপুত্রের ছবি ও ভিডিও স্মৃতিসমূহ ❤️",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterMedia,
                decoration: const InputDecoration(
                  hintText: "খুঁজুন...",
                  prefixIcon: Icon(Icons.search, color: Colors.teal),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredList.isEmpty
                ? const Center(
                    child: Text(
                      "কোনো ছবি বা ভিডিও পাওয়া যায়নি!",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      return GestureDetector(
                        onTap: () => _openImageViewer(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(15),
                                        ),
                                        child: item.isVideo
                                            ? Container(
                                                color: Colors.black87,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.play_circle_fill,
                                                    color: Colors.white,
                                                    size: 48,
                                                  ),
                                                ),
                                              )
                                            : Image.file(
                                                File(item.path),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            item.isFavorite = !item.isFavorite;
                                            _applyFilter();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black38,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            item.isFavorite
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: item.isFavorite
                                                ? Colors.red
                                                : Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _editTitle(item),
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _editTitle(item),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.teal,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _deleteMedia(index),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
              label: const Text(
                "ছবি",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_call, color: Colors.white),
              label: const Text(
                "ভিডিও",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}