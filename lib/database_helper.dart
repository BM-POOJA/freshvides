import 'package:postgres/postgres.dart';
import 'dart:io';

class DatabaseHelper {
  static Future<Connection> getConnection() async {
    try {
      // Try using DATABASE_URL first (Render standard)
      final databaseUrl = Platform.environment['DATABASE_URL'];

      if (databaseUrl != null && databaseUrl.isNotEmpty) {
        print('🔌 Connecting using DATABASE_URL...');
        final uri = Uri.parse(databaseUrl);

        final conn = await Connection.open(
          Endpoint(
            host: uri.host,
            port: uri.port,
            database: uri.pathSegments.isNotEmpty
                ? uri.pathSegments.first
                : 'postgres',
            username: uri.userInfo.split(':').first,
            password: uri.userInfo.split(':').last,
          ),
          settings: ConnectionSettings(
            sslMode: SslMode.require,
          ),
        );
        print('✅ DB Connected Successfully');
        return conn;
      }

      // Fallback to individual environment variables
      final host = Platform.environment['DB_HOST'] ?? 'localhost';
      final port = int.parse(Platform.environment['DB_PORT'] ?? '5432');
      final userName = Platform.environment['DB_USER'] ?? 'postgres';
      final password = Platform.environment['DB_PASSWORD'] ?? '';
      final databaseName = Platform.environment['DB_NAME'] ?? 'listofapis';

      print('🔌 Attempting DB Connection...');
      print('Host: $host');
      print('Database: $databaseName');
      print('User: $userName');

      final conn = await Connection.open(
        Endpoint(
          host: host,
          port: port,
          database: databaseName,
          username: userName,
          password: password,
        ),
        settings: ConnectionSettings(
          sslMode: SslMode.require,
        ),
      );
      print('✅ DB Connected Successfully');
      return conn;
    } catch (e) {
      print('❌ DB Connection Failed: $e');
      rethrow;
    }
  }
}
