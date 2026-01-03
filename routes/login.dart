import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'Method not allowed. Use POST.'},
    );
  }

  try {
    final body = await context.request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final usernameOrEmail = data['username'] ?? data['email'];
    final password = data['password'] as String?;

    // Validate required fields
    if (usernameOrEmail == null || (usernameOrEmail as String).isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Username or email is required.'},
      );
    }

    if (password == null || password.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Password is required.'},
      );
    }

    // Get database connection
    final conn = await DatabaseHelper.getConnection();

    try {
      // Find user by username or email
      final result = await conn.execute(
        Sql.named(
            'SELECT id, username, email, password, created_at FROM signup WHERE username = @usernameOrEmail OR email = @usernameOrEmail'),
        parameters: {'usernameOrEmail': usernameOrEmail},
      );

      if (result.isEmpty) {
        await conn.close();
        return Response.json(
          statusCode: 401,
          body: {'error': 'Invalid username/email or password.'},
        );
      }

      final user = result.first;
      final storedPassword = user[3] as String?;

      // Verify password
      if (storedPassword != password) {
        await conn.close();
        return Response.json(
          statusCode: 401,
          body: {'error': 'Invalid username/email or password.'},
        );
      }

      await conn.close();

      return Response.json(
        statusCode: 200,
        body: {
          'message': 'Login successful.',
          'user': {
            'id': user[0] as int,
            'username': user[1] as String?,
            'email': user[2] as String?,
            'created_at': user[4].toString(),
          },
        },
      );
    } catch (e) {
      await conn.close();
      rethrow;
    }
  } catch (e) {
    print('❌ Login Error: $e');
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal server error: $e'},
    );
  }
}
