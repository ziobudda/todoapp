// widgets/todo_list_item.dart

import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoListItem extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onTap;
  final Function(TodoStatus)? onStatusChanged;

  const TodoListItem({
    Key? key,
    required this.todo,
    required this.onTap,
    this.onStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = todo.stato == TodoStatus.completato;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      todo.testo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  // Mostra l'icona di stato solo se il todo non è completato
                  if (!isCompleted) _buildStatusIcon(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Inserito il: ${_formatDate(todo.dataInserimento)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
              if (todo.dataChiusura != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Completato il: ${_formatDate(todo.dataChiusura!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (todo.stato) {
      case TodoStatus.inCorso:
        icon = Icons.pending;
        color = Colors.orange;
        break;
      case TodoStatus.completato:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case TodoStatus.archiviato:
        icon = Icons.archive;
        color = Colors.grey;
        break;
    }

    return Icon(icon, color: color);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
