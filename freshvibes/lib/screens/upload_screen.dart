import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_constants.dart';
import 'package:video_player/video_player.dart';

class UploadScreen extends StatefulWidget {
  final File mediaFile;
  final bool isVideo;
  final Map<String, dynamic> user;

  const UploadScreen({
    super.key,
    required this.mediaFile,
    required this.isVideo,
    required this.user,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isUploading = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    // Only initialize video controller if user wants to preview
    // Don't auto-play to save time
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  void _initializeVideo() async {
    _videoController = VideoPlayerController.file(widget.mediaFile);
    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Video preview initialization error: $e');
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _titleController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _uploadMedia() async {
    debugPrint('📤 Starting upload process...');
    debugPrint('📁 Media type: ${widget.isVideo ? "Video" : "Photo"}');

    if (widget.isVideo && _titleController.text.trim().isEmpty) {
      debugPrint('⚠️ Upload cancelled: Title is required for videos');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter a title'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      return;
    }

    // Show uploading message and immediately go back
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text('Uploading ${widget.isVideo ? "video" : "photo"}...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 30),
        ),
      );

      // Close the upload screen immediately
      Navigator.pop(context);
    }

    // Continue upload in background
    try {
      final endpoint = widget.isVideo
          ? ApiConstants.postVideosEndpoint
          : ApiConstants.postPhotosEndpoint;

      debugPrint('🌐 Endpoint: $endpoint');
      debugPrint('👤 User ID: ${widget.user['id']}');
      debugPrint('📝 Description: ${_descriptionController.text.trim()}');
      if (widget.isVideo) {
        debugPrint('📺 Title: ${_titleController.text.trim()}');
      }
      debugPrint('📂 File path: ${widget.mediaFile.path}');

      final request = http.MultipartRequest('POST', Uri.parse(endpoint));

      request.fields['user_id'] = widget.user['id'].toString();
      request.fields['description'] = _descriptionController.text.trim();

      if (widget.isVideo) {
        request.fields['title'] = _titleController.text.trim();
        request.fields['duration'] = '0';
        debugPrint('🎬 Adding video file to request...');
        request.files.add(
          await http.MultipartFile.fromPath('video', widget.mediaFile.path),
        );
      } else {
        debugPrint('📸 Adding photo file to request...');
        request.files.add(
          await http.MultipartFile.fromPath('photo', widget.mediaFile.path),
        );
      }

      debugPrint('📡 Sending request...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Upload successful!');
      } else {
        debugPrint('❌ Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          widget.isVideo ? 'New Video' : 'New Photo',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isUploading ? null : _uploadMedia,
              child: const Text(
                'Upload',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Media Preview
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.grey[900],
              child: widget.isVideo
                  ? (_videoController != null &&
                            _videoController!.value.isInitialized
                        ? GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: _videoController!.value.size.width,
                                    height: _videoController!.value.size.height,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _videoController!.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(widget.mediaFile, fit: BoxFit.contain),
                              Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ],
                          ))
                  : Image.file(widget.mediaFile, fit: BoxFit.contain),
            ),
          ),

          // Description Input Area
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.grey[900],
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isVideo) ...[
                      const Text(
                        'Title',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter video title',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        enabled: !_isUploading,
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 4,
                      enabled: !_isUploading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
