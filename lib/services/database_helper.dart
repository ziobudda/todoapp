// services/database_helper.dart

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/todo_item.dart';

class DatabaseHelper {
  static const _databaseName = 'todo_app.db';
  static const _databaseVersion = 3;
  static const todoTable = 'todos';

  static Database? _database;

  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $todoTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        testo TEXT NOT NULL,
        stato INTEGER NOT NULL,
        oreLavorate REAL NOT NULL,
        dataCreazione TEXT NOT NULL,
        dataInserimento TEXT NOT NULL,
        dataChiusura TEXT,
        dataUltimaModifica TEXT NOT NULL,
        peso INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE $todoTable ADD COLUMN dataInserimento TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP');
      await db.execute('ALTER TABLE $todoTable ADD COLUMN dataChiusura TEXT');
    }

    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE $todoTable ADD COLUMN peso INTEGER NOT NULL DEFAULT 0');

      final List<Map<String, dynamic>> todos =
          await db.query(todoTable, orderBy: 'dataUltimaModifica DESC');

      for (var i = 0; i < todos.length; i++) {
        await db.update(
          todoTable,
          {'peso': i},
          where: 'id = ?',
          whereArgs: [todos[i]['id']],
        );
      }
    }
  }

  // CRUD Operations
  Future<int> insertTodo(TodoItem todo) async {
    final db = await database;
    return await db.insert(
      todoTable,
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TodoItem>> getTodos({bool includeArchived = false}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      todoTable,
      where: includeArchived ? null : 'stato != ?',
      whereArgs: includeArchived ? null : [TodoStatus.archiviato.index],
      orderBy:
          'CASE WHEN stato = ${TodoStatus.inCorso.index} THEN peso ELSE dataUltimaModifica END ASC',
    );

    return List.generate(maps.length, (i) => TodoItem.fromMap(maps[i]));
  }

  Future<TodoItem?> getTodoById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      todoTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return TodoItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateTodo(TodoItem todo) async {
    final db = await database;
    return await db.update(
      todoTable,
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      todoTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Utility methods
  Future<void> deleteAllTodos() async {
    final db = await database;
    await db.delete(todoTable);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
