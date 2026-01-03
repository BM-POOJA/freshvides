import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:crypto/crypto.dart';

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
        Sql.named('SELECT id FROM signup WHERE id = @userId'),
        parameters: {'userId': userId},
      );

      if (userCheck.isEmpty) {
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

      // Upload to Cloudinary with signed upload
      print('📸 Starting Cloudinary upload process...');
      final cloudinaryCloudName = Platform.environment['CLOUDINARY_CLOUD_NAME'];
      final cloudinaryApiKey = Platform.environment['CLOUDINARY_API_KEY'];
      final cloudinaryApiSecret = Platform.environment['CLOUDINARY_API_SECRET'];

      print('🔍 Checking Cloudinary credentials...');
      print('  Cloud Name: ${cloudinaryCloudName != null && cloudinaryCloudName.isNotEmpty ? "✅ Set" : "❌ Missing"}');
      print('  Cloud Name VALUE: "$cloudinaryCloudName" (length: ${cloudinaryCloudName?.length})');
      print('  API Key: ${cloudinaryApiKey != null && cloudinaryApiKey.isNotEmpty ? "✅ Set" : "❌ Missing"}');
      print('  API Key VALUE: "$cloudinaryApiKey"');
      print('  API Secret: ${cloudinaryApiSecret != null && cloudinaryApiSecret.isNotEmpty ? "✅ Set" : "❌ Missing"}');

      if (cloudinaryCloudName == null ||
          cloudinaryCloudName.isEmpty ||
          cloudinaryApiKey == null ||
          cloudinaryApiKey.isEmpty ||
          cloudinaryApiSecret == null ||
          cloudinaryApiSecret.isEmpty) {
        await conn.close();
        print('❌ Cloudinary environment variables not properly configured');
        return Response.json(
          statusCode: 500,
          body: {
            'error': 'Server configuration error: Cloudinary not configured'
          },
        );
      }

      print('✅ All Cloudinary credentials found');
      final cloudinaryUrl =
          'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';
      print('📤 Upload URL: $cloudinaryUrl');

      final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));

      // Add API key for signed upload
      request.fields['api_key'] = cloudinaryApiKey;
      request.fields['timestamp'] =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      request.fields['public_id'] =
          'photos/${userId}_${DateTime.now().millisecondsSinceEpoch}';

      print('🔐 Generating signature...');
      // Generate signature for secure upload
      final signature = _generateCloudinarySignature(
        publicId: request.fields['public_id']!,
        timestamp: request.fields['timestamp']!,
        apiSecret: cloudinaryApiSecret,
      );
      request.fields['signature'] = signature;
      print('✅ Signature generated: ${signature.substring(0, 10)}...');
      print('📦 File size: ${fileBytes.length} bytes');

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: photoFile.name,
        ),
      );

      print('⏳ Sending request to Cloudinary...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 Cloudinary Response Status: ${response.statusCode}');
      print('📥 Response Body: $responseBody');

      if (response.statusCode != 200) {
        await conn.close();
        print(
            '❌ Cloudinary upload failed (${response.statusCode}): $responseBody');
        return Response.json(
          statusCode: 500,
          body: {
            'error': 'Failed to upload to Cloudinary',
            'details': 'Status ${response.statusCode}',
            'cloudinary_response': responseBody,
          },
        );
      }

      final cloudinaryResponse = jsonDecode(responseBody);
      final imageUrl = cloudinaryResponse['secure_url'];
      final publicId = cloudinaryResponse['public_id'];

      print('✅ Photo uploaded to Cloudinary: $imageUrl');

      // Insert photo into database with Cloudinary URL
      final result = await conn.execute(
        Sql.named(
            '''INSERT INTO photos (user_id, description, image, created_at) 
           VALUES (@user_id, @description, @image, NOW()) RETURNING id'''),
        parameters: {
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
            'id': result[0][0] as int,
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

/// Generate Cloudinary signature for authenticated uploads
String _generateCloudinarySignature({
  required String publicId,
  required String timestamp,
  required String apiSecret,
  String? resourceType,
}) {
  // Build parameters string (alphabetically sorted)
  final params = <String, String>{
    'public_id': publicId,
    'timestamp': timestamp,
  };

  if (resourceType != null) {
    params['resource_type'] = resourceType;
  }

  // Sort keys alphabetically and build string
  final sortedKeys = params.keys.toList()..sort();
  final paramsString = sortedKeys.map((key) => '$key=${params[key]}').join('&');

  // Append API secret
  final stringToSign = '$paramsString$apiSecret';

  // Generate SHA256 hash
  final bytes = utf8.encode(stringToSign);
  final digest = sha256.convert(bytes);

  return digest.toString();
}
