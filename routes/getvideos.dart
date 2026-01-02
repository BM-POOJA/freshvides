import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';
import 'package:mysql_client/mysql_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Method not allowed. Use GET.'},
    );
  }

  try {
    // Get query parameters for filtering/pagination
    final params = context.request.uri.queryParameters;
    final userId = params['user_id'];
    final page = int.tryParse(params['page'] ?? '1') ?? 1;
    final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
    final offset = (page - 1) * limit;

    final conn = await DatabaseHelper.getConnection();

    try {
      IResultSet result;
      IResultSet countResult;

      if (userId != null) {
        // Get videos for specific user
        result = await conn.execute(
          '''SELECT v.id, v.user_id, v.title, v.description, v.video_url, v.video_type, v.duration, v.created_at, u.username, u.email 
             FROM videos v 
             JOIN signup u ON v.user_id = u.id 
             WHERE v.user_id = :userId 
             ORDER BY v.created_at DESC
             LIMIT :limit OFFSET :offset''',
          {'userId': int.parse(userId), 'limit': limit, 'offset': offset},
        );

        countResult = await conn.execute(
          'SELECT COUNT(*) as total FROM videos WHERE user_id = :userId',
          {'userId': int.parse(userId)},
        );
      } else {
        // Get all videos
        result = await conn.execute(
          '''SELECT v.id, v.user_id, v.title, v.description, v.video_url, v.video_type, v.duration, v.created_at, u.username, u.email 
             FROM videos v 
             JOIN signup u ON v.user_id = u.id 
             ORDER BY v.created_at DESC
             LIMIT :limit OFFSET :offset''',
          {'limit': limit, 'offset': offset},
        );

        countResult = await conn.execute(
          'SELECT COUNT(*) as total FROM videos',
        );
      }

      final totalCount =
          int.parse(countResult.rows.first.assoc()['total'] ?? '0');
      final totalPages = (totalCount / limit).ceil();

      final videos = result.rows.map((row) {
        final data = row.assoc();
        final videoPath = data['video_url'] ?? '';
        // Extract just the filename from the path
        final videoFile = videoPath.split('/').last;
        return {
          'id': int.parse(data['id'] ?? '0'),
          'user_id': int.parse(data['user_id'] ?? '0'),
          'username': data['username'],
          'email': data['email'],
          'title': data['title'],
          'description': data['description'],
          'video_url': '/uploads/videos/$videoFile',
          'video_type': data['video_type'],
          'duration': int.parse(data['duration'] ?? '0'),
          'created_at': data['created_at'],
        };
      }).toList();

      await conn.close();

      return Response.json(
        statusCode: 200,
        body: {
          'message': 'Videos fetched successfully.',
          'pagination': {
            'current_page': page,
            'per_page': limit,
            'total_count': totalCount,
            'total_pages': totalPages,
          },
          'count': videos.length,
          'videos': videos,
        },
      );
    } catch (e) {
      await conn.close();
      rethrow;
    }
  } catch (e) {
    print('❌ Get Videos Error: $e');
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal server error: $e'},
    );
  }
}
