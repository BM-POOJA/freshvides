import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

/// Health check endpoint to verify server is running
Future<Response> onRequest(RequestContext context) async {
  return Response.json(
    statusCode: 200,
    body: {
      'status': 'ok',
      'message': 'Server is running',
      'timestamp': DateTime.now().toIso8601String(),
      'environment': {
        'has_cloudinary_name':
            Platform.environment['CLOUDINARY_CLOUD_NAME'] != null,
        'has_cloudinary_key':
            Platform.environment['CLOUDINARY_API_KEY'] != null,
        'has_cloudinary_secret':
            Platform.environment['CLOUDINARY_API_SECRET'] != null,
        'has_db_host': Platform.environment['DB_HOST'] != null,
      },
    },
  );
}
