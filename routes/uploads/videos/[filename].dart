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
  final filePath = p.join('uploads', 'videos', decodedFilename);
  final file = File(filePath);

  // Debug logging
  print('Requested filename: "$filename"');
  print('Decoded filename: "$decodedFilename"');
  print('Resolved file path: $filePath');
  print('File exists: ${await file.exists()}');

  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    final ext = p.extension(decodedFilename).toLowerCase();

    String contentType;
    switch (ext) {
      case '.mp4':
        contentType = 'video/mp4';
        break;
      case '.mov':
        contentType = 'video/quicktime';
        break;
      case '.avi':
        contentType = 'video/x-msvideo';
        break;
      case '.webm':
        contentType = 'video/webm';
        break;
      case '.mkv':
        contentType = 'video/x-matroska';
        break;
      case '.3gp':
        contentType = 'video/3gpp';
        break;
      default:
        contentType = 'video/mp4';
    }

    return Response.bytes(
      body: bytes,
      headers: {
        'Content-Type': contentType,
        'Content-Length': bytes.length.toString(),
        'Accept-Ranges': 'bytes',
      },
    );
  } else {
    return Response.json(
      statusCode: 404,
      body: {
        'error': 'File not found',
        'path': filePath,
      },
    );
  }
}
