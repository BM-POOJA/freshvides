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
        // Get photos for specific user
        result = await conn.execute(
          Sql.named(
              '''SELECT p.id, p.user_id, p.description, p.image, p.created_at, u.username, u.email 
               FROM photos p 
               JOIN signup u ON p.user_id = u.id 
               WHERE p.user_id = @userId 
               ORDER BY p.created_at DESC
               LIMIT @limit OFFSET @offset'''),
          parameters: {
            'userId': int.parse(userId),
            'limit': limit,
            'offset': offset
          },
        );

        countResult = await conn.execute(
          Sql.named(
              'SELECT COUNT(*) as total FROM photos WHERE user_id = @userId'),
          parameters: {'userId': int.parse(userId)},
        );
      } else {
        // Get all photos
        result = await conn.execute(
          Sql.named(
              '''SELECT p.id, p.user_id, p.description, p.image, p.created_at, u.username, u.email 
               FROM photos p 
               JOIN signup u ON p.user_id = u.id 
               ORDER BY p.created_at DESC
               LIMIT @limit OFFSET @offset'''),
          parameters: {'limit': limit, 'offset': offset},
        );

        countResult = await conn.execute(
          Sql.named('SELECT COUNT(*) as total FROM photos'),
        );
      }

      final totalCount = countResult[0][0] as int;
      final totalPages = (totalCount / limit).ceil();

      final photos = result.map((row) {
        return {
          'id': row[0] as int,
          'user_id': row[1] as int,
          'description': row[2] as String?,
          'image': row[3] as String?,
          'created_at': row[4].toString(),
          'username': row[5] as String?,
          'email': row[6] as String?,
        };
      }).toList();

      await conn.close();

      return Response.json(
        statusCode: 200,
        body: {
          'message': 'Photos fetched successfully.',
          'pagination': {
            'current_page': page,
            'per_page': limit,
            'total_count': totalCount,
            'total_pages': totalPages,
          },
          'count': photos.length,
          'photos': photos,
        },
      );
    } catch (e) {
      await conn.close();
      rethrow;
    }
  } catch (e) {
    print('❌ Get Photos Error: $e');
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal server error: $e'},
    );
  }
}
