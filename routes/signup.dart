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

    final username = data['username'] as String?;
    final email = data['email'] as String?;
    final password = data['password'] as String?;

    // Validate required fields
    if (username == null || username.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Username is required.'},
      );
    }

    if (email == null || email.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Email is required.'},
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
      // Check if username already exists
      final existingUsername = await conn.execute(
        'SELECT id FROM signup WHERE username = \$1',
        parameters: [username],
      );

      if (existingUsername.isNotEmpty) {
        await conn.close();
        return Response.json(
          statusCode: 409,
          body: {'error': 'Username already taken.'},
        );
      }

      // Check if email already exists
      final existingEmail = await conn.execute(
        'SELECT id FROM signup WHERE email = \$1',
        parameters: [email],
      );

      if (existingEmail.isNotEmpty) {
        await conn.close();
        return Response.json(
          statusCode: 409,
          body: {'error': 'Email already registered.'},
        );
      }

      // Insert new user into database
      final result = await conn.execute(
        'INSERT INTO signup (username, email, password, created_at) VALUES (\$1, \$2, \$3, NOW()) RETURNING id',
        parameters: [username, email, password],
      );

      await conn.close();

      final userId = result.isNotEmpty ? result.first[0] as int : 0;

      return Response.json(
        statusCode: 201,
        body: {
          'message': 'User registered successfully.',
          'user': {
            'id': userId,
            'username': username,
            'email': email,
          },
        },
      );
    } catch (e) {
      await conn.close();
      rethrow;
    }
  } catch (e) {
    print('❌ Signup Error: $e');
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal server error: $e'},
    );
  }
}
