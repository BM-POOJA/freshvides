import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';
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
    final body = await context.request.json() as Map<String, dynamic>;
    final email = body['email'] as String?;
    final resetCode = body['reset_code'] as String?;
    final newPassword = body['new_password'] as String?;

    // Validate required fields
    if (email == null || email.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Email is required.'},
      );
    }

    if (resetCode == null || resetCode.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Reset code is required.'},
      );
    }

    if (newPassword == null || newPassword.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'New password is required.'},
      );
    }

    if (newPassword.length < 6) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Password must be at least 6 characters long.'},
      );
    }

    final conn = await DatabaseHelper.getConnection();

    try {
      // Get user by email
      final userCheck = await conn.execute(
        Sql.named('SELECT id FROM signup WHERE email = @email'),
        parameters: {'email': email},
      );

      if (userCheck.isEmpty) {
        await conn.close();
        return Response.json(
          statusCode: 404,
          body: {'error': 'User not found.'},
        );
      }

      final userId = userCheck[0][0] as int;

      // Verify reset code
      final resetCheck = await conn.execute(
        Sql.named(
          '''SELECT id, expires_at, used FROM password_resets 
             WHERE user_id = @userId AND reset_code = @resetCode
             ORDER BY created_at DESC LIMIT 1''',
        ),
        parameters: {
          'userId': userId,
          'resetCode': resetCode,
        },
      );

      if (resetCheck.isEmpty) {
        await conn.close();
        return Response.json(
          statusCode: 400,
          body: {'error': 'Invalid reset code.'},
        );
      }

      final resetId = resetCheck[0][0] as int;
      final expiresAt = DateTime.parse(resetCheck[0][1].toString());
      final used = resetCheck[0][2] as bool;

      // Check if code is expired
      if (DateTime.now().isAfter(expiresAt)) {
        await conn.close();
        return Response.json(
          statusCode: 400,
          body: {'error': 'Reset code has expired. Please request a new one.'},
        );
      }

      // Check if code has been used
      if (used) {
        await conn.close();
        return Response.json(
          statusCode: 400,
          body: {'error': 'Reset code has already been used.'},
        );
      }

      // Hash the new password
      final bytes = utf8.encode(newPassword);
      final hashedPassword = sha256.convert(bytes).toString();

      // Update password
      await conn.execute(
        Sql.named('UPDATE signup SET password = @password WHERE id = @userId'),
        parameters: {
          'password': hashedPassword,
          'userId': userId,
        },
      );

      // Mark reset code as used
      await conn.execute(
        Sql.named('UPDATE password_resets SET used = TRUE WHERE id = @resetId'),
        parameters: {'resetId': resetId},
      );

      await conn.close();

      print('✅ Password changed successfully for user ID: $userId');

      return Response.json(
        statusCode: 200,
        body: {
          'message':
              'Password changed successfully. You can now login with your new password.',
        },
      );
    } catch (e) {
      await conn.close();
      rethrow;
    }
  } catch (e) {
    print('❌ Change Password Error: $e');
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal server error: $e'},
    );
  }
}
