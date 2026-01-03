import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';
import 'package:postgres/postgres.dart';

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
      List<List<dynamic>> result;
      List<List<dynamic>> countResult;

      if (userId != null) {
        // Get videos for specific user
        result = await conn.execute(
          Sql.named(
              '''SELECT v.id, v.user_id, v.title, v.description, v.video_url, v.video_type, v.duration, v.created_at, u.username, u.email 
               FROM videos v 
               JOIN signup u ON v.user_id = u.id 
               WHERE v.user_id = @userId 
               ORDER BY v.created_at DESC
               LIMIT @limit OFFSET @offset'''),
          parameters: {
            'userId': int.parse(userId),
            'limit': limit,
            'offset': offset
          },
        );

        countResult = await conn.execute(
          Sql.named(
              'SELECT COUNT(*) as total FROM videos WHERE user_id = @userId'),
          parameters: {'userId': int.parse(userId)},
        );
      } else {
        // Get all videos
        result = await conn.execute(
          Sql.named(
              '''SELECT v.id, v.user_id, v.title, v.description, v.video_url, v.video_type, v.duration, v.created_at, u.username, u.email 
               FROM videos v 
               JOIN signup u ON v.user_id = u.id 
               ORDER BY v.created_at DESC
               LIMIT @limit OFFSET @offset'''),
          parameters: {'limit': limit, 'offset': offset},
        );

        countResult = await conn.execute(
          Sql.named('SELECT COUNT(*) as total FROM videos'),
        );
      }

      final totalCount = countResult[0][0] as int;
      final totalPages = (totalCount / limit).ceil();

      final videos = result.map((row) {
        final videoPath = (row[4] as String?) ?? '';
        final videoFile = videoPath.split('/').last;
        return {
          'id': row[0] as int,
          'user_id': row[1] as int,
          'title': row[2] as String?,
          'description': row[3] as String?,
          'video_url': '/uploads/videos/$videoFile',
          'video_type': row[5] as String?,
          'duration': row[6] as int?,
          'created_at': row[7].toString(),
          'username': row[8] as String?,
          'email': row[9] as String?,
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
