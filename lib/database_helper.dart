import 'package:postgres/postgres.dart';
import 'dart:io';

class DatabaseHelper {
  static Future<Connection> getConnection() async {
    try {
      final host = Platform.environment['DB_HOST'] ?? 'localhost';
      final port = int.parse(Platform.environment['DB_PORT'] ?? '5432');
      final userName = Platform.environment['DB_USER'] ?? 'postgres';
      final password = Platform.environment['DB_PASSWORD'] ?? '';
      final databaseName = Platform.environment['DB_NAME'] ?? 'listofapis';

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
