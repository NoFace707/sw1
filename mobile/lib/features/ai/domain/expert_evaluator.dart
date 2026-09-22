import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'mobile_ai.dart';

class ExpertRuleSet {
  const ExpertRuleSet({
    required this.version,
    required this.registryVersion,
    required this.rules,
    required this.checksum,
  });

  final String version;
  final String registryVersion;
  final List<Map<String, dynamic>> rules;
  final String checksum;

  factory ExpertRuleSet.verified(Map<String, dynamic> payload) {
    final unsigned = Map<String, dynamic>.from(payload)..remove('checksum');
    final actual = sha256
        .convert(utf8.encode(canonicalJson(unsigned)))
        .toString();
    final expected = '${payload['checksum'] ?? ''}';
    final rules = payload['rules'];
    if (expected.length != 64 || actual != expected || rules is! List) {
      throw const FormatException('La base de reglas no supera integridad.');
    }
    final parsed = rules
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
    for (final rule in parsed) {
      if (!_validRule(rule)) {
        throw const FormatException('La base contiene una regla inválida.');
      }
    }
    return ExpertRuleSet(
      version: '${payload['version']}',
      registryVersion: '${payload['registry_version']}',
      rules: parsed,
      checksum: expected,
    );
  }

  static bool _validRule(Map<String, dynamic> rule) {
    return '${rule['id']}'.isNotEmpty &&
        {'error', 'warning', 'info'}.contains(rule['severity']) &&
        rule['condition'] is Map &&
        '${rule['message']}'.isNotEmpty &&
        rule.containsKey('evidence') &&
        rule.containsKey('question') &&
        rule.containsKey('repair') &&
        rule.containsKey('mapping');
  }
}

class ExpertEvaluator {
  const ExpertEvaluator(this.ruleSet);
  final ExpertRuleSet ruleSet;

  List<MobileAiDiagnostic> evaluate(Map<String, dynamic> context) {
    final result = <MobileAiDiagnostic>[];
    for (final rule in ruleSet.rules) {
      for (final evidence in _violations(rule, context)) {
        result.add(
          MobileAiDiagnostic(
            ruleId: '${rule['id']}',
            severity: '${rule['severity']}',
            message: '${rule['message']}',
            evidence: evidence,
            question: rule['question']?.toString(),
            repair: rule['repair'] is Map ? _map(rule['repair']) : null,
          ),
        );
      }
    }
    const order = {'error': 0, 'warning': 1, 'info': 2};
    result.sort((a, b) {
      final severity = (order[a.severity] ?? 9).compareTo(
        order[b.severity] ?? 9,
      );
      return severity != 0 ? severity : a.ruleId.compareTo(b.ruleId);
    });
    return result;
  }

  List<Map<String, dynamic>> _violations(
    Map<String, dynamic> rule,
    Map<String, dynamic> context,
  ) {
    final condition = _map(rule['condition']);
    final operator = '${condition['operator']}';
    final elements = _maps(context['elements']);
    final relationships = _maps(context['relationships']);
    switch (operator) {
      case 'stable_identity':
        return elements
            .where((item) => '${item['id'] ?? ''}'.trim().isEmpty)
            .map((item) => {'entity': item})
            .toList();
      case 'non_blank_name':
        return elements
            .where((item) => '${item['name'] ?? ''}'.trim().isEmpty)
            .map((item) => {'entity_id': item['id']})
            .toList();
      case 'known_metaclass':
        final allowed = _strings(
          context['registry'] is Map
              ? _map(context['registry'])['element_types']
              : null,
        );
        if (allowed.isEmpty) return const [];
        return elements
            .where((item) => !allowed.contains('${item['metaclass']}'))
            .map(
              (item) => {
                'entity_id': item['id'],
                'metaclass': item['metaclass'],
              },
            )
            .toList();
      case 'known_relationship':
        final allowed = _strings(
          context['registry'] is Map
              ? _map(context['registry'])['relationship_types']
              : null,
        );
        if (allowed.isEmpty) return const [];
        return relationships
            .where(
              (item) => !allowed.contains(
                '${item['relationship_type'] ?? item['type']}',
              ),
            )
            .map(
              (item) => {
                'relationship_id': item['id'],
                'relationship_type': item['relationship_type'] ?? item['type'],
              },
            )
            .toList();
      case 'existing_endpoints':
        final ids = elements.map((item) => '${item['id']}').toSet();
        return relationships
            .where(
              (item) =>
                  !ids.contains('${item['source'] ?? item['source_id']}') ||
                  !ids.contains('${item['target'] ?? item['target_id']}'),
            )
            .map((item) => {'relationship_id': item['id']})
            .toList();
      case 'multiplicity_known':
        return relationships
            .where(
              (item) =>
                  '${_map(item['properties'])['multiplicity'] ?? ''}'.isEmpty,
            )
            .map((item) => {'relationship_id': item['id']})
            .toList();
      case 'class_attributes_typed':
        final violations = <Map<String, dynamic>>[];
        for (final element in elements.where(
          (e) => e['metaclass'] == 'Class',
        )) {
          final attributes = _map(element['properties'])['attributes'];
          if (attributes is! List) continue;
          for (final attribute in attributes) {
            final text = '$attribute';
            if (!text.contains(':') || text.split(':').last.trim().isEmpty) {
              violations.add({'entity_id': element['id'], 'attribute': text});
            }
          }
        }
        return violations;
      case 'spring_identifier':
        return elements
            .where((item) => item['metaclass'] == 'Class')
            .where((item) {
              final attributes = _map(item['properties'])['attributes'];
              return attributes is! List ||
                  !attributes.any(
                    (a) => RegExp(
                      r'\b(id|uuid)\b',
                      caseSensitive: false,
                    ).hasMatch('$a'),
                  );
            })
            .map((item) => {'entity_id': item['id'], 'name': item['name']})
            .toList();
      case 'spring_supported_type':
        const supported = {
          'string',
          'uuid',
          'int',
          'integer',
          'long',
          'double',
          'decimal',
          'boolean',
          'date',
          'datetime',
          'instant',
        };
        final violations = <Map<String, dynamic>>[];
        for (final element in elements.where(
          (e) => e['metaclass'] == 'Class',
        )) {
          final attributes = _map(element['properties'])['attributes'];
          if (attributes is! List) continue;
          for (final attribute in attributes) {
            final text = '$attribute';
            if (!text.contains(':')) continue;
            final type = text.split(':').last.trim();
            if (type.isNotEmpty && !supported.contains(type.toLowerCase())) {
              violations.add({
                'entity_id': element['id'],
                'attribute': text,
                'type': type,
              });
            }
          }
        }
        return violations;
      case 'mda_level_known':
        final level = _map(context['project'])['mda_level'];
        return level == null ||
                {'', 'unspecified'}.contains('$level'.toLowerCase())
            ? [
                const {'field': 'project.mda_level'},
              ]
            : const [];
      case 'write_permission':
        return '${context['permission']}' == 'viewer'
            ? [
                const {'permission': 'viewer'},
              ]
            : const [];
      case 'operation_limit':
        final operations = context['operations'];
        final limit = (condition['maximum'] as num?)?.toInt() ?? 200;
        return operations is List && operations.length > limit
            ? [
                {'count': operations.length, 'maximum': limit},
              ]
            : const [];
      default:
        return const [];
    }
  }
}

String canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : const {};
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(_map).toList(growable: false)
    : const [];
List<String> _strings(Object? value) => value is List
    ? value.map((item) => '$item').toList(growable: false)
    : const [];
