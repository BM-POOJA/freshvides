import 'package:mysql_client/mysql_client.dart';
import 'dart:typed_data';
import 'dart:io';

class DatabaseHelper {
  static Future<MySQLConnection> getConnection() async {
    try {
      final host = Platform.environment['DB_HOST'] ?? 'localhost';
      final port = int.parse(Platform.environment['DB_PORT'] ?? '3306');
      final userName = Platform.environment['DB_USER'] ?? 'root';
      final password = Platform.environment['DB_PASSWORD'] ?? 'pbudha@5';
      final databaseName = Platform.environment['DB_NAME'] ?? 'listofapis';

      final conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: userName,
        password: password,
        databaseName: databaseName,
      );
      await conn.connect();
      print('✅ DB Connected Successfully');
      return conn;
    } catch (e) {
      print('❌ DB Connection Failed: $e');
      rethrow;
    }
  }
}
