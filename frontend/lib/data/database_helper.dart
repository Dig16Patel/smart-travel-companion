import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'travel_assistant.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journeys(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT,
        destination TEXT,
        date TEXT,
        notes TEXT
      )
    ''');
  }

  Future<int> insertJourney(Map<String, dynamic> journey) async {
    Database db = await database;
    return await db.insert('journeys', journey);
  }

  Future<List<Map<String, dynamic>>> getJourneys() async {
    Database db = await database;
    return await db.query('journeys', orderBy: 'id DESC');
  }

  Future<int> updateJourney(Map<String, dynamic> journey) async {
    Database db = await database;
    return await db.update(
      'journeys',
      journey,
      where: 'id = ?',
      whereArgs: [journey['id']],
    );
  }

  Future<int> deleteJourney(int id) async {
    Database db = await database;
    return await db.delete(
      'journeys',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
