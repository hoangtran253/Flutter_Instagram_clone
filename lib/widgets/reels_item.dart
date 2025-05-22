import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  bool _isLiked = false;

  late final AnimationController _likeAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final Animation<double> _likeScaleAnimation = Tween<double>(
    begin: 1.0,
    end: 1.5,
  ).animate(
    CurvedAnimation(parent: _likeAnimationController, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _initVideo();
    _likeAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _likeAnimationController.reverse();
      }
    });
  }

  Future<void> _initVideo() async {
    final url = widget.reelData['videoUrl'];
    if (url == null) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    _controller!.setLooping(true);

    setState(() => _isInitialized = true);

    if (widget.currentlyPlaying) {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentlyPlaying && !_isPlaying && _isInitialized) {
      _controller?.play();
      setState(() => _isPlaying = true);
    } else if (!widget.currentlyPlaying && _isPlaying) {
      _controller?.pause();
      setState(() => _isPlaying = false);
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _onLikePressed() {
    setState(() => _isLiked = !_isLiked);
    if (_isLiked) _likeAnimationController.forward();
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
      children: [
        _isInitialized && _controller!.value.isInitialized
            ? GestureDetector(
              onTap: _togglePlayPause,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
            : const Center(child: CircularProgressIndicator()),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // UI Elements
        Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(children: [_buildLeftInfo(), _buildRightActions()]),
        ),

        // Play icon
        if (!_isPlaying)
          const Center(
            child: Icon(Icons.play_arrow, color: Colors.white, size: 64),
          ),
      ],
    );
  }

  Widget _buildLeftInfo() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage:
                    widget.reelData['avatarUrl'] != null
                        ? CachedNetworkImageProvider(
                          widget.reelData['avatarUrl'],
                        )
                        : null,
                radius: 20,
                backgroundColor: Colors.black,
                child:
                    widget.reelData['avatarUrl'] == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
              ),
              const SizedBox(width: 8),
              Text(
                widget.reelData['username'] ?? 'Người dùng',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.reelData['caption'] ?? '',
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.music_note, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('Original Audio', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightActions() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _likeAnimationController,
            builder:
                (_, child) => Transform.scale(
                  scale: _likeScaleAnimation.value,
                  child: IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.white,
                      size: 30,
                    ),
                    onPressed: _onLikePressed,
                  ),
                ),
          ),
          _buildAction(Icons.comment, '120'),
          _buildAction(Icons.send, ''),
          _buildAction(Icons.more_vert, ''),
        ],
      ),
    );
  }

  Widget _buildAction(IconData icon, String count) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 26),
        if (count.isNotEmpty)
          Text(
            count,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
