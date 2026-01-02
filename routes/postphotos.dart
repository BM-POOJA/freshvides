import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';
import 'package:http/http.dart' as http;

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

      // Validate image extension
      final originalName = photoFile.name;
      String extension = '';
      if (originalName.contains('.')) {
        extension = originalName.split('.').last.toLowerCase();
      } else {
        extension = 'jpg';
      }

      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!validExtensions.contains(extension)) {
        await conn.close();
        return Response.json(
          statusCode: 400,
          body: {
            'error': 'Invalid file type. Allowed: jpg, jpeg, png, gif, webp',
          },
        );
      }

      // Read file bytes
      final fileBytes = <int>[];
      await for (final chunk in photoFile.openRead()) {
        fileBytes.addAll(chunk);
      }

      if (fileBytes.isEmpty) {
        await conn.close();
        return Response.json(
          statusCode: 400,
          body: {'error': 'Photo file is empty or could not be read.'},
        );
      }

      // Upload to Cloudinary
      final cloudinaryUrl =
          'https://api.cloudinary.com/v1_1/${Platform.environment['CLOUDINARY_CLOUD_NAME']}/image/upload';

      final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] =
          'freshvides_preset'; // Create this in Cloudinary
      request.fields['public_id'] =
          'photos/${userId}_${DateTime.now().millisecondsSinceEpoch}';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: photoFile.name,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        await conn.close();
        return Response.json(
          statusCode: 500,
          body: {'error': 'Failed to upload to Cloudinary'},
        );
      }

      final cloudinaryResponse = jsonDecode(responseBody);
      final imageUrl = cloudinaryResponse['secure_url'];
      final publicId = cloudinaryResponse['public_id'];

      print('✅ Photo uploaded to Cloudinary: $imageUrl');

      // Insert photo into database with Cloudinary URL
      final result = await conn.execute(
        '''INSERT INTO photos (user_id, description, image, created_at) 
           VALUES (:user_id, :description, :image, NOW())''',
        {
          'user_id': userId,
          'description': description ?? '',
          'image': imageUrl, // Store full Cloudinary URL
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
            'image': imageUrl,
            'public_id': publicId,
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
