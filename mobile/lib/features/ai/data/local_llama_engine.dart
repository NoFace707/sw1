import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../domain/expert_evaluator.dart';
import '../domain/ai_proposal_validator.dart';
import '../domain/mobile_ai.dart';

abstract class LocalModelRuntime {
  Stream<String> generate(LocalAiPrompt prompt);
  Future<void> cancel();
  Future<void> close();
}

class LocalAiPrompt {
  const LocalAiPrompt({required this.system, required this.user});

  final String system;
  final String user;
}

typedef LocalRuntimeFactory = Future<LocalModelRuntime> Function();

class LocalLlamaEngine implements MobileAiEngine {
  LocalLlamaEngine({
    required this.runtimeFactory,
    required this.available,
    required this.evaluator,
    this.model = 'Qwen2.5-Coder-1.5B-Instruct-GGUF-Q4_K_M',
  });

  final LocalRuntimeFactory runtimeFactory;
  final Future<bool> Function() available;
  final ExpertEvaluator evaluator;
  final String model;
  bool _running = false;

  @override
  String get id => 'local-llama';

  @override
  Future<bool> isAvailable() => available();

  @override
  Future<MobileAiResponse> propose(
    MobileAiRequest request, {
    MobileAiCancellation? cancellation,
    void Function(String token)? onToken,
  }) async {
    if (_running) {
      throw const MobileAiException(
        'Ya hay una inferencia local en curso.',
        code: 'local_busy',
      );
    }
    if (cancellation?.isCancelled == true) {
      throw const MobileAiException('Solicitud cancelada.', code: 'cancelled');
    }
    if (!await isAvailable()) {
      throw const MobileAiException(
        'El modelo local no está instalado o el dispositivo no es compatible.',
        code: 'local_unavailable',
      );
    }

    _running = true;
    LocalModelRuntime? runtime;
    StreamSubscription<void>? cancellationSubscription;
    try {
      runtime = await runtimeFactory();
      cancellationSubscription = cancellation?.onCancel.listen((_) {
        unawaited(runtime?.cancel());
      });
      final buffer = StringBuffer();
      await for (final token in runtime.generate(buildQwenPrompt(request))) {
        if (cancellation?.isCancelled == true) {
          throw const MobileAiException(
            'Solicitud cancelada.',
            code: 'cancelled',
          );
        }
        if (buffer.length + token.length > 1024 * 1024) {
          throw const MobileAiException(
            'La respuesta local superó el tamaño permitido.',
            code: 'response_too_large',
          );
        }
        buffer.write(token);
        onToken?.call(token);
      }
      if (cancellation?.isCancelled == true) {
        throw const MobileAiException(
          'Solicitud cancelada.',
          code: 'cancelled',
        );
      }
      final payload = _withOperationIds(decodeAiJson(buffer.toString()));
      final diagnostics = evaluator.evaluate({
        ...request.context,
        'permission': request.permission,
        'operations': payload['operations'] ?? const [],
      });
      final parsed = MobileAiResponse.fromJson(
        {'id': const Uuid().v4(), ...payload, 'model': model},
        origin: MobileAiOrigin.local,
        model: model,
      );
      final proposalDiagnostics = const AiProposalValidator().validate(
        request,
        parsed.operations,
      );
      final questions = <String>{
        ..._strings(payload['questions']),
        ...diagnostics
            .where((item) => item.question?.trim().isNotEmpty == true)
            .map((item) => item.question!.trim()),
      }.toList(growable: false);
      return MobileAiResponse(
        id: parsed.id,
        origin: parsed.origin,
        model: parsed.model,
        operations: parsed.operations,
        questions: questions,
        assumptions: parsed.assumptions,
        warnings: parsed.warnings,
        diagnostics: [...diagnostics, ...proposalDiagnostics],
      );
    } on FormatException {
      throw const MobileAiException(
        'La IA local no logró completar una propuesta válida. '
        'Inténtalo de nuevo con una solicitud más concreta o usa el modo API.',
        code: 'invalid_json',
      );
    } on MobileAiException {
      rethrow;
    } catch (error) {
      throw MobileAiException(
        'La inferencia local falló antes de completar la respuesta. '
        'Vuelve a intentarlo o usa el modo API. Detalle: '
        '${_cleanRuntimeError(error)}',
        code: 'local_runtime_error',
      );
    } finally {
      await cancellationSubscription?.cancel();
      await runtime?.close();
      _running = false;
    }
  }

  Map<String, dynamic> _withOperationIds(Map<String, dynamic> payload) {
    final operations = payload['operations'];
    if (operations is! List) return payload;
    return {
      ...payload,
      'operations': operations.map((operation) {
        if (operation is! Map) return operation;
        return {
          ...operation.map((key, value) => MapEntry('$key', value)),
          if ('${operation['id'] ?? ''}'.isEmpty) 'id': const Uuid().v4(),
        };
      }).toList(),
    };
  }
}

LocalAiPrompt buildQwenPrompt(MobileAiRequest request) {
  final schema = {
    'operations': [
      {
        'id': 'uuid-opcional',
        'entity_type':
            'UmlPackage|UmlElement|UmlRelationship|Diagram|DiagramNode|DiagramEdge',
        'entity_id': 'uuid-si-aplica',
        'action': 'create|update|delete',
        'value': <String, dynamic>{},
        'depends_on': <String>[],
        'explanation': 'motivo breve',
      },
    ],
    'questions': <String>[],
    'assumptions': <String>[],
    'warnings': <String>[],
  };
  return LocalAiPrompt(
    system: '''Eres un asistente UML 2.5.1 integrado en un modelador.
Responde exclusivamente con un objeto JSON válido, sin Markdown, comentarios ni texto antes o después.
No inventes IDs existentes, permisos ni datos ausentes. Si falta una decisión necesaria, agrega una pregunta y no generes la operación dependiente.
Si el mensaje es un saludo o no solicita una edición, devuelve operations vacío y una pregunta breve para saber qué desea modelar.
Máximo 200 operaciones. Respeta la revisión base y el alcance recibido.''',
    user:
        'ESQUEMA=${jsonEncode(schema)}\nSOLICITUD=${jsonEncode(request.toJson())}',
  );
}

String _cleanRuntimeError(Object error) => '$error'
    .replaceFirst('Bad state: ', '')
    .replaceFirst('Exception: ', '')
    .replaceFirst(RegExp(r'\s*#\d+.*', dotAll: true), '')
    .trim();

List<String> _strings(Object? value) => value is List
    ? value.map((item) => '$item').where((item) => item.isNotEmpty).toList()
    : const [];
