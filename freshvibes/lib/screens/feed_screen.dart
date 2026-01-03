import 'package:flutter/material.dart';

class FeedScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const FeedScreen({super.key, required this.user});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Sample data - Replace with API data later
  final List<Map<String, dynamic>> _feedItems = [
    {
      'type': 'image',
      'url': 'https://picsum.photos/400/600?random=1',
      'username': 'john_doe',
      'description': 'Beautiful sunset view 🌅',
    },
    {
      'type': 'video',
      'thumbnail': 'https://picsum.photos/400/600?random=2',
      'username': 'jane_smith',
      'description': 'Amazing dance performance! 💃',
    },
    {
      'type': 'image',
      'url': 'https://picsum.photos/400/600?random=3',
      'username': 'travel_buddy',
      'description': 'Exploring new places ✈️',
    },
    {
      'type': 'image',
      'url': 'https://picsum.photos/400/600?random=4',
      'username': 'foodie_life',
      'description': 'Delicious meal today! 🍕',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
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
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemCount: _feedItems.length,
        itemBuilder: (context, index) {
          final item = _feedItems[index];
          return _buildFeedItem(item);
        },
      ),
    );
  }

  Widget _buildFeedItem(Map<String, dynamic> item) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Media Content
        if (item['type'] == 'image')
          Image.network(
            item['url'],
            fit: BoxFit.cover,
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
          Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item['thumbnail'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.broken_image,
                    size: 64,
                    color: Colors.grey,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),

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
                  Text(
                    item['username'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item['description'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        // Action buttons
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              _buildActionButton(Icons.favorite_border, '12.5K'),
              const SizedBox(height: 24),
              _buildActionButton(Icons.comment_outlined, '1.2K'),
              const SizedBox(height: 24),
              _buildActionButton(Icons.share_outlined, '845'),
              const SizedBox(height: 24),
              _buildActionButton(Icons.bookmark_border, ''),
            ],
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
