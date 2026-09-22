import 'mobile_ai.dart';

class AiProposalValidator {
  const AiProposalValidator();

  List<MobileAiDiagnostic> validate(
    MobileAiRequest request,
    Iterable<MobileAiOperation> operations,
  ) {
    final diagnostics = <MobileAiDiagnostic>[];
    final context = request.context;
    final project = _map(context['project']);
    final registry = _map(context['registry']);
    final existingElements = _maps(
      context['elements'],
    ).map((item) => '${item['id']}').toSet();
    final existingEntities = <String>{
      ...existingElements,
      ..._maps(context['relationships']).map((item) => '${item['id']}'),
      ..._maps(context['diagrams']).map((item) => '${item['id']}'),
    };
    final list = operations.toList(growable: false);
    final ids = <String>{};
    final createdElements = <String>{};
    final metaclasses = _strings(registry['element_types']);
    final relationshipTypes = _strings(registry['relationship_types']);

    void add(String id, String message, Map<String, dynamic> evidence) {
      diagnostics.add(
        MobileAiDiagnostic(
          ruleId: id,
          severity: 'error',
          message: message,
          evidence: evidence,
        ),
      );
    }

    if (request.permission == 'viewer') {
      add(
        'proposal.permission.write',
        'El permiso de lector no permite confirmar cambios.',
        const {'permission': 'viewer'},
      );
    }
    if ((project['revision'] as num?)?.toInt() != request.baseRevision) {
      add(
        'proposal.revision.current',
        'La propuesta fue generada sobre una revisión distinta.',
        {'expected': project['revision'], 'received': request.baseRevision},
      );
    }
    if (list.length > 200) {
      add(
        'proposal.operations.limit',
        'La propuesta supera el límite de operaciones.',
        {'count': list.length, 'maximum': 200},
      );
    }
    for (final operation in list) {
      if (!ids.add(operation.id)) {
        add(
          'proposal.operation.identity',
          'Cada operación debe tener una identidad única.',
          {'operation_id': operation.id},
        );
      }
      final entityId = operation.entityId ?? '${operation.value['id'] ?? ''}';
      if (operation.action == 'create' && entityId.isEmpty) {
        add(
          'proposal.entity.identity',
          'Las creaciones locales requieren una identidad estable.',
          {'operation_id': operation.id},
        );
      }
      if (operation.action != 'create' &&
          (entityId.isEmpty || !existingEntities.contains(entityId))) {
        add(
          'proposal.entity.exists',
          'La entidad que se intenta modificar no existe en el contexto.',
          {'operation_id': operation.id, 'entity_id': entityId},
        );
      }
      if (operation.entityType == 'UmlElement' &&
          operation.action == 'create') {
        final metaclass = '${operation.value['metaclass'] ?? ''}';
        if (metaclasses.isNotEmpty && !metaclasses.contains(metaclass)) {
          add(
            'proposal.element.metaclass',
            'La propuesta usa una metaclase no registrada.',
            {'operation_id': operation.id, 'metaclass': metaclass},
          );
        }
        if (entityId.isNotEmpty) createdElements.add(entityId);
      }
    }
    final availableElements = {...existingElements, ...createdElements};
    for (final operation in list.where(
      (item) => item.entityType == 'UmlRelationship' && item.action == 'create',
    )) {
      final type = '${operation.value['relationship_type'] ?? ''}';
      final source = '${operation.value['source'] ?? ''}';
      final target = '${operation.value['target'] ?? ''}';
      if (relationshipTypes.isNotEmpty && !relationshipTypes.contains(type)) {
        add(
          'proposal.relationship.type',
          'La propuesta usa una relación no registrada.',
          {'operation_id': operation.id, 'relationship_type': type},
        );
      }
      if (!availableElements.contains(source) ||
          !availableElements.contains(target)) {
        add(
          'proposal.relationship.endpoints',
          'La relación propuesta no conecta elementos disponibles.',
          {'operation_id': operation.id, 'source': source, 'target': target},
        );
      }
    }
    for (final operation in list) {
      for (final dependency in operation.dependsOn) {
        if (!ids.contains(dependency)) {
          add(
            'proposal.dependency.exists',
            'La operación depende de otra operación ausente.',
            {'operation_id': operation.id, 'dependency': dependency},
          );
        }
      }
    }
    diagnostics.sort((a, b) => a.ruleId.compareTo(b.ruleId));
    return diagnostics;
  }
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : const {};
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(_map).toList(growable: false)
    : const [];
Set<String> _strings(Object? value) =>
    value is List ? value.map((item) => '$item').toSet() : const {};
