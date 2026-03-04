import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

// ===========================
// إعدادات - غيّر البيانات دي
// ===========================
const String BOT_TOKEN = "YOUR_BOT_TOKEN";
const String BOT_CHAT_ID = "YOUR_TELEGRAM_USER_ID";
const String API_SECRET = "MY_SECRET_KEY_123";

void main() {
  runApp(const AnimeApp());
}

class AnimeApp extends StatelessWidget {
  const AnimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أنمي عربي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ===========================
// API Functions
// ===========================

Future<List<Map<String, dynamic>>> fetchAnimeList() async {
  await http.get(Uri.parse(
    'https://api.telegram.org/bot$BOT_TOKEN/sendMessage'
    '?chat_id=$BOT_CHAT_ID&text=/api $API_SECRET getanime'
  ));
  await Future.delayed(const Duration(seconds: 2));
  final updates = await http.get(Uri.parse(
    'https://api.telegram.org/bot$BOT_TOKEN/getUpdates?limit=1&offset=-1'
  ));
  final data = json.decode(updates.body);
  final results = data['result'] as List;
  if (results.isEmpty) return [];
  final text = results.last['message']?['text'] ?? '[]';
  try {
    final List<dynamic> animes = json.decode(text);
    return animes.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

Future<String> fetchAnimeImage(String name) async {
  try {
    final res = await http.get(Uri.parse(
      'https://api.jikan.moe/v4/anime?q=${Uri.encodeComponent(name)}&limit=1'
    ));
    final data = json.decode(res.body);
    return data['data'][0]['images']['jpg']['image_url'] ?? '';
  } catch (_) {
    return '';
  }
}

Future<List<int>> fetchEpisodes(String animeName) async {
  await http.get(Uri.parse(
    'https://api.telegram.org/bot$BOT_TOKEN/sendMessage'
    '?chat_id=$BOT_CHAT_ID&text=/api $API_SECRET getepisodes $animeName'
  ));
  await Future.delayed(const Duration(seconds: 2));
  final updates = await http.get(Uri.parse(
    'https://api.telegram.org/bot$BOT_TOKEN/getUpdates?limit=1&offset=-1'
  ));
  final data = json.decode(updates.body);
  final results = data['result'] as List;
  if (results.isEmpty) return [];
  final text = results.last['message']?['text'] ?? '{}';
  try {
    final Map<String, dynamic> epData = json.decode(text);
    final List<dynamic> eps = epData['episodes'] ?? [];
    return eps.cast<int>();
  } catch (_) {
    return [];
  }
}

Future<String?> fetchVideoUrl(String animeName, int epNum) async {
  await http.get(Uri.parse(
    'https://api.telegram.org/bot$BOT_TOKEN/sendMessage'
    '?chat_id=$BOT_CHAT_ID&text=/api $API_SECRET getfile $animeName $epNum'
  ));
  await Future.delayed(const Duration(seconds: 2));
  final updates = await http.get(Uri.parse(
    'https://api.telegram.org/bot$BOT_TOKEN/getUpdates?limit=1&offset=-1'
  ));
  final data = json.decode(updates.body);
  final results = data['result'] as List;
  if (results.isEmpty) return null;
  final text = results.last['message']?['text'] ?? '{}';
  try {
    final Map<String, dynamic> fileData = json.decode(text);
    final fileId = fileData['file_id'];
    if (fileId == null) return null;
    final fileRes = await http.get(Uri.parse(
      'https://api.telegram.org/bot$BOT_TOKEN/getFile?file_id=$fileId'
    ));
    final fileJson = json.decode(fileRes.body);
    final filePath = fileJson['result']['file_path'];
    return 'https://api.telegram.org/file/bot$BOT_TOKEN/$filePath';
  } catch (_) {
    return null;
  }
}

// ===========================
// الشاشة الرئيسية
// ===========================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> animeList = [];
  List<Map<String, dynamic>> filteredList = [];
  bool loading = true;
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAnime();
  }

  Future<void> loadAnime() async {
    setState(() => loading = true);
    try {
      final animes = await fetchAnimeList();
      List<Map<String, dynamic>> withImages = [];
      for (var anime in animes) {
        final img = await fetchAnimeImage(anime['name']);
        withImages.add({...anime, 'image': img});
      }
      setState(() {
        animeList = withImages;
        filteredList = withImages;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  void search(String query) {
    setState(() {
      filteredList = query.isEmpty
          ? animeList
          : animeList.where((a) =>
              a['name'].toString().toLowerCase().contains(query.toLowerCase())
            ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text('أنمي عربي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: loadAnime)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: searchCtrl,
              onChanged: search,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن أنمي...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white24,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : filteredList.isEmpty
              ? const Center(child: Text('مفيش أنميات!', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: loadAnime,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final anime = filteredList[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => EpisodesScreen(anime: anime),
                        )),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: anime['image'] != null && anime['image'].isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: anime['image'],
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            color: const Color(0xFF1565C0).withOpacity(0.1),
                                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            color: const Color(0xFF1565C0).withOpacity(0.2),
                                            child: const Icon(Icons.movie, color: Color(0xFF1565C0), size: 40),
                                          ),
                                        )
                                      : Container(
                                          color: const Color(0xFF1565C0).withOpacity(0.2),
                                          child: const Icon(Icons.movie, color: Color(0xFF1565C0), size: 40),
                                        ),
                                ),
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  child: Column(
                                    children: [
                                      Text(anime['name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      Text('${anime['episodes_count']} حلقة', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ===========================
// شاشة الحلقات
// ===========================

class EpisodesScreen extends StatefulWidget {
  final Map<String, dynamic> anime;
  const EpisodesScreen({super.key, required this.anime});

  @override
  State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  List<int> episodes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchEpisodes(widget.anime['name']).then((eps) {
      setState(() { episodes = eps; loading = false; });
    });
  }

  Future<void> openEpisode(int epNum) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final url = await fetchVideoUrl(widget.anime['name'], epNum);
    Navigator.pop(context);
    if (url != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => VideoScreen(url: url, title: '${widget.anime['name']} - حلقة $epNum'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فيه مشكلة في تحميل الحلقة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: Text(widget.anime['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.anime['image'] != null && widget.anime['image'].isNotEmpty
                      ? CachedNetworkImage(imageUrl: widget.anime['image'], width: 90, height: 120, fit: BoxFit.cover)
                      : Container(width: 90, height: 120, color: Colors.white24, child: const Icon(Icons.movie, color: Colors.white, size: 40)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(widget.anime['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                      const SizedBox(height: 8),
                      Text('🏷️ ${widget.anime['genre']}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      Text('📺 ${episodes.length} حلقة', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                : episodes.isEmpty
                    ? const Center(child: Text('مفيش حلقات', style: TextStyle(fontSize: 18, color: Colors.grey)))
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, childAspectRatio: 1.2, crossAxisSpacing: 8, mainAxisSpacing: 8,
                        ),
                        itemCount: episodes.length,
                        itemBuilder: (context, index) {
                          final ep = episodes[index];
                          return GestureDetector(
                            onTap: () => openEpisode(ep),
                            child: Container(
                              decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
                                  const SizedBox(height: 4),
                                  Text('$ep', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ===========================
// مشغل الفيديو
// ===========================

class VideoScreen extends StatefulWidget {
  final String url;
  final String title;
  const VideoScreen({super.key, required this.url, required this.title});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight, DeviceOrientation.portraitUp]);
    initPlayer();
  }

  Future<void> initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF1565C0),
          handleColor: const Color(0xFF1565C0),
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white12,
        ),
      );
      setState(() => loading = false);
    } catch (_) {
      setState(() { loading = false; error = 'فيه مشكلة في تحميل الفيديو'; });
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text(error!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
                    ],
                  )
                : Chewie(controller: _chewieController!),
      ),
    );
  }
}
