import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

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
      title: "Zayan's Media Album",
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
  String mediaBase64;
  bool isVideo;
  String title;
  String date;

  AlbumItem({
    required this.id,
    required this.mediaBase64,
    required this.isVideo,
    required this.title,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mediaBase64': mediaBase64,
      'isVideo': isVideo,
      'title': title,
      'date': date,
    };
  }

  factory AlbumItem.fromMap(Map<String, dynamic> map) {
    return AlbumItem(
      id: map['id'] ?? '',
      mediaBase64: map['mediaBase64'] ?? '',
      isVideo: map['isVideo'] ?? false,
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

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _saveAlbum() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList('zayan_media_items_v2', data);
  }

  Future<void> _loadAlbum() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getStringList('zayan_media_items_v2') ?? [];
    final loadedItems = <AlbumItem>[];

    for (final item in savedData) {
      try {
        loadedItems.add(AlbumItem.fromMap(jsonDecode(item)));
      } catch (_) {}
    }

    setState(() {
      _items = loadedItems;
      _filteredItems = List.from(_items);
      _loading = false;
    });
  }

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

  Future<void> _addMedia(bool isVideo) async {
    try {
      XFile? pickedFile;
      if (isVideo) {
        pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      } else {
        pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      }

      if (pickedFile == null) return;

      final Uint8List mediaBytes = await pickedFile.readAsBytes();
      final String base64Media = base64Encode(mediaBytes);

      final titleController = TextEditingController(text: isVideo ? 'Zayan-এর ভিডিও' : 'Zayan-এর ছবি');
      final dateController = TextEditingController(text: _todayDate());

      if (!mounted) return;

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              isVideo ? '🎥 ভিডিওর তথ্য' : '📷 ছবির তথ্য',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'ক্যাপশন / শিরোনাম',
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
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('বাতিল'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('যোগ করুন'),
              ),
            ],
          );
        },
      );

      if (result == true && titleController.text.trim().isNotEmpty) {
        final newItem = AlbumItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          mediaBase64: base64Media,
          isVideo: isVideo,
          title: titleController.text.trim(),
          date: dateController.text.trim(),
        );

        setState(() {
          _items.insert(0, newItem);
        });

        await _saveAlbum();
        _search(_searchController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isVideo ? "ভিডিও" : "ছবি"} যোগ হয়েছে ❤️'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ফাইল যোগ করা যায়নি: $e'),
          ),
        );
      }
    }
  }

  String _todayDate() {
    final now = DateTime.now();
    const months = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
    ];
    return '${now.day} ${months[now.month - 1]}, ${now.year}';
  }

  Future<void> _deleteItem(AlbumItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🗑️ মুছে ফেলবেন?'),
          content: const Text('এটি অ্যালবাম থেকে স্থায়ীভাবে মুছে যাবে।'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('না'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('মুছে ফেলুন'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _items.removeWhere((element) => element.id == item.id);
    });

    await _saveAlbum();
    _search(_searchController.text);
  }

  void _showMediaView(AlbumItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenMedia(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Zayan's Media Album ❤️",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.teal, Colors.indigo],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      Text('👑', style: TextStyle(fontSize: 45)),
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
                        'আমাদের রাজপুত্রের ছবি ও ভিডিও স্মৃতিসমূহ ❤️',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'খুঁজুন...',
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? const Center(child: Text('কোনো ছবি বা ভিডিও নেই'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return _mediaCard(item);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'img_btn',
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            onPressed: () => _addMedia(false),
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('ছবি'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'vid_btn',
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            onPressed: () => _addMedia(true),
            icon: const Icon(Icons.video_call),
            label: const Text('ভিডিও'),
          ),
        ],
      ),
    );
  }

  Widget _mediaCard(AlbumItem item) {
    final bytes = base64Decode(item.mediaBase64);

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showMediaView(item),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.isVideo
                      ? Container(
                          color: Colors.black87,
                          child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                        )
                      : Image.memory(bytes, fit: BoxFit.cover),
                  if (item.isVideo)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.videocam, color: Colors.white),
                    )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _deleteItem(item),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class FullScreenMedia extends StatefulWidget {
  final AlbumItem item;

  const FullScreenMedia({super.key, required this.item});

  @override
  State<FullScreenMedia> createState() => _FullScreenMediaState();
}

class _FullScreenMediaState extends State<FullScreenMedia> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      final bytes = base64Decode(widget.item.mediaBase64);
      final Uri videoUri = Uri.dataFromBytes(bytes, mimeType: 'video/mp4');
      _videoController = VideoPlayerController.networkUrl(videoUri)
        ..initialize().then((_) {
          setState(() {});
          _videoController?.play();
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(widget.item.mediaBase64);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.item.title),
      ),
      body: Center(
        child: widget.item.isVideo
            ? (_videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const CircularProgressIndicator())
            : Image.memory(bytes),
      ),
      floatingActionButton: widget.item.isVideo
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              child: Icon(
                _videoController != null && _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}