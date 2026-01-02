import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';

/// Track users who are currently uploading (to prevent multiple uploads)
final Set<int> _usersCurrentlyUploading = {};

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.post:
      return _postVideo(context);

    default:
      return Response.json(
        statusCode: 405,
        body: {'error': 'Method not allowed. Use GET or POST.'},
      );
  }
}

/// POST - Upload a new video (one at a time, max 30 seconds) using FormData
Future<Response> _postVideo(RequestContext context) async {
  try {
    final formData = await context.request.formData();

    // Get form fields
    final userIdStr = formData.fields['user_id'];
    final title = formData.fields['title'];
    final description = formData.fields['description'];
    final videoType = formData.fields['video_type'] ?? 'other';
    final durationStr = formData.fields['duration'];

    // Get video file
    final videoFile = formData.files['video'];

    // Parse user_id
    final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
    final duration = durationStr != null ? int.tryParse(durationStr) : null;

    // Validate required fields
    if (userId == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'User ID is required.'},
      );
    }

    if (title == null || title.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Title is required.'},
      );
    }

    if (videoFile == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Video file is required.'},
      );
    }

    if (duration == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Video duration is required.'},
      );
    }

    // Check video duration limit (max 30 seconds)
    if (duration > 30) {
      return Response.json(
        statusCode: 400,
        body: {
          'error':
              'Video duration exceeds limit. Maximum allowed is 30 seconds.',
          'max_duration': 30,
          'your_duration': duration,
        },
      );
    }

    // Check if user is already uploading
    if (_usersCurrentlyUploading.contains(userId)) {
      return Response.json(
        statusCode: 429,
        body: {
          'error':
              'You can only upload one video at a time. Please wait for your current upload to complete.',
        },
      );
    }

    // Mark user as uploading
    _usersCurrentlyUploading.add(userId);

    try {
      // Get database connection
      final conn = await DatabaseHelper.getConnection();

      try {
        // Verify user exists
        final userCheck = await conn.execute(
          'SELECT id FROM signup WHERE id = :userId',
          {'userId': userId},
        );

        if (userCheck.rows.isEmpty) {
          await conn.close();
          _usersCurrentlyUploading.remove(userId);
          return Response.json(
            statusCode: 404,
            body: {'error': 'User not found.'},
          );
        }

        // Save video file to uploads directory
        final uploadsDir = Directory('uploads/videos');
        if (!uploadsDir.existsSync()) {
          uploadsDir.createSync(recursive: true);
        }

        // Generate unique filename with proper extension
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final originalName = videoFile.name;
        // Ensure we have an extension
        String extension = '';
        if (originalName.contains('.')) {
          extension = '.${originalName.split('.').last}';
        } else {
          // Default to mp4 if no extension
          extension = '.mp4';
        }
        final fileName = '${userId}_${timestamp}$extension';
        final filePath = '${uploadsDir.path}/$fileName';

        // Write file to disk - read all bytes from the stream
        final fileBytes = <int>[];
        await for (final chunk in videoFile.openRead()) {
          fileBytes.addAll(chunk);
        }

        print('Video file size: ${fileBytes.length} bytes');

        if (fileBytes.isEmpty) {
          await conn.close();
          _usersCurrentlyUploading.remove(userId);
          return Response.json(
            statusCode: 400,
            body: {'error': 'Video file is empty or could not be read.'},
          );
        }

        final savedFile = File(filePath);
        await savedFile.writeAsBytes(fileBytes);

        print('Video saved to: $filePath');

        // Video URL (file name to be used with /video endpoint)
        final videoUrl = fileName;

        // Insert video into database
        final result = await conn.execute(
          '''INSERT INTO videos (user_id, title, description, video_url, video_type, duration, created_at) 
             VALUES (:user_id, :title, :description, :video_url, :video_type, :duration, NOW())''',
          {
            'user_id': userId,
            'title': title,
            'description': description ?? '',
            'video_url': videoUrl,
            'video_type': videoType,
            'duration': duration,
          },
        );

        await conn.close();

        // Remove user from uploading set
        _usersCurrentlyUploading.remove(userId);

        return Response.json(
          statusCode: 201,
          body: {
            'message': 'Video posted successfully.',
            'video': {
              'id': result.lastInsertID.toInt(),
              'user_id': userId,
              'title': title,
              'description': description,
              'video_url': '/uploads/videos/$fileName',
              'video_type': videoType,
              'duration': duration,
              'file_name': fileName,
            },
          },
        );
      } catch (e) {
        await conn.close();
        rethrow;
      }
    } catch (e) {
      // Remove user from uploading set on error
      _usersCurrentlyUploading.remove(userId);
      rethrow;
    }
  } catch (e) {
    print('❌ Post Video Error: $e');
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal server error: $e'},
    );
  }
}

/// GET - Get all videos or videos by user_id
