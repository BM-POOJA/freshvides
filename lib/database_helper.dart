import 'package:mysql_client/mysql_client.dart';
import 'dart:typed_data';

class DatabaseHelper {
  static Future<MySQLConnection> getConnection() async {
    try {
      final conn = await MySQLConnection.createConnection(
        host: 'localhost',
        port: 3306,
        userName: 'root',
        password: 'pbudha@5',
        databaseName: 'listofapis',
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
