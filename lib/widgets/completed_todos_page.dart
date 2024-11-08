// widgets/completed_todos_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_list_item.dart';

class CompletedTodosPage extends StatelessWidget {
  const CompletedTodosPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        final todos = todoProvider.todos
            .where((todo) => todo.stato == TodoStatus.completato)
            .toList();

        if (todos.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            return _buildCompletedTodoItem(context, todo, todoProvider);
          },
        );
      },
    );
  }

  Widget _buildCompletedTodoItem(
    BuildContext context,
    TodoItem todo,
    TodoProvider todoProvider,
  ) {
    return Dismissible(
      key: ValueKey("${todo.id}_dismissible"),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Elimina
          return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Conferma eliminazione'),
                  content:
                      const Text('Vuoi eliminare definitivamente questo TODO?'),
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
        } else {
          // Ripristina
          await HapticFeedback.mediumImpact();
          return true;
        }
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(
          Icons.replay,
          color: Colors.white,
          size: 28,
        ),
      ),
      secondaryBackground: Container(
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
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Elimina
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
                  content:
                      Text('Errore durante l\'eliminazione: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // Ripristina
          final updatedTodo = todo.copyWith(
            stato: TodoStatus.inCorso,
            dataUltimaModifica: DateTime.now(),
            dataChiusura: null,
          );
          await todoProvider.updateTodo(updatedTodo);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('TODO ripristinato'),
                duration: const Duration(seconds: 2),
                action: SnackBarAction(
                  label: 'Annulla',
                  onPressed: () {
                    final revertedTodo = todo.copyWith(
                      stato: TodoStatus.completato,
                      dataUltimaModifica: todo.dataUltimaModifica,
                      dataChiusura: todo.dataChiusura,
                    );
                    todoProvider.updateTodo(revertedTodo);
                  },
                ),
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
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.done_all,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun TODO completato',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }
}
