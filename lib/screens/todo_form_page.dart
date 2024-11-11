import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Speech recognition variables
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastError = '';
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _isModifica = widget.todo != null;
    _testoController = TextEditingController(text: widget.todo?.testo ?? '');
    _statoSelezionato = widget.todo?.stato ?? TodoStatus.inCorso;
    _oreLavorateController = TextEditingController(
      text: widget.todo?.oreLavorate.toString() ?? '0.0',
    );
    _initializeSpeechRecognition();
  }

  Future<void> _initializeSpeechRecognition() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
      _lastError = '';
    });

    try {
      final isAvailable = await _speechToText.initialize(
        onStatus: _handleSpeechStatus,
        onError: (error) => _handleError(error.errorMsg),
        debugLogging: true,
      );

      if (!isAvailable) {
        _handleError('Il riconoscimento vocale non è disponibile su questo dispositivo');
        return;
      }

      // Get the list of available locales
      final locales = await _speechToText.locales();

      // Try to find Italian locale
      final italianLocale = locales.firstWhere(
        (locale) => locale.localeId.startsWith('it_'),
        orElse: () => locales.first, // Fallback to first available locale
      );

      setState(() {
        _speechEnabled = true;
        _lastError = '';
        if (!italianLocale.localeId.startsWith('it_')) {
          _showWarningSnackBar('Lingua italiana non disponibile, verrà utilizzata: ${italianLocale.name}');
        }
      });
    } catch (e) {
      _handleError('Errore durante l\'inizializzazione: $e');
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  void _handleSpeechStatus(String status) {
    debugPrint('Speech recognition status: $status');
    if (mounted) {
      setState(() {
        switch (status) {
          case 'listening':
            _isListening = true;
            break;
          case 'notListening':
          case 'done':
            _isListening = false;
            break;
          case 'error':
            _isListening = false;
            break;
        }
      });
    }
  }

  void _handleError(String message) {
    debugPrint('Speech recognition error: $message');
    String userMessage;

    switch (message) {
      case 'error_no_match':
        userMessage = 'Non ho capito. Prova a parlare più chiaramente.';
        break;
      case 'error_speech_timeout':
        userMessage = 'Non ho sentito nulla. Prova di nuovo.';
        break;
      case 'error_network':
        userMessage = 'Errore di rete. Verifica la tua connessione.';
        break;
      case 'error_permission':
        userMessage = 'Permesso microfono non concesso.';
        break;
      case 'error_busy':
        userMessage = 'Riconoscimento vocale occupato. Riprova tra poco.';
        break;
      case 'error_not_available':
        userMessage = 'Riconoscimento vocale non disponibile su questo dispositivo.';
        break;
      default:
        userMessage = 'Errore: $message';
    }

    setState(() {
      _lastError = userMessage;
      _isListening = false;
      if (message.contains('permission') || message.contains('not_available')) {
        _speechEnabled = false;
      }
    });
    _showErrorSnackBar(userMessage);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Riprova',
          textColor: Colors.white,
          onPressed: _initializeSpeechRecognition,
        ),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _handleError('È necessario concedere il permesso del microfono');
      return;
    }

    setState(() => _lastError = '');

    try {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            if (result.recognizedWords.isNotEmpty) {
              final currentText = _testoController.text;
              _testoController.text = currentText.isEmpty
                  ? result.recognizedWords
                  : '$currentText\n${result.recognizedWords}';
            }
          });
        },
        localeId: 'it_IT',
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      _handleError('Errore durante l\'avvio del riconoscimento: $e');
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } catch (e) {
      _handleError('Errore durante l\'arresto del riconoscimento: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (_isInitializing) {
      _showWarningSnackBar('Inizializzazione in corso...');
      return;
    }

    if (!_speechEnabled) {
      await _initializeSpeechRecognition();
      if (!_speechEnabled) return;
    }

    if (_speechToText.isNotListening) {
      await _startListening();
    } else {
      await _stopListening();
    }
  }

  @override
  void dispose() {
    _testoController.dispose();
    _oreLavorateController.dispose();
    _speechToText.stop();
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
              tooltip: 'Elimina TODO',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Stack(
              alignment: Alignment.centerRight,
              children: [
                TextFormField(
                  controller: _testoController,
                  decoration: InputDecoration(
                    labelText: 'Descrizione',
                    border: const OutlineInputBorder(),
                    helperText: _lastError.isNotEmpty ? _lastError : null,
                    helperStyle: _lastError.isNotEmpty
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                    helperMaxLines: 2,
                    suffixIcon: Tooltip(
                      message: _isInitializing
                          ? 'Inizializzazione in corso...'
                          : (_speechEnabled
                              ? (_isListening
                                  ? 'Interrompi registrazione'
                                  : 'Inizia registrazione')
                              : 'Riconoscimento vocale non disponibile'),
                      child: IconButton(
                        onPressed: _isInitializing ? null : _toggleListening,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _isInitializing
                                ? Icons.sync
                                : (_isListening ? Icons.mic : Icons.mic_none),
                            key: ValueKey<bool>(_isListening),
                            color: _isListening
                                ? Theme.of(context).colorScheme.primary
                                : (_speechEnabled ? null : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci una descrizione';
                    }
                    return null;
                  },
                ),
                if (_isListening)
                  Positioned(
                    right: 48,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<TodoStatus>(
              segments: const [
                ButtonSegment(
                  value: TodoStatus.inCorso,
                  label: Text('In Corso'),
                  icon: Icon(Icons.pending_actions),
                ),
                ButtonSegment(
                  value: TodoStatus.completato,
                  label: Text('Completato'),
                  icon: Icon(Icons.task_alt),
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
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      bottomSheet: _isListening
                        ? Container(
                            width: double.infinity,
                            color: Theme.of(context).colorScheme.primaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mic, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Sto ascoltando...',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _stopListening,
                                  child: const Text('STOP'),
                                ),
                              ],
                            ),
                          )
                        : null,
                    );
                  }
                }
