import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  String path;
  final bool isVideo;
  String title;
  bool isFavorite;
  String folder;

  MediaItem({
    required this.path,
    required this.isVideo,
    this.title = 'Zayan-এর স্মৃতি',
    this.isFavorite = false,
    this.folder = 'Pictures',
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'isVideo': isVideo,
        'title': title,
        'isFavorite': isFavorite,
        'folder': folder,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        path: json['path'] as String,
        isVideo: json['isVideo'] as bool? ?? false,
        title: json['title'] as String? ?? 'Zayan-এর স্মৃতি',
        isFavorite: json['isFavorite'] as bool? ?? false,
        folder: json['folder'] as String? ?? 'Pictures',
      );
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
  final TextEditingController _folderController = TextEditingController();
  Directory? _albumDirectory;
  final Set<String> _folders = {'Pictures'};
  bool _showOnlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  Future<Directory> _getAlbumDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}ZayanAlbum');
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _loadAlbum() async {
    final directory = await _getAlbumDirectory();
    final metadata = File('${directory.path}${Platform.pathSeparator}album.json');
    if (!await metadata.exists()) {
      if (mounted) setState(() => _albumDirectory = directory);
      return;
    }
    try {
      final decoded = jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
      final items = (decoded['items'] as List<dynamic>? ?? [])
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .where((item) => File(item.path).existsSync())
          .toList();
      final folders = (decoded['folders'] as List<dynamic>? ?? []).whereType<String>();
      if (!mounted) return;
      setState(() {
        _albumDirectory = directory;
        _mediaList.addAll(items);
        _folders.addAll(folders);
        _applyFilter();
      });
    } catch (_) {
      if (mounted) setState(() => _albumDirectory = directory);
    }
  }

  Future<void> _saveAlbum() async {
    final directory = _albumDirectory ?? await _getAlbumDirectory();
    _albumDirectory = directory;
    final metadata = File('${directory.path}${Platform.pathSeparator}album.json');
    await metadata.writeAsString(jsonEncode({
      'items': _mediaList.map((item) => item.toJson()).toList(),
      'folders': _folders.toList(),
    }));
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    final imported = <MediaItem>[];
    for (final image in images) {
      imported.add(await _importFile(image.path, isVideo: false));
    }
    setState(() {
      _mediaList.addAll(imported);
      _applyFilter();
    });
    await _saveAlbum();
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    final imported = await _importFile(video.path, isVideo: true);
    setState(() {
      _mediaList.add(imported);
      _applyFilter();
    });
    await _saveAlbum();
  }

  Future<MediaItem> _importFile(String sourcePath, {required bool isVideo}) async {
    final directory = _albumDirectory ?? await _getAlbumDirectory();
    _albumDirectory = directory;
    final folder = Directory('${directory.path}${Platform.pathSeparator}Pictures');
    await folder.create(recursive: true);
    final sourceName = sourcePath.split(RegExp(r'[\\/]')).last;
    final dot = sourceName.lastIndexOf('.');
    final stem = dot > 0 ? sourceName.substring(0, dot) : sourceName;
    final extension = dot > 0 ? sourceName.substring(dot) : '';
    var destination = File('${folder.path}${Platform.pathSeparator}$sourceName');
    var counter = 1;
    while (await destination.exists()) {
      destination = File(
        '${folder.path}${Platform.pathSeparator}$stem ($counter)$extension',
      );
      counter++;
    }
    await File(sourcePath).copy(destination.path);
    return MediaItem(path: destination.path, isVideo: isVideo);
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
    File(itemToDelete.path).delete().then<void>((_) {}, onError: (_) {});
    setState(() {
      _mediaList.remove(itemToDelete);
      _applyFilter();
    });
    _saveAlbum();
  }

  Future<void> _renameMedia(MediaItem item) async {
    final controller = TextEditingController(text: _fileName(item.path));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename picture'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Rename')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final oldFile = File(item.path);
    final extension = _extension(item.path);
    final newName = name.trim().endsWith(extension) ? name.trim() : '${name.trim()}$extension';
    final newPath = '${oldFile.parent.path}${Platform.pathSeparator}$newName';
    if (newPath == item.path) return;
    if (await File(newPath).exists()) {
      if (mounted) _showMessage('A file with that name already exists');
      return;
    }
    await oldFile.rename(newPath);
    setState(() => item.path = newPath);
    await _saveAlbum();
  }

  String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

  String _extension(String path) {
    final name = _fileName(path);
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot) : '';
  }

  Future<void> _showDetails(MediaItem item) async {
    final file = File(item.path);
    final size = await file.length();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Picture details'),
        content: SelectableText(
          'Name: ${_fileName(item.path)}\n'
          'Folder: ${item.folder}\n'
          'Size: ${(size / 1024).toStringAsFixed(1)} KB\n'
          'Location: ${item.path}',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<String?> _chooseFolder({String? title}) async {
    _folderController.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Choose folder'),
        content: DropdownButtonFormField<String>(
          initialValue: _folders.first,
          items: _folders
              .map((folder) => DropdownMenuItem(value: folder, child: Text(folder)))
              .toList(),
          onChanged: (value) => _folderController.text = value ?? _folders.first,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, _folderController.text.isEmpty ? _folders.first : _folderController.text),
            child: const Text('Choose'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create folder'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    final cleanName = name?.trim() ?? '';
    if (cleanName.isEmpty || _folders.contains(cleanName)) return;
    final directory = _albumDirectory ?? await _getAlbumDirectory();
    await Directory('${directory.path}${Platform.pathSeparator}$cleanName').create(recursive: true);
    setState(() => _folders.add(cleanName));
    await _saveAlbum();
  }

  Future<void> _copyOrMove(MediaItem item, {required bool move}) async {
    final folder = await _chooseFolder(title: move ? 'Move to folder' : 'Copy to folder');
    if (folder == null) return;
    final directory = _albumDirectory ?? await _getAlbumDirectory();
    final targetDirectory = Directory('${directory.path}${Platform.pathSeparator}$folder');
    await targetDirectory.create(recursive: true);
    final targetPath = '${targetDirectory.path}${Platform.pathSeparator}${_fileName(item.path)}';
    if (await File(targetPath).exists()) {
      if (mounted) _showMessage('A file with that name already exists');
      return;
    }
    if (move) {
      await File(item.path).rename(targetPath);
      setState(() {
        item.path = targetPath;
        item.folder = folder;
      });
    } else {
      await File(item.path).copy(targetPath);
    }
    await _saveAlbum();
  }

  Future<void> _shareMedia(MediaItem item) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(item.path)], text: item.title));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
              _saveAlbum();
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
            icon: const Icon(Icons.create_new_folder, color: Colors.white),
            onPressed: _createFolder,
            tooltip: 'Create folder',
          ),
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
                                          _saveAlbum();
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
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: Colors.teal),
                                      onSelected: (action) {
                                        switch (action) {
                                          case 'rename':
                                            _renameMedia(item);
                                            break;
                                          case 'details':
                                            _showDetails(item);
                                            break;
                                          case 'copy':
                                            _copyOrMove(item, move: false);
                                            break;
                                          case 'move':
                                            _copyOrMove(item, move: true);
                                            break;
                                          case 'share':
                                            _shareMedia(item);
                                            break;
                                          case 'delete':
                                            _deleteMedia(index);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                                        PopupMenuItem(value: 'details', child: Text('Picture details')),
                                        PopupMenuItem(value: 'copy', child: Text('Copy to folder')),
                                        PopupMenuItem(value: 'move', child: Text('Move to folder')),
                                        PopupMenuItem(value: 'share', child: Text('Share to WhatsApp / Facebook')),
                                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                                      ],
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