import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Method not allowed. Use POST.'},
    );
  }

  try {
    final formData = await context.request.formData();

    // Get form fields
    final userIdStr = formData.fields['user_id'];
    final description = formData.fields['description'];

    // Get photo file
    final photoFile = formData.files['photo'];

    // Parse user_id
    final userId = userIdStr != null ? int.tryParse(userIdStr) : null;

    // Validate required fields
    if (userId == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'User ID is required.'},
      );
    }

    if (photoFile == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Photo file is required.'},
      );
    }

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
        return Response.json(
          statusCode: 404,
          body: {'error': 'User not found.'},
        );
      }

      // Save photo file to uploads directory
      final uploadsDir = Directory('uploads/photos');
      if (!uploadsDir.existsSync()) {
        uploadsDir.createSync(recursive: true);
      }

      // Generate unique filename with proper extension
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalName = photoFile.name;

      // Ensure we have an extension
      String extension = '';
      if (originalName.contains('.')) {
        extension = '.${originalName.split('.').last.toLowerCase()}';
      } else {
        // Default to jpg if no extension
        extension = '.jpg';
      }

      // Validate image extension
      final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
      if (!validExtensions.contains(extension)) {
        await conn.close();
        return Response.json(
          statusCode: 400,
          body: {
            'error': 'Invalid file type. Allowed: jpg, jpeg, png, gif, webp',
          },
        );
      }

      final fileName = '${userId}_${timestamp}$extension';
      final filePath = '${uploadsDir.path}/$fileName';

      // Write file to disk - read all bytes from the stream
      final fileBytes = <int>[];
      await for (final chunk in photoFile.openRead()) {
        fileBytes.addAll(chunk);
      }

      print('Photo file size: ${fileBytes.length} bytes');

      if (fileBytes.isEmpty) {
        await conn.close();
        return Response.json(
          statusCode: 400,
          body: {'error': 'Photo file is empty or could not be read.'},
        );
      }

      final savedFile = File(filePath);
      await savedFile.writeAsBytes(fileBytes);

      print('Photo saved to: $filePath');

      // Insert photo into database
      final result = await conn.execute(
        '''INSERT INTO photos (user_id, description, image, created_at) 
           VALUES (:user_id, :description, :image, NOW())''',
        {
          'user_id': userId,
          'description': description ?? '',
          'image': fileName,
        },
      );

      await conn.close();

      return Response.json(
        statusCode: 201,
        body: {
          'message': 'Photo uploaded successfully.',
          'photo': {
            'id': result.lastInsertID.toInt(),
            'user_id': userId,
            'description': description,
            'image': '/uploads/photos/$fileName',
          },
        },
      );
    } catch (e) {
      await conn.close();
      rethrow;
    }
  } catch (e) {
    print('❌ Post Photo Error: $e');
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal server error: $e'},
    );
  }
}
