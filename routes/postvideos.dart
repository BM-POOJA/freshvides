import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';
import 'package:postgres/postgres.dart';
// ignore: directives_ordering
import 'package:http/http.dart' as http;

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
          Sql.named('SELECT id FROM signup WHERE id = @userId'),
          parameters: {'userId': userId},
        );

        if (userCheck.isEmpty) {
          await conn.close();
          _usersCurrentlyUploading.remove(userId);
          return Response.json(
            statusCode: 404,
            body: {'error': 'User not found.'},
          );
        }

        // Read video file bytes
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

        // Upload to Cloudinary
        final cloudinaryUrl =
            'https://api.cloudinary.com/v1_1/${Platform.environment['CLOUDINARY_CLOUD_NAME']}/video/upload';

        final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
        request.fields['upload_preset'] =
            'freshvides_preset'; // Create this in Cloudinary
        request.fields['public_id'] =
            'videos/${userId}_${DateTime.now().millisecondsSinceEpoch}';
        request.fields['resource_type'] = 'video';

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: videoFile.name,
          ),
        );

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode != 200) {
          await conn.close();
          _usersCurrentlyUploading.remove(userId);
          print('Cloudinary error: $responseBody');
          return Response.json(
            statusCode: 500,
            body: {'error': 'Failed to upload to Cloudinary'},
          );
        }

        final cloudinaryResponse = jsonDecode(responseBody);
        final videoUrl = cloudinaryResponse['secure_url'];
        final publicId = cloudinaryResponse['public_id'];

        print('✅ Video uploaded to Cloudinary: $videoUrl');

        // Insert video into database with Cloudinary URL
        final result = await conn.execute(
          Sql.named(
              '''INSERT INTO videos (user_id, title, description, video_url, video_type, duration, created_at) 
             VALUES (@user_id, @title, @description, @video_url, @video_type, @duration, NOW()) RETURNING id'''),
          parameters: {
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
              'id': result[0][0] as int,
              'user_id': userId,
              'title': title,
              'description': description,
              'video_url': videoUrl,
              'video_type': videoType,
              'duration': duration,
              'public_id': publicId,
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
