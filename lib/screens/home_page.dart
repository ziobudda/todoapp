// screens/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_list_item.dart';

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({Key? key}) : super(key: key);

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoProvider>().loadTodos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showCompleted ? 'TODO Completati' : 'TODO da Fare'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu',
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Esporta CSV'),
                  ],
                ),
                onTap: () {
                  // Esporta i TODO in CSV
                  final csvData = context.read<TodoProvider>().exportToCsv();
                  // In una vera app qui dovremmo salvare il file
                  Future.delayed(
                    const Duration(seconds: 0),
                    () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Export Completato'),
                        content: const Text(
                          'I TODO sono stati esportati correttamente in formato CSV.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Impostazioni',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.backup, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Backup',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildTodoList(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _showCompleted ? 1 : 0,
        onTap: (index) {
          switch (index) {
            case 0:
              setState(() => _showCompleted = false);
              break;
            case 1:
              setState(() => _showCompleted = true);
              break;
            case 2:
              Navigator.pushNamed(context, '/add-todo');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions_outlined),
            label: 'Da Fare',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_outlined),
            label: 'Completati',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Nuovo',
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList() {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        final todos = todoProvider.todos
            .where((todo) =>
                todo.stato ==
                (_showCompleted ? TodoStatus.completato : TodoStatus.inCorso))
            .toList();

        if (todos.isEmpty) {
          return _buildEmptyState();
        }

        if (!_showCompleted) {
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.all(8),
            itemCount: todos.length,
            onReorder: (oldIndex, newIndex) {
              todoProvider.reorderTodo(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final todo = todos[index];
              return ReorderableDragStartListener(
                key: ValueKey(todo.id),
                index: index,
                child: _buildTodoItem(todo, todoProvider),
              );
            },
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              return _buildTodoItem(todo, todoProvider);
            },
          );
        }
      },
    );
  }

  Widget _buildTodoItem(TodoItem todo, TodoProvider todoProvider) {
    return Dismissible(
      key: ValueKey("${todo.id}_dismissible"),
      confirmDismiss: (direction) async {
        await HapticFeedback.mediumImpact();
        return true;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _showCompleted ? Colors.orange : Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          _showCompleted ? Icons.replay : Icons.check_circle,
          color: Colors.white,
          size: 28,
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _showCompleted ? Colors.orange : Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          _showCompleted ? Icons.replay : Icons.check_circle,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (_) {
        final updatedTodo = todo.copyWith(
          stato: _showCompleted ? TodoStatus.inCorso : TodoStatus.completato,
          dataUltimaModifica: DateTime.now(),
          dataChiusura: !_showCompleted ? DateTime.now() : null,
        );
        todoProvider.updateTodo(updatedTodo);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _showCompleted ? 'TODO riaperto' : 'TODO completato',
              style: const TextStyle(fontSize: 16),
            ),
            behavior: SnackBarBehavior.floating,
            width: 200,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Annulla',
              onPressed: () {
                final revertedTodo = updatedTodo.copyWith(
                  stato: todo.stato,
                  dataUltimaModifica: todo.dataUltimaModifica,
                  dataChiusura: todo.dataChiusura,
                );
                todoProvider.updateTodo(revertedTodo);
              },
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TodoListItem(
          todo: todo,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamed(
              context,
              '/edit-todo',
              arguments: todo,
            );
          },
          onStatusChanged: (newStatus) {
            final updatedTodo = todo.copyWith(
              stato: newStatus,
              dataUltimaModifica: DateTime.now(),
              dataChiusura:
                  newStatus == TodoStatus.completato ? DateTime.now() : null,
            );
            todoProvider.updateTodo(updatedTodo);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showCompleted ? Icons.done_all : Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _showCompleted ? 'Nessun TODO completato' : 'Nessun TODO da fare',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                ),
          ),
          if (!_showCompleted) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/add-todo');
              },
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi TODO'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
