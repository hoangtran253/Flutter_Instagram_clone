import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/data/model/adminmodel.dart';
import 'package:intl/intl.dart';

class ReelsManagementPage extends StatefulWidget {
  final AdminService adminService;

  const ReelsManagementPage({Key? key, required this.adminService})
    : super(key: key);

  @override
  _ReelsManagementPageState createState() => _ReelsManagementPageState();
}

class _ReelsManagementPageState extends State<ReelsManagementPage> {
  List<Map<String, dynamic>> _reels = [];
  List<Map<String, dynamic>> _filteredReels = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'newest'; // 'newest', 'oldest', 'popular'

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final reels = await widget.adminService.getAllReels();
      setState(() {
        _reels = reels;
        _filterAndSortReels();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reels: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load reels')));
    }
  }

  void _filterAndSortReels() {
    setState(() {
      _filteredReels =
          _reels.where((reel) {
            final caption = reel['caption']?.toString().toLowerCase() ?? '';
            final username = reel['username']?.toString().toLowerCase() ?? '';
            final query = _searchQuery.toLowerCase();
            return caption.contains(query) || username.contains(query);
          }).toList();

      _filteredReels.sort((a, b) {
        if (_sortBy == 'newest') {
          final DateTime aTime = a['postTime'].toDate();
          final DateTime bTime = b['postTime'].toDate();
          return bTime.compareTo(aTime);
        } else if (_sortBy == 'oldest') {
          final DateTime aTime = a['postTime'].toDate();
          final DateTime bTime = b['postTime'].toDate();
          return aTime.compareTo(bTime);
        } else if (_sortBy == 'popular') {
          final int aLikes = a['likes']?.length ?? 0;
          final int bLikes = b['likes']?.length ?? 0;
          return bLikes.compareTo(aLikes);
        }
        return 0;
      });
    });
  }

  Future<void> _deleteReel(String reelId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Reel'),
            content: Text(
              'Are you sure you want to delete this reel by $username?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('DELETE'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await widget.adminService.deleteReel(reelId);
        await _loadReels();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reel deleted successfully')));
      } catch (e) {
        print('Error deleting reel: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete reel')));
      }
    }
  }

  void _showReelDetails(Map<String, dynamic> reel) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              reel['avatarUrl'] != null
                                  ? NetworkImage(reel['avatarUrl'])
                                  : null,
                          child:
                              reel['avatarUrl'] == null
                                  ? Text(reel['username'][0].toUpperCase())
                                  : null,
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reel['username'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MMM d, yyyy - HH:mm',
                              ).format(reel['postTime'].toDate()),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _deleteReel(reel['reelId'], reel['username']);
                          },
                          tooltip: 'Delete Reel',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (reel['thumbnailUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              reel['thumbnailUrl'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 300,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 300,
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 300,
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            height: 300,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.videocam_off,
                                color: Colors.grey[400],
                                size: 48,
                              ),
                            ),
                          ),
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            icon: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 36,
                            ),
                            onPressed: () {
                              // TODO: Implement video playback with video player package
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Video URL: ${reel['videoUrl']}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          '${reel['likes']?.length ?? 0} likes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.comment, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          '${reel['comments'] ?? 0} comments',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(reel['caption'] ?? '', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 16),
                    Text(
                      'Reel ID: ${reel['reelId']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      'User ID: ${reel['uid']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('CLOSE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reels Management')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by caption or username',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterAndSortReels();
                    });
                  },
                ),
                SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Newest First'),
                        selected: _sortBy == 'newest',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _sortBy = 'newest';
                              _filterAndSortReels();
                            });
                          }
                        },
                      ),
                      SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Oldest First'),
                        selected: _sortBy == 'oldest',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _sortBy = 'oldest';
                              _filterAndSortReels();
                            });
                          }
                        },
                      ),
                      SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Most Popular'),
                        selected: _sortBy == 'popular',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _sortBy = 'popular';
                              _filterAndSortReels();
                            });
                          }
                        },
                      ),
                      SizedBox(width: 16),
                      Text(
                        '${_filteredReels.length} reels',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredReels.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No reels found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadReels,
                      child: GridView.builder(
                        padding: EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: _filteredReels.length,
                        itemBuilder: (context, index) {
                          final reel = _filteredReels[index];
                          return GestureDetector(
                            onTap: () => _showReelDetails(reel),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child:
                                      reel['thumbnailUrl'] != null
                                          ? Image.network(
                                            reel['thumbnailUrl'],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            loadingBuilder: (
                                              context,
                                              child,
                                              progress,
                                            ) {
                                              if (progress == null)
                                                return child;
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  value:
                                                      progress.expectedTotalBytes !=
                                                              null
                                                          ? progress
                                                                  .cumulativeBytesLoaded /
                                                              progress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                ),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      color: Colors.grey[300],
                                                      child: Icon(
                                                        Icons.error,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                          )
                                          : Container(
                                            color: Colors.grey[300],
                                            child: Icon(
                                              Icons.videocam,
                                              color: Colors.grey[400],
                                              size: 64,
                                            ),
                                          ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black45,
                                    radius: 14,
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
