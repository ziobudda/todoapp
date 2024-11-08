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
                onTap: () async {
                  final csvData =
                      await context.read<TodoProvider>().exportToCsv();
                  if (context.mounted) {
                    showDialog(
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
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          if (todoProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (todoProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(todoProvider.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => todoProvider.loadTodos(),
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            );
          }

          final todos = todoProvider.todos
              .where((todo) =>
                  todo.stato ==
                  (_showCompleted ? TodoStatus.completato : TodoStatus.inCorso))
              .toList();

          if (todos.isEmpty) {
            return _buildEmptyState();
          }

          if (_showCompleted) {
            // Lista dei TODO completati con swipe per eliminare
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];
                return Dismissible(
                  key: ValueKey(todo.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Conferma eliminazione'),
                            content: const Text(
                                'Vuoi eliminare definitivamente questo TODO?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annulla'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Elimina'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(
                      Icons.delete_forever,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  onDismissed: (_) async {
                    try {
                      await todoProvider.deleteTodo(todo.id!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TODO eliminato definitivamente'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Errore durante l\'eliminazione: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TodoListItem(
                      todo: todo,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/edit-todo',
                          arguments: todo,
                        );
                      },
                    ),
                  ),
                );
              },
            );
          } else {
            // Lista dei TODO attivi con swipe per completare e riordinamento
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
                  child: Dismissible(
                    key: ValueKey("${todo.id}_dismissible"),
                    confirmDismiss: (direction) async {
                      await HapticFeedback.mediumImpact();
                      return true;
                    },
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    secondaryBackground: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    onDismissed: (_) {
                      final updatedTodo = todo.copyWith(
                        stato: TodoStatus.completato,
                        dataUltimaModifica: DateTime.now(),
                        dataChiusura: DateTime.now(),
                      );
                      todoProvider.updateTodo(updatedTodo);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('TODO completato'),
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'Annulla',
                            onPressed: () {
                              final revertedTodo = todo.copyWith(
                                stato: TodoStatus.inCorso,
                                dataUltimaModifica: todo.dataUltimaModifica,
                                dataChiusura: null,
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
                          Navigator.pushNamed(
                            context,
                            '/edit-todo',
                            arguments: todo,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
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
