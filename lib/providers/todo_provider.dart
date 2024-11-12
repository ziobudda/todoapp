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

      // Ordina prima per peso (decrescente per i TODO in corso) e poi per data
      _todos.sort((a, b) {
        if (a.stato == TodoStatus.inCorso && b.stato == TodoStatus.inCorso) {
          return b.peso.compareTo(a.peso); // Ordine decrescente dei pesi
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
      // Ottieni i TODO in corso
      final activeTodos = _todos.where((t) => t.stato == TodoStatus.inCorso).toList();
      // Il nuovo TODO avrà peso pari alla lunghezza della lista (sarà l'ultimo)
      final newTodo = todo.copyWith(peso: 0);

      // Aggiorna i pesi di tutti i TODO esistenti
      for (var i = 0; i < activeTodos.length; i++) {
        final updatedTodo = activeTodos[i].copyWith(peso: i + 1);
        await _dbHelper.updateTodo(updatedTodo);
      }

      final id = await _dbHelper.insertTodo(newTodo);
      final createdTodo = newTodo.copyWith(id: id);
      await loadTodos(); // Ricarica per mantenere l'ordinamento corretto
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
      // Riordina i pesi dopo l'eliminazione
      final activeTodos = _todos.where((todo) => todo.stato == TodoStatus.inCorso).toList();
      for (var i = 0; i < activeTodos.length; i++) {
        final updatedTodo = activeTodos[i].copyWith(peso: activeTodos.length - i - 1);
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

      // Ottieni solo i TODO in corso per l'ordinamento
      final activeTodos = _todos.where((todo) => todo.stato == TodoStatus.inCorso).toList()
        ..sort((a, b) => b.peso.compareTo(a.peso)); // Ordina per peso decrescente

      // Aggiusta l'indice se necessario
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      // Sposta l'elemento nella nuova posizione
      final TodoItem item = activeTodos.removeAt(oldIndex);
      activeTodos.insert(newIndex, item);

      // Ricalcola i pesi per tutti i todo attivi
      // L'elemento in posizione 0 avrà il peso più alto
      final int maxWeight = activeTodos.length - 1;

      // Aggiorna i pesi di tutti i TODO
      for (var i = 0; i < activeTodos.length; i++) {
        final currentTodo = activeTodos[i];
        final newWeight = maxWeight - i; // Il primo elemento avrà peso = maxWeight

        // Aggiorna solo se il peso è effettivamente cambiato
        if (currentTodo.peso != newWeight) {
          final updatedTodo = currentTodo.copyWith(
            peso: newWeight,
            dataUltimaModifica: DateTime.now(),
          );
          await _dbHelper.updateTodo(updatedTodo);
        }
      }

      // Ricarica la lista completa per vedere gli aggiornamenti
      await loadTodos();
      notifyListeners();
    } catch (e) {
      _error = 'Errore nel riordinamento dei TODO: ${e.toString()}';
      notifyListeners();
      await loadTodos(); // Ricarica in caso di errore
      rethrow;
    }
  }

  // Cambia lo stato di visualizzazione dei TODO archiviati
  void toggleArchived() {
    _includeArchived = !_includeArchived;
    loadTodos();
  }

  // Filtra i TODO per stato
  List<TodoItem> getTodosByStatus(TodoStatus status) {
    return _todos.where((todo) => todo.stato == status).toList();
  }

  // Ottiene le statistiche dei TODO
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

    // Intestazioni CSV
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

    // Righe dati
    final rows = _todos.map((todo) => [
          todo.id,
          '"${todo.testo.replaceAll('"', '""')}"', // Gestisce le virgolette nel testo
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

  // Pulisce i dati in memoria quando il provider viene distrutto
  @override
  void dispose() {
    _todos.clear();
    _error = null;
    _isLoading = false;
    super.dispose();
  }
}
