// widgets/active_todos_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_list_item.dart';

class ActiveTodosPage extends StatelessWidget {
  const ActiveTodosPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        final todos = todoProvider.todos
            .where((todo) => todo.stato == TodoStatus.inCorso)
            .toList();

        if (todos.isEmpty) {
          return _buildEmptyState(context);
        }

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
              child: _buildActiveTodoItem(context, todo, todoProvider),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveTodoItem(
    BuildContext context,
    TodoItem todo,
    TodoProvider todoProvider,
  ) {
    return Dismissible(
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
      onDismissed: (_) async {
        final updatedTodo = todo.copyWith(
          stato: TodoStatus.completato,
          dataUltimaModifica: DateTime.now(),
          dataChiusura: DateTime.now(),
        );
        await todoProvider.updateTodo(updatedTodo);
        if (context.mounted) {
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
            Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun TODO da fare',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                ),
          ),
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
      ),
    );
  }
}
