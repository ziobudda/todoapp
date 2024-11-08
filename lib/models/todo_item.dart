// models/todo_item.dart

enum TodoStatus { inCorso, completato, archiviato }

class TodoItem {
  final int? id;
  String testo;
  TodoStatus stato;
  double oreLavorate;
  final DateTime dataCreazione;
  final DateTime dataInserimento;
  DateTime? dataChiusura;
  DateTime dataUltimaModifica;
  int peso; // Nuovo campo per l'ordinamento

  TodoItem({
    this.id,
    required this.testo,
    this.stato = TodoStatus.inCorso,
    this.oreLavorate = 0.0,
    DateTime? dataCreazione,
    DateTime? dataInserimento,
    this.dataChiusura,
    DateTime? dataUltimaModifica,
    this.peso = 0, // Valore predefinito
  })  : dataCreazione = dataCreazione ?? DateTime.now(),
        dataInserimento = dataInserimento ?? DateTime.now(),
        dataUltimaModifica = dataUltimaModifica ?? DateTime.now();

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'] as int?,
      testo: map['testo'] as String,
      stato: TodoStatus.values[map['stato'] as int],
      oreLavorate: map['oreLavorate'] as double,
      dataCreazione: DateTime.parse(map['dataCreazione'] as String),
      dataInserimento: DateTime.parse(map['dataInserimento'] as String),
      dataChiusura: map['dataChiusura'] != null
          ? DateTime.parse(map['dataChiusura'] as String)
          : null,
      dataUltimaModifica: DateTime.parse(map['dataUltimaModifica'] as String),
      peso: map['peso'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'testo': testo,
      'stato': stato.index,
      'oreLavorate': oreLavorate,
      'dataCreazione': dataCreazione.toIso8601String(),
      'dataInserimento': dataInserimento.toIso8601String(),
      'dataChiusura': dataChiusura?.toIso8601String(),
      'dataUltimaModifica': dataUltimaModifica.toIso8601String(),
      'peso': peso,
    };
  }

  TodoItem copyWith({
    int? id,
    String? testo,
    TodoStatus? stato,
    double? oreLavorate,
    DateTime? dataCreazione,
    DateTime? dataInserimento,
    DateTime? dataChiusura,
    DateTime? dataUltimaModifica,
    int? peso,
  }) {
    return TodoItem(
      id: id ?? this.id,
      testo: testo ?? this.testo,
      stato: stato ?? this.stato,
      oreLavorate: oreLavorate ?? this.oreLavorate,
      dataCreazione: dataCreazione ?? this.dataCreazione,
      dataInserimento: dataInserimento ?? this.dataInserimento,
      dataChiusura: dataChiusura ?? this.dataChiusura,
      dataUltimaModifica: dataUltimaModifica ?? DateTime.now(),
      peso: peso ?? this.peso,
    );
  }
}
