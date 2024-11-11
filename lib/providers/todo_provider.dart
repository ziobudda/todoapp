import 'package:flutter/foundation.dart';
import '../models/todo_item.dart';
import '../services/database_helper.dart';

class TodoProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<TodoItem> _todos = [];
  bool _includeArchived = false;
  bool _isLoading = false;
  String? _error;

  List<TodoItem> get todos => _todos;
  bool get includeArchived => _includeArchived;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Carica tutti i TODO dal database
  Future<void> loadTodos() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _todos = await _dbHelper.getTodos(includeArchived: _includeArchived);

      // Ordina prima per peso (solo per i TODO in corso) e poi per data
      _todos.sort((a, b) {
        if (a.stato == TodoStatus.inCorso && b.stato == TodoStatus.inCorso) {
          return a.peso.compareTo(b.peso);
        } else {
          return b.dataUltimaModifica.compareTo(a.dataUltimaModifica);
        }
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Errore nel caricamento dei TODO: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Aggiunge un nuovo TODO
  Future<void> addTodo(TodoItem todo) async {
    try {
      _error = null;
      // Ottiene il peso massimo attuale dei TODO in corso e aggiunge 1
      final maxPeso = _todos
          .where((t) => t.stato == TodoStatus.inCorso)
          .fold(0, (max, todo) => todo.peso > max ? todo.peso : max);
      final newTodo = todo.copyWith(peso: maxPeso + 1);

      final id = await _dbHelper.insertTodo(newTodo);
      final createdTodo = newTodo.copyWith(id: id);
      _todos.add(createdTodo);
      notifyListeners();
    } catch (e) {
      _error = 'Errore nell\'aggiunta del TODO: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // Aggiorna un TODO esistente
  Future<void> updateTodo(TodoItem todo) async {
    try {
      _error = null;
      // Se lo stato è cambiato a completato e non c'era una data di chiusura,
      // imposta la data di chiusura
      TodoItem updatedTodo = todo;
      if (todo.stato == TodoStatus.completato && todo.dataChiusura == null) {
        updatedTodo = todo.copyWith(
          dataChiusura: DateTime.now(),
          dataUltimaModifica: DateTime.now(),
        );
      }

      await _dbHelper.updateTodo(updatedTodo);
      await loadTodos(); // Ricarica per mantenere l'ordinamento corretto
    } catch (e) {
      _error = 'Errore nell\'aggiornamento del TODO: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // Elimina un TODO
  Future<void> deleteTodo(int id) async {
    try {
      _error = null;
      await _dbHelper.deleteTodo(id);
      _todos.removeWhere((todo) => todo.id == id);

      // Ricalcola i pesi dei TODO in corso dopo l'eliminazione
      final activeTodos = _todos
          .where((todo) => todo.stato == TodoStatus.inCorso)
          .toList()
        ..sort((a, b) => a.peso.compareTo(b.peso));

      for (var i = 0; i < activeTodos.length; i++) {
        final updatedTodo = activeTodos[i].copyWith(peso: i);
        await _dbHelper.updateTodo(updatedTodo);
      }

      await loadTodos();
      notifyListeners();
    } catch (e) {
      _error = 'Errore nell\'eliminazione del TODO: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // Gestisce il riordinamento
  Future<void> reorderTodo(int oldIndex, int newIndex) async {
    try {
      _error = null;

      // Ottieni solo i TODO in corso
      final activeTodos = _todos
          .where((todo) => todo.stato == TodoStatus.inCorso)
          .toList()
        ..sort((a, b) => a.peso.compareTo(b.peso));

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final TodoItem item = activeTodos.removeAt(oldIndex);
      activeTodos.insert(newIndex, item);

      // Aggiorna i pesi di tutti i TODO attivi in modo sequenziale
      for (var i = 0; i < activeTodos.length; i++) {
        final updatedTodo = activeTodos[i].copyWith(
          peso: i,
          dataUltimaModifica: DateTime.now(),
        );
        await _dbHelper.updateTodo(updatedTodo);
      }

      // Ricarica la lista completa per vedere gli aggiornamenti
      await loadTodos();
    } catch (e) {
      _error = 'Errore nel riordinamento dei TODO: ${e.toString()}';
      notifyListeners();
      await loadTodos(); // Ricarica in caso di errore
      rethrow;
    }
  }

  void toggleArchived() {
    _includeArchived = !_includeArchived;
    loadTodos();
  }

  List<TodoItem> getTodosByStatus(TodoStatus status) {
    return _todos.where((todo) => todo.stato == status).toList();
  }

  Map<String, dynamic> getStatistics() {
    final total = _todos.length;
    final completed = _todos.where((todo) => todo.stato == TodoStatus.completato).length;
    final inProgress = _todos.where((todo) => todo.stato == TodoStatus.inCorso).length;
    final totalHours = _todos.fold(0.0, (sum, todo) => sum + todo.oreLavorate);

    return {
      'total': total,
      'completed': completed,
      'inProgress': inProgress,
      'totalHours': totalHours,
    };
  }

  // Esporta i TODO in formato CSV
  Future<String?> exportToCsv() async {
    if (_todos.isEmpty) return null;

    final headers = [
      'ID',
      'Testo',
      'Stato',
      'Ore Lavorate',
      'Data Creazione',
      'Data Inserimento',
      'Data Chiusura',
      'Ultima Modifica',
      'Peso'
    ].join(',');

    final rows = _todos.map((todo) => [
      todo.id,
      '"${todo.testo.replaceAll('"', '""')}"',
      _getStatusLabel(todo.stato),
      todo.oreLavorate,
      todo.dataCreazione.toIso8601String(),
      todo.dataInserimento.toIso8601String(),
      todo.dataChiusura?.toIso8601String() ?? '',
      todo.dataUltimaModifica.toIso8601String(),
      todo.peso
    ].join(','));

    final csvContent = [headers, ...rows].join('\n');
    return csvContent;
  }

  String _getStatusLabel(TodoStatus status) {
    switch (status) {
      case TodoStatus.inCorso:
        return 'In Corso';
      case TodoStatus.completato:
        return 'Completato';
      case TodoStatus.archiviato:
        return 'Archiviato';
    }
  }

  @override
  void dispose() {
    _todos.clear();
    _error = null;
    _isLoading = false;
    super.dispose();
  }
}
