import 'dart:async';
import 'dart:convert';

enum MobileAiMode { automatic, api, local }

enum MobileAiOrigin { remote, local, rules }

class MobileAiCancellation {
  bool _cancelled = false;
  final _controller = StreamController<void>.broadcast();

  bool get isCancelled => _cancelled;
  Stream<void> get onCancel => _controller.stream;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _controller.add(null);
  }

  Future<void> close() => _controller.close();
}

class MobileAiRequest {
  const MobileAiRequest({
    required this.projectId,
    required this.prompt,
    required this.baseRevision,
    required this.permission,
    required this.context,
    this.selection = const [],
    this.mode = MobileAiMode.automatic,
  });

  final String projectId;
  final String prompt;
  final int baseRevision;
  final String permission;
  final Map<String, dynamic> context;
  final List<String> selection;
  final MobileAiMode mode;

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'prompt': prompt.trim(),
    'base_revision': baseRevision,
    'permission': permission,
    'selection': selection,
    'context': context,
  };
}

class MobileAiOperation {
  const MobileAiOperation({
    required this.id,
    required this.entityType,
    required this.action,
    required this.value,
    this.entityId,
    this.path = '',
    this.dependsOn = const [],
    this.explanation = '',
  });

  static const allowedEntities = {
    'UmlPackage',
    'UmlElement',
    'UmlRelationship',
    'Diagram',
    'DiagramNode',
    'DiagramEdge',
  };
  static const allowedActions = {'create', 'update', 'delete'};

  final String id;
  final String entityType;
  final String action;
  final String? entityId;
  final String path;
  final Map<String, dynamic> value;
  final List<String> dependsOn;
  final String explanation;

  factory MobileAiOperation.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final entityType = '${json['entity_type'] ?? ''}'.trim();
    final action = '${json['action'] ?? ''}'.trim();
    final rawValue = json['value'] ?? json['new_value'];
    if (id.isEmpty ||
        !allowedEntities.contains(entityType) ||
        !allowedActions.contains(action) ||
        rawValue is! Map) {
      throw const FormatException('Operación de IA inválida.');
    }
    return MobileAiOperation(
      id: id,
      entityType: entityType,
      action: action,
      entityId: json['entity_id']?.toString(),
      path: '${json['path'] ?? ''}',
      value: rawValue.map((key, value) => MapEntry('$key', value)),
      dependsOn: _strings(json['depends_on']),
      explanation: '${json['explanation'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity_type': entityType,
    'action': action,
    if (entityId != null) 'entity_id': entityId,
    if (path.isNotEmpty) 'path': path,
    'value': value,
    if (dependsOn.isNotEmpty) 'depends_on': dependsOn,
    if (explanation.isNotEmpty) 'explanation': explanation,
  };
}

class MobileAiDiagnostic {
  const MobileAiDiagnostic({
    required this.ruleId,
    required this.severity,
    required this.message,
    this.evidence = const {},
    this.question,
    this.repair,
  });

  final String ruleId;
  final String severity;
  final String message;
  final Map<String, dynamic> evidence;
  final String? question;
  final Map<String, dynamic>? repair;

  bool get blocksConfirmation => severity == 'error';

  factory MobileAiDiagnostic.fromJson(Map<String, dynamic> json) =>
      MobileAiDiagnostic(
        ruleId: '${json['rule_id'] ?? json['id'] ?? ''}',
        severity: '${json['severity'] ?? 'warning'}',
        message: '${json['message'] ?? ''}',
        evidence: _map(json['evidence']),
        question: json['question']?.toString(),
        repair: json['repair'] is Map ? _map(json['repair']) : null,
      );

  Map<String, dynamic> toJson() => {
    'rule_id': ruleId,
    'severity': severity,
    'message': message,
    'evidence': evidence,
    if (question != null) 'question': question,
    if (repair != null) 'repair': repair,
  };
}

class MobileAiResponse {
  const MobileAiResponse({
    required this.id,
    required this.origin,
    required this.model,
    required this.operations,
    this.questions = const [],
    this.assumptions = const [],
    this.warnings = const [],
    this.diagnostics = const [],
  });

  final String id;
  final MobileAiOrigin origin;
  final String model;
  final List<MobileAiOperation> operations;
  final List<String> questions;
  final List<String> assumptions;
  final List<String> warnings;
  final List<MobileAiDiagnostic> diagnostics;

  bool get canConfirm =>
      questions.isEmpty && !diagnostics.any((item) => item.blocksConfirmation);

  factory MobileAiResponse.fromJson(
    Map<String, dynamic> json, {
    required MobileAiOrigin origin,
    required String model,
  }) {
    final proposal = json['proposal'] is Map ? _map(json['proposal']) : json;
    final operations = proposal['operations'];
    if (operations is! List || operations.length > 200) {
      throw const FormatException('Lote de IA inválido.');
    }
    return MobileAiResponse(
      id: '${json['id'] ?? proposal['id'] ?? ''}',
      origin: origin,
      model: '${json['model'] ?? model}',
      operations: operations
          .whereType<Map>()
          .map((item) => MobileAiOperation.fromJson(_map(item)))
          .toList(growable: false),
      questions: _strings(proposal['questions']),
      assumptions: _strings(proposal['assumptions']),
      warnings: _strings(proposal['warnings'] ?? json['warnings']),
      diagnostics: _maps(
        proposal['diagnostics'],
      ).map(MobileAiDiagnostic.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin.name,
    'model': model,
    'operations': operations.map((item) => item.toJson()).toList(),
    'questions': questions,
    'assumptions': assumptions,
    'warnings': warnings,
    'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
  };
}

abstract class MobileAiEngine {
  String get id;
  Future<bool> isAvailable();

  Future<MobileAiResponse> propose(
    MobileAiRequest request, {
    MobileAiCancellation? cancellation,
    void Function(String token)? onToken,
  });
}

class MobileAiException implements Exception {
  const MobileAiException(this.message, {this.code = 'ai_error'});
  final String message;
  final String code;

  @override
  String toString() => message;
}

Map<String, dynamic> decodeAiJson(String raw) {
  final normalized = raw.replaceFirst('\uFEFF', '').trim();
  if (normalized.isEmpty) {
    throw const FormatException('La IA local devolvió una respuesta vacía.');
  }
  final jsonObject = _firstCompleteJsonObject(normalized);
  if (jsonObject == null) {
    throw const FormatException(
      'La IA local no terminó de generar un objeto JSON válido.',
    );
  }
  final decoded = jsonDecode(jsonObject);
  if (decoded is! Map) {
    throw const FormatException('La IA no devolvió un objeto JSON.');
  }
  return _map(decoded);
}

String? _firstCompleteJsonObject(String raw) {
  var start = -1;
  var depth = 0;
  var inString = false;
  var escaped = false;

  for (var index = 0; index < raw.length; index++) {
    final character = raw[index];
    if (start < 0) {
      if (character == '{') {
        start = index;
        depth = 1;
      }
      continue;
    }
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character == r'\') {
        escaped = true;
      } else if (character == '"') {
        inString = false;
      }
      continue;
    }
    if (character == '"') {
      inString = true;
    } else if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) return raw.substring(start, index + 1);
    }
  }
  return null;
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(_map).toList(growable: false)
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.map((item) => '$item').where((item) => item.isNotEmpty).toList()
    : const [];
