import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/add_reels_screen.dart';
import 'package:flutter_instagram_clone/widgets/reels_item.dart';

class ReelsScreen extends StatefulWidget {
  final int initialReelIndex;
  final String? userId;
  final String? initialReelId; // New parameter to identify specific reel

  const ReelsScreen({
    Key? key,
    this.initialReelIndex = 0,
    this.userId,
    this.initialReelId,
  }) : super(key: key);

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final List<Map<String, dynamic>> _reels = [];
  final List<String> _reelIds = []; // Keep track of document IDs
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialReelIndex);
    _currentIndex = widget.initialReelIndex;
    _loadReels();
  }

  Future<void> _loadReels() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('reels')
          .orderBy('postTime', descending: true);

      if (widget.userId != null) {
        query = query.where('uid', isEqualTo: widget.userId);
      }

      final snapshot = await query.get();

      final reelsData =
          snapshot.docs.map((doc) {
            _reelIds.add(doc.id); // Store the document ID
            final data = doc.data() as Map<String, dynamic>;
            // Add the document ID to the data for easier access
            data['reelId'] = doc.id;
            return data;
          }).toList();

      setState(() {
        _reels.addAll(reelsData);
        _isLoading = false;

        // If initialReelId is provided, find its index and scroll to it
        if (widget.initialReelId != null) {
          final index = _reelIds.indexOf(widget.initialReelId!);
          if (index != -1) {
            _currentIndex = index;
            // Use Future.delayed to ensure the PageView is built before scrolling
            Future.delayed(Duration.zero, () {
              _pageController.jumpToPage(index);
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi khi tải reels: $e';
        _isLoading = false;
      });
    }
  }

  void _addNewReel(Map<String, dynamic> reelData) {
    setState(() {
      _reels.insert(0, reelData);
    });
  }

  void _goToAddReel() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddReelScreen(onUpload: _addNewReel)),
    );
  }

  // Method to refresh specific reel data (for like/comment updates)
  Future<void> _refreshReelData(int index) async {
    if (index < 0 || index >= _reelIds.length) return;

    try {
      final reelId = _reelIds[index];
      DocumentSnapshot reelDoc =
          await FirebaseFirestore.instance
              .collection('reels')
              .doc(reelId)
              .get();

      if (reelDoc.exists) {
        final updatedData = reelDoc.data() as Map<String, dynamic>;
        updatedData['reelId'] = reelId;

        setState(() {
          _reels[index] = updatedData;
        });
      }
    } catch (e) {
      print('Error refreshing reel data: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _reels.isEmpty
              ? _buildEmptyState()
              : Stack(
                children: [
                  PageView.builder(
                    scrollDirection: Axis.vertical,
                    controller: _pageController,
                    itemCount: _reels.length,
                    onPageChanged:
                        (index) => setState(() {
                          _currentIndex = index;
                        }),
                    itemBuilder:
                        (_, index) => ReelItem(
                          reelData: _reels[index],
                          currentlyPlaying: index == _currentIndex,
                          onDataChanged: () => _refreshReelData(index),
                        ),
                  ),
                  _buildHeader(),
                ],
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.video_library_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Chưa có Reels nào',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Nhấn nút + để tạo Reels mới',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Reels',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            // Only show camera button if viewing own reels
            if (widget.userId == null ||
                widget.userId ==
                    FirebaseFirestore.instance.app.options.projectId)
              IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: _goToAddReel,
              ),
          ],
        ),
      ),
    );
  }
}
