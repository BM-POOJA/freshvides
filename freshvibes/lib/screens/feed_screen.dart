import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_constants.dart';
import 'post_detail_screen.dart';
import 'package:video_player/video_player.dart';

class FeedScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const FeedScreen({super.key, required this.user});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _feedItems = [];
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 FeedScreen initState - Calling _loadFeed()');
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    debugPrint('⏰ _loadFeed called at ${DateTime.now()}');
    setState(() => _isLoading = true);
    try {
      debugPrint('🔄 Loading feed...');
      debugPrint('📸 Photos endpoint: ${ApiConstants.getAllPhotosEndpoint}');
      debugPrint('🎥 Videos endpoint: ${ApiConstants.getAllVideosEndpoint}');

      // Fetch photos and videos in parallel
      final results = await Future.wait([
        http.get(Uri.parse(ApiConstants.getAllPhotosEndpoint)),
        http.get(Uri.parse(ApiConstants.getAllVideosEndpoint)),
      ]);

      final photosResponse = results[0];
      final videosResponse = results[1];

      debugPrint('📸 Photos Response Status: ${photosResponse.statusCode}');
      debugPrint('📸 Photos Response Body: ${photosResponse.body}');
      debugPrint('🎥 Videos Response Status: ${videosResponse.statusCode}');
      debugPrint('🎥 Videos Response Body: ${videosResponse.body}');

      List<Map<String, dynamic>> allItems = [];

      // Parse photos
      if (photosResponse.statusCode == 200) {
        final photosData = jsonDecode(photosResponse.body);
        debugPrint('📸 Photos Data: $photosData');
        debugPrint('📸 Photos Key Exists: ${photosData.containsKey('photos')}');

        if (photosData['photos'] != null) {
          debugPrint('📸 Number of photos: ${photosData['photos'].length}');
          for (var photo in photosData['photos']) {
            debugPrint('📸 Adding photo: $photo');
            allItems.add({...photo, 'type': 'photo'});
          }
        } else {
          debugPrint('⚠️ Photos data is null');
        }
      } else {
        debugPrint(
          '❌ Photos request failed with status: ${photosResponse.statusCode}',
        );
      }

      // Parse videos
      if (videosResponse.statusCode == 200) {
        final videosData = jsonDecode(videosResponse.body);
        debugPrint('🎥 Videos Data: $videosData');
        debugPrint('🎥 Videos Key Exists: ${videosData.containsKey('videos')}');

        if (videosData['videos'] != null) {
          debugPrint('🎥 Number of videos: ${videosData['videos'].length}');
          for (var video in videosData['videos']) {
            debugPrint('🎥 Adding video: $video');
            // Fix video URL if it's a relative path
            String videoUrl = video['video_url'] ?? '';
            if (videoUrl.startsWith('/')) {
              videoUrl = '${ApiConstants.baseUrl}$videoUrl';
              debugPrint('🎥 Fixed video URL: $videoUrl');
            }
            allItems.add({...video, 'video_url': videoUrl, 'type': 'video'});
          }
        } else {
          debugPrint('⚠️ Videos data is null');
        }
      } else {
        debugPrint(
          '❌ Videos request failed with status: ${videosResponse.statusCode}',
        );
      }

      debugPrint('📊 Total items before sorting: ${allItems.length}');

      // Sort by created_at (newest first)
      allItems.sort((a, b) {
        final aTime = a['created_at'] ?? '';
        final bTime = b['created_at'] ?? '';
        return bTime.compareTo(aTime);
      });

      debugPrint('📊 Total items after sorting: ${allItems.length}');

      if (mounted) {
        setState(() {
          _feedItems = allItems;
          _isLoading = false;
        });
        debugPrint(
          '✅ Feed loaded successfully with ${_feedItems.length} items',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading feed: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading feed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'FreshVibes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              debugPrint('🔄 Refresh button pressed - Calling _loadFeed()');
              _loadFeed();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _feedItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No posts yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to share something!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _feedItems.length,
              itemBuilder: (context, index) {
                final item = _feedItems[index];
                return _buildFeedItem(item);
              },
            ),
    );
  }

  Widget _buildFeedItem(Map<String, dynamic> item) {
    final isVideo = item['type'] == 'video';
    final imageUrl = isVideo ? null : item['image'] ?? item['public_id'];
    final username = item['username'] ?? 'Unknown';
    final description = item['description'] ?? (isVideo ? item['title'] : '');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media Content
          if (!isVideo && imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[900],
                child: const Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
            )
          else
            _buildVideoPlayer(item),

          // Gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
          ),

          // Content overlay
          Positioned(
            bottom: 80,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                _buildActionButton(Icons.favorite_border, ''),
                const SizedBox(height: 24),
                _buildActionButton(Icons.comment_outlined, ''),
                const SizedBox(height: 24),
                _buildActionButton(Icons.share_outlined, ''),
                const SizedBox(height: 24),
                _buildActionButton(Icons.bookmark_border, ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(Map<String, dynamic> item) {
    final videoUrl = item['video_url'] ?? '';
    final itemId = item['id'] ?? 0;

    if (!_videoControllers.containsKey(itemId) && videoUrl.isNotEmpty) {
      debugPrint('🎬 Initializing video player for: $videoUrl');
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      controller
          .initialize()
          .then((_) {
            debugPrint('✅ Video initialized successfully');
            if (mounted) setState(() {});
            controller.setLooping(true);
            controller.play();
          })
          .catchError((error) {
            debugPrint('❌ Video initialization error: $error');
          });
      _videoControllers[itemId] = controller;
    }

    final controller = _videoControllers[itemId];

    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && controller.value.isInitialized)
          GestureDetector(
            onTap: () {
              setState(() {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
              });
            },
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          )
        else
          Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        if (controller != null && controller.value.isInitialized)
          Center(
            child: AnimatedOpacity(
              opacity: controller.value.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
        if (item['duration'] != null)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${item['duration']}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
