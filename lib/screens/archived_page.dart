// lib/screens/archived_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_list_item.dart';

class ArchivedPage extends StatefulWidget {
  const ArchivedPage({Key? key}) : super(key: key);

  @override
  State<ArchivedPage> createState() => _ArchivedPageState();
}

class _ArchivedPageState extends State<ArchivedPage> {
  @override
  void initState() {
    super.initState();
    // Carica i TODO archiviati
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoProvider>()
        ..toggleArchived()
        ..loadTodos();
    });
  }

  @override
  void dispose() {
    // Ripristina la visualizzazione normale quando si esce
    context.read<TodoProvider>().toggleArchived();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO Archiviati'),
      ),
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          final archivedTodos = todoProvider.todos
              .where((todo) => todo.stato == TodoStatus.archiviato)
              .toList();

          if (archivedTodos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun TODO archiviato',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.5),
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: archivedTodos.length,
            itemBuilder: (context, index) {
              final todo = archivedTodos[index];
              return Dismissible(
                key: ValueKey(todo.id),
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(
                    Icons.unarchive,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                secondaryBackground: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(
                    Icons.unarchive,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                onDismissed: (_) {
                  final updatedTodo = todo.copyWith(
                    stato: TodoStatus.inCorso,
                    dataUltimaModifica: DateTime.now(),
                  );
                  todoProvider.updateTodo(updatedTodo);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'TODO ripristinato',
                        style: TextStyle(fontSize: 16),
                      ),
                      behavior: SnackBarBehavior.floating,
                      width: 200,
                      duration: const Duration(seconds: 2),
                      action: SnackBarAction(
                        label: 'Annulla',
                        onPressed: () {
                          final revertedTodo = todo.copyWith(
                            stato: TodoStatus.archiviato,
                            dataUltimaModifica: todo.dataUltimaModifica,
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
              );
            },
          );
        },
      ),
    );
  }
}
