import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/add_reels_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({Key? key}) : super(key: key);

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  // Danh sách video reels
  final List<Map<String, dynamic>> _reels = [];
  int _currentReelIndex = 0;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadReelsFromFirestore();
  }

  void _loadReelsFromFirestore() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('reels')
            .orderBy('postTime', descending: true)
            .get();
    final reelsData = snapshot.docs.map((doc) => doc.data()).toList();

    setState(() {
      _reels.addAll(reelsData.cast<Map<String, dynamic>>());
    });
  }

  // Thêm video mới vào danh sách reels
  void _addNewReel(Map<String, dynamic> reelData) {
    setState(() {
      _reels.add(reelData);
    });
  }

  // Mở màn hình tạo reels mới
  void _navigateToAddReelScreen() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddReelScreen(onUpload: _addNewReel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _reels.isEmpty
              ? _buildEmptyState()
              : Stack(children: [_buildReelsPageView(), _buildHeader()]),
    );
  }

  // Hiển thị khi chưa có reels nào
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'Chưa có Reels nào',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Nhấn nút + để tạo Reels mới',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Header của trang Reels
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Reels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.camera_alt, color: Colors.white),
            onPressed: _navigateToAddReelScreen,
          ),
        ],
      ),
    );
  }

  // PageView để lướt giữa các reels
  Widget _buildReelsPageView() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _reels.length,
      onPageChanged: (index) {
        setState(() {
          _currentReelIndex = index;
        });
      },
      itemBuilder: (context, index) {
        return ReelItem(
          reelData: _reels[index],
          currentlyPlaying: _currentReelIndex == index,
        );
      },
    );
  }
}

// Widget hiển thị một reel riêng lẻ
class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reelData;
  final bool currentlyPlaying;

  const ReelItem({
    Key? key,
    required this.reelData,
    required this.currentlyPlaying,
  }) : super(key: key);

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;

  // Quản lý trạng thái like
  bool _isLiked = false;

  // Animation controller cho tim
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();

    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _likeScaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.easeOut),
    );

    _likeAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _likeAnimationController.reverse();
      }
    });
  }

  @override
  void didUpdateWidget(ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentlyPlaying && _controller != null && _isInitialized) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    } else if (!widget.currentlyPlaying && _controller != null && _isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _initializeVideoPlayer() async {
    final videoUrl = widget.reelData['videoUrl'];
    _controller = VideoPlayerController.network(videoUrl);

    await _controller!.initialize();
    _controller!.setLooping(true);

    setState(() {
      _isInitialized = true;
    });

    if (widget.currentlyPlaying) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller!.play() : _controller!.pause();
    });
  }

  // Hàm xử lý khi bấm nút tim
  void _onLikePressed() {
    setState(() {
      _isLiked = !_isLiked;
    });

    // Bật animation scale khi like
    if (_isLiked) {
      _likeAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _isInitialized
            ? GestureDetector(
              onTap: _togglePlayPause,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            )
            : Center(child: CircularProgressIndicator()),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.6),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        if (!_isPlaying && _isInitialized)
          Center(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 50),
            ),
          ),

        _buildOverlayUI(),
      ],
    );
  }

  Widget _buildOverlayUI() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          widget.reelData['avatarUrl'] != null
                              ? NetworkImage(widget.reelData['avatarUrl'])
                              : null,
                      backgroundColor: Colors.grey[700],
                      child:
                          widget.reelData['avatarUrl'] == null
                              ? Icon(Icons.person, color: Colors.white)
                              : null,
                    ),
                    SizedBox(width: 10),
                    Text(
                      widget.reelData['username'] ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 10),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'Follow',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        side: BorderSide(color: Colors.white),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        minimumSize: Size(0, 30),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    widget.reelData['caption'] ?? '',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.music_note, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Original Audio',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated nút tim
                AnimatedBuilder(
                  animation: _likeAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _likeScaleAnimation.value,
                      child: IconButton(
                        icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.white,
                          size: 28,
                        ),
                        onPressed: _onLikePressed,
                      ),
                    );
                  },
                ),

                _buildActionButton(Icons.chat_bubble_outline, '354'),
                _buildActionButton(Icons.send, ''),
                _buildActionButton(Icons.more_vert, ''),
                SizedBox(height: 10),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Icon(Icons.queue_music, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String count) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 28),
          onPressed: () {},
        ),
        if (count.isNotEmpty)
          Text(count, style: TextStyle(color: Colors.white, fontSize: 12)),
        SizedBox(height: 8),
      ],
    );
  }
}
