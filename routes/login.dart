import 'dart:convert';
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
        'SELECT id, username, email, password, created_at FROM signup WHERE username = :usernameOrEmail OR email = :usernameOrEmail',
        {'usernameOrEmail': usernameOrEmail},
      );

      if (result.rows.isEmpty) {
        await conn.close();
        return Response.json(
          statusCode: 401,
          body: {'error': 'Invalid username/email or password.'},
        );
      }

      final user = result.rows.first.assoc();
      final storedPassword = user['password'];

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
            'id': int.parse(user['id'] ?? '0'),
            'username': user['username'],
            'email': user['email'],
            'created_at': user['created_at'],
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
