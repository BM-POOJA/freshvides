import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:path/path.dart' as p;

Future<Response> onRequest(RequestContext context, String filename) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Method not allowed. Use GET.'},
    );
  }

  final decodedFilename = Uri.decodeComponent(filename);
  final filePath = p.join('uploads', 'photos', decodedFilename);
  final file = File(filePath);

  // Debug logging
  print('Requested photo: "$filename"');
  print('Resolved file path: $filePath');
  print('File exists: ${await file.exists()}');

  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    final ext = p.extension(decodedFilename).toLowerCase();

    String contentType;
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        contentType = 'image/jpeg';
        break;
      case '.png':
        contentType = 'image/png';
        break;
      case '.gif':
        contentType = 'image/gif';
        break;
      case '.webp':
        contentType = 'image/webp';
        break;
      default:
        contentType = 'image/jpeg';
    }

    return Response.bytes(
      body: bytes,
      headers: {
        'Content-Type': contentType,
        'Content-Length': bytes.length.toString(),
      },
    );
  } else {
    return Response.json(
      statusCode: 404,
      body: {
        'error': 'Photo not found',
        'path': filePath,
      },
    );
  }
}
