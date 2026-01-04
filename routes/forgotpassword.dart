import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:listofapis/database_helper.dart';
import 'package:postgres/postgres.dart';
import 'package:crypto/crypto.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

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

    if (email == null || email.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Email is required.'},
      );
    }

    final conn = await DatabaseHelper.getConnection();

    try {
      // Check if user exists
      final userCheck = await conn.execute(
        Sql.named(
            'SELECT id, username, email FROM signup WHERE email = @email'),
        parameters: {'email': email},
      );

      if (userCheck.isEmpty) {
        // Don't reveal if email exists or not for security
        await conn.close();
        return Response.json(
          statusCode: 200,
          body: {
            'message':
                'If your email is registered, you will receive password reset instructions.'
          },
        );
      }

      final userId = userCheck[0][0] as int;
      final username = userCheck[0][1] as String;

      // Generate a 6-digit reset code
      final resetCode =
          (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
      final expiresAt = DateTime.now().add(Duration(minutes: 15));

      // Store reset code in database (you'll need to create this table)
      // For now, we'll just return the code (in production, send via email)
      try {
        await conn.execute(
          Sql.named(
            '''CREATE TABLE IF NOT EXISTS password_resets (
              id SERIAL PRIMARY KEY,
              user_id INTEGER NOT NULL REFERENCES signup(id) ON DELETE CASCADE,
              reset_code VARCHAR(10) NOT NULL,
              expires_at TIMESTAMP NOT NULL,
              used BOOLEAN DEFAULT FALSE,
              created_at TIMESTAMP DEFAULT NOW()
            )''',
          ),
        );

        // Delete any old reset codes for this user
        await conn.execute(
          Sql.named('DELETE FROM password_resets WHERE user_id = @userId'),
          parameters: {'userId': userId},
        );

        // Insert new reset code
        await conn.execute(
          Sql.named(
            '''INSERT INTO password_resets (user_id, reset_code, expires_at) 
               VALUES (@userId, @resetCode, @expiresAt)''',
          ),
          parameters: {
            'userId': userId,
            'resetCode': resetCode,
            'expiresAt': expiresAt.toIso8601String(),
          },
        );
      } catch (e) {
        print('Error managing password reset: $e');
      }

      await conn.close();

      // Send reset code via email
      print('📧 Sending password reset code to $email...');

      try {
        final smtpUsername = Platform.environment['SMTP_USERNAME'];
        final smtpPassword = Platform.environment['SMTP_PASSWORD'];
        final smtpHost = Platform.environment['SMTP_HOST'] ?? 'smtp.gmail.com';
        final smtpPort =
            int.tryParse(Platform.environment['SMTP_PORT'] ?? '587') ?? 587;

        // Debug: Print environment variables (mask password)
        print('🔍 Checking SMTP Configuration:');
        print(
            '  SMTP_HOST: ${smtpHost} (${Platform.environment['SMTP_HOST'] != null ? "from env" : "default"})');
        print(
            '  SMTP_PORT: $smtpPort (${Platform.environment['SMTP_PORT'] != null ? "from env" : "default"})');
        print(
            '  SMTP_USERNAME: ${smtpUsername != null && smtpUsername.isNotEmpty ? smtpUsername : "❌ NOT SET"}');
        print(
            '  SMTP_PASSWORD: ${smtpPassword != null && smtpPassword.isNotEmpty ? "✅ SET (${smtpPassword.length} chars)" : "❌ NOT SET"}');

        if (smtpUsername == null ||
            smtpUsername.isEmpty ||
            smtpPassword == null ||
            smtpPassword.isEmpty) {
          print('⚠️ SMTP credentials not configured. Reset code: $resetCode');
          print(
              '💡 Add SMTP_USERNAME and SMTP_PASSWORD to environment variables');
          // If email not configured, return code in response for testing
          return Response.json(
            statusCode: 200,
            body: {
              'message':
                  'Email service temporarily unavailable. Please contact support.',
              'reset_code': resetCode,
            },
          );
        }

        print('✅ SMTP credentials found, initializing mail server...');
        final smtpServer = SmtpServer(
          smtpHost,
          port: smtpPort,
          username: smtpUsername,
          password: smtpPassword,
        );
        print('📧 SMTP Server configured: $smtpHost:$smtpPort');

        final message = Message()
          ..from = Address(smtpUsername, 'FreshVibes')
          ..recipients.add(email)
          ..subject = 'Password Reset Code - FreshVibes'
          ..text = '''
Hello $username,

You requested to reset your password for FreshVibes.

Your password reset code is: $resetCode

This code will expire in 15 minutes.

If you didn't request this, please ignore this email.

Best regards,
FreshVibes Team
'''
          ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #111827; color: white; padding: 20px; text-align: center; }
    .content { padding: 30px; background-color: #f9fafb; }
    .code-box { background-color: white; border: 2px solid #111827; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0; }
    .code { font-size: 32px; font-weight: bold; color: #111827; letter-spacing: 4px; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Password Reset</h1>
    </div>
    <div class="content">
      <p>Hello <strong>$username</strong>,</p>
      <p>You requested to reset your password for FreshVibes.</p>
      <p>Your password reset code is:</p>
      <div class="code-box">
        <div class="code">$resetCode</div>
      </div>
      <p>This code will expire in <strong>15 minutes</strong>.</p>
      <p>If you didn't request this, please ignore this email.</p>
      <p>Best regards,<br>FreshVibes Team</p>
    </div>
    <div class="footer">
      This is an automated email. Please do not reply.
    </div>
  </div>
</body>
</html>
''';

        print('📤 Attempting to send email...');
        print('  From: $smtpUsername');
        print('  To: $email');
        print('  Subject: Password Reset Code - FreshVibes');

        await send(message, smtpServer);
        print('✅ Password reset email sent successfully to $email');

        return Response.json(
          statusCode: 200,
          body: {
            'message':
                'Password reset code has been sent to your email. Code expires in 15 minutes.',
          },
        );
      } catch (e, stackTrace) {
        print('❌ Email sending error: $e');
        print('❌ Stack trace: $stackTrace');
        // If email fails, still return success but log the code
        print('🔐 Fallback - Reset code for $email: $resetCode');
        return Response.json(
          statusCode: 200,
          body: {
            'message':
                'Email service temporarily unavailable. Please contact support.',
            // Only for development/testing
            'reset_code': resetCode,
          },
        );
      }
    } catch (e) {
      await conn.close();
      rethrow;
    }
  } catch (e) {
    print('❌ Forgot Password Error: $e');
    return Response.json(
      statusCode: 500,
      body: {'error': 'Internal server error: $e'},
    );
  }
}
