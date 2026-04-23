import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/minute_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('minutes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE minutes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        ai_summary TEXT,
        audioPath TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE minutes ADD COLUMN ai_summary TEXT');
    }
  }

  Future<int> create(Minute minute) async {
    final db = await instance.database;
    final map = minute.toMap();
    if (map.containsKey('aiSummary')) {
      map['ai_summary'] = map['aiSummary'];
      map.remove('aiSummary');
    }
    return await db.insert('minutes', map);
  }

  Future<List<Minute>> readAllMinutes() async {
    final db = await instance.database;
    final result = await db.query('minutes', orderBy: 'createdAt DESC');
    return result.map((json) {
      // DBのカラム名(ai_summary)をモデルのフィールド名(aiSummary)にマッピング
      final map = Map<String, dynamic>.from(json);
      if (map.containsKey('ai_summary')) {
        map['aiSummary'] = map['ai_summary'];
      }
      return Minute.fromMap(map);
    }).toList();
  }

  Future<int> update(Minute minute) async {
    final map = minute.toMap();
    // モデルのフィールド名(aiSummary)をDBのカラム名(ai_summary)にマッピング
    if (map.containsKey('aiSummary')) {
      map['ai_summary'] = map['aiSummary'];
      map.remove('aiSummary');
    }
    
    final db = await instance.database;
    return db.update(
      'minutes',
      map,
      where: 'id = ?',
      whereArgs: [minute.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'minutes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
