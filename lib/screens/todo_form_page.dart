// screens/todo_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/todo_item.dart';
import '../providers/todo_provider.dart';

class TodoFormPage extends StatefulWidget {
  final TodoItem? todo;

  const TodoFormPage({Key? key, this.todo}) : super(key: key);

  @override
  State<TodoFormPage> createState() => _TodoFormPageState();
}

class _TodoFormPageState extends State<TodoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _testoController;
  late TodoStatus _statoSelezionato;
  late TextEditingController _oreLavorateController;
  bool _isModifica = false;

  @override
  void initState() {
    super.initState();
    _isModifica = widget.todo != null;
    _testoController = TextEditingController(text: widget.todo?.testo ?? '');
    _statoSelezionato = widget.todo?.stato ?? TodoStatus.inCorso;
    _oreLavorateController = TextEditingController(
      text: widget.todo?.oreLavorate.toString() ?? '0.0',
    );
  }

  @override
  void dispose() {
    _testoController.dispose();
    _oreLavorateController.dispose();
    super.dispose();
  }

  Future<void> _salvaTodo() async {
    if (_formKey.currentState!.validate()) {
      final todoProvider = context.read<TodoProvider>();
      final todo = TodoItem(
        id: widget.todo?.id,
        testo: _testoController.text,
        stato: _statoSelezionato,
        oreLavorate: double.parse(_oreLavorateController.text),
        dataCreazione: widget.todo?.dataCreazione,
      );

      try {
        if (_isModifica) {
          await todoProvider.updateTodo(todo);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('TODO aggiornato con successo')),
            );
          }
        } else {
          await todoProvider.addTodo(todo);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('TODO creato con successo')),
            );
          }
        }
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _eliminaTodo() async {
    final confermato = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text('Sei sicuro di voler eliminare questo TODO?'),
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
    );

    if (confermato == true && mounted) {
      try {
        await context.read<TodoProvider>().deleteTodo(widget.todo!.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TODO eliminato con successo')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore durante l\'eliminazione: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isModifica ? 'Modifica TODO' : 'Nuovo TODO'),
        actions: [
          if (_isModifica)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _eliminaTodo,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _testoController,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Inserisci una descrizione';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<TodoStatus>(
              segments: const [
                ButtonSegment(
                  value: TodoStatus.inCorso,
                  label: Text('In Corso'),
                ),
                ButtonSegment(
                  value: TodoStatus.completato,
                  label: Text('Completato'),
                ),
              ],
              selected: {_statoSelezionato},
              onSelectionChanged: (Set<TodoStatus> selected) {
                setState(() => _statoSelezionato = selected.first);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _oreLavorateController,
              decoration: const InputDecoration(
                labelText: 'Ore lavorate',
                border: OutlineInputBorder(),
                suffixText: 'ore',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Inserisci le ore lavorate';
                }
                final ore = double.tryParse(value);
                if (ore == null) {
                  return 'Inserisci un numero valido';
                }
                if (ore < 0) {
                  return 'Le ore non possono essere negative';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _salvaTodo,
              icon: Icon(_isModifica ? Icons.save : Icons.add),
              label: Text(
                _isModifica ? 'Salva modifiche' : 'Crea TODO',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
