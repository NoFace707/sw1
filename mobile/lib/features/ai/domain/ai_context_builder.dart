import '../../viewer/domain/viewer_models.dart';

class AiContextBuilder {
  static final _secretKey = RegExp(
    r'(token|secret|password|authorization|cookie|invite|api.?key|code)',
    caseSensitive: false,
  );

  Map<String, dynamic> build({
    required UmlSnapshot snapshot,
    String? diagramId,
    List<String> selectedElementIds = const [],
  }) {
    final selected = selectedElementIds.toSet();
    final related = <String>{...selected};
    for (final relationship in snapshot.relationships) {
      if (selected.contains(relationship.sourceId) ||
          selected.contains(relationship.targetId)) {
        related.add(relationship.sourceId);
        related.add(relationship.targetId);
      }
    }
    final includeAll = selected.isEmpty;
    final elements = snapshot.elements
        .where((item) => includeAll || related.contains(item.id))
        .map((item) => sanitize(item.toJson()))
        .toList(growable: false);
    final relationships = snapshot.relationships
        .where(
          (item) =>
              includeAll ||
              (related.contains(item.sourceId) &&
                  related.contains(item.targetId)),
        )
        .map((item) => sanitize(item.toJson()))
        .toList(growable: false);
    final diagram = snapshot.diagramById(diagramId);
    return sanitize({
      'project': {
        'id': snapshot.project.id,
        'name': snapshot.project.name,
        'revision': snapshot.project.revision,
      },
      if (diagram != null) 'diagram': diagram.toJson(),
      'diagrams': snapshot.diagrams.map((item) => item.toJson()).toList(),
      'elements': elements,
      'relationships': relationships,
      'selection': selected.toList()..sort(),
    });
  }

  Map<String, dynamic> sanitize(Map<String, dynamic> input) =>
      _sanitizeValue(input) as Map<String, dynamic>;

  Object? _sanitizeValue(Object? value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = '${entry.key}';
        if (_secretKey.hasMatch(key)) continue;
        result[key] = _sanitizeValue(entry.value);
      }
      return result;
    }
    if (value is List) return value.map(_sanitizeValue).toList();
    return value;
  }
}
