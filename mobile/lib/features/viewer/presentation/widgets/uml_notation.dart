import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/viewer_models.dart';

const supportedDiagramTypes = <String>{
  'class',
  'object',
  'component',
  'composite_structure',
  'package',
  'deployment',
  'profile',
  'use_case',
  'activity',
  'state_machine',
  'sequence',
  'communication',
  'interaction_overview',
  'timing',
};

const _knownMetaclasses = <String>{
  'Class',
  'Object',
  'Package',
  'Actor',
  'UseCase',
  'Component',
  'Interface',
  'Node',
  'Artifact',
  'Port',
  'Profile',
  'Stereotype',
  'Activity',
  'Action',
  'DecisionNode',
  'MergeNode',
  'InitialNode',
  'ActivityFinalNode',
  'State',
  'FinalState',
  'Pseudostate',
  'Region',
  'Lifeline',
  'Interaction',
  'CombinedFragment',
  'TimeObservation',
};

const supportedVisualShapes = <String, Set<String>>{
  'general': {
    'text',
    'rectangle',
    'rounded-rectangle',
    'ellipse',
    'circle',
    'diamond',
    'triangle',
    'parallelogram',
    'hexagon',
    'cylinder',
    'document',
    'note',
    'cloud',
    'callout',
  },
  'flowchart': {
    'process',
    'terminator',
    'decision',
    'data',
    'database',
    'flow-document',
    'manual-input',
    'preparation',
    'delay',
    'connector',
    'off-page-connector',
    'subprocess',
  },
  'er': {
    'entity',
    'weak-entity',
    'attribute',
    'key-attribute',
    'multivalued-attribute',
    'derived-attribute',
    'relationship',
    'identifying-relationship',
  },
};

bool isSupportedVisualNode(UmlDiagramNode node) {
  if (!node.isVisual) return false;
  final library = node.properties['library']?.toString();
  final shape = node.properties['shape']?.toString();
  return supportedVisualShapes[library]?.contains(shape) ?? false;
}

class UmlNodeView extends StatelessWidget {
  const UmlNodeView({
    super.key,
    required this.node,
    required this.element,
    required this.diagramType,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final UmlDiagramNode node;
  final UmlElement? element;
  final String diagramType;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  bool get _unknown {
    if (!supportedDiagramTypes.contains(diagramType)) return true;
    if (node.isVisual) return !isSupportedVisualNode(node);
    return element == null || !_knownMetaclasses.contains(element!.metaclass);
  }

  @override
  Widget build(BuildContext context) {
    final label =
        element?.name ?? '${node.properties['label'] ?? 'Elemento visual'}';
    final metaclass =
        element?.metaclass ?? '${node.properties['shape'] ?? 'Visual'}';
    final details = _detailLines(element);
    final visualStyle = node.properties['style'] is Map
        ? Map<String, dynamic>.from(node.properties['style'] as Map)
        : const <String, dynamic>{};
    final visualTextColor = _colorFromHex(
      visualStyle['textColor'],
      const Color(0xFF0F172A),
    );
    final visualFontSize = (visualStyle['fontSize'] as num?)?.toDouble() ?? 14;
    return Semantics(
      button: true,
      label: '$metaclass $label. Solo lectura.',
      hint:
          'Toca para inspeccionar. Mantén pulsado para solicitar un cambio con IA.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: CustomPaint(
          painter: UmlNodePainter(
            metaclass: metaclass,
            diagramType: diagramType,
            properties: element?.properties ?? node.properties,
            visual: node.isVisual,
            unknown: _unknown,
            selected: selected,
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_unknown)
                  const Icon(
                    Icons.extension_off_outlined,
                    size: 18,
                    color: Color(0xFFB45309),
                  ),
                if (metaclass == 'Stereotype' || metaclass == 'Profile')
                  Text(
                    '«$metaclass»',
                    style: const TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: node.isVisual ? visualTextColor : null,
                      fontSize: node.isVisual ? visualFontSize : 12,
                      fontWeight: FontWeight.w700,
                      decoration:
                          node.isVisual &&
                              node.properties['shape'] == 'key-attribute'
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                ),
                if (details.isNotEmpty && node.bounds.height >= 64)
                  Text(
                    details.take(3).join('\n'),
                    textAlign: TextAlign.left,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, height: 1.2),
                  ),
                if (_unknown)
                  const Text(
                    'Notación no compatible',
                    style: TextStyle(fontSize: 8, color: Color(0xFF92400E)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Iterable<String> _detailLines(UmlElement? element) sync* {
  if (element == null) return;
  for (final key in const [
    'attributes',
    'operations',
    'slots',
    'guard',
    'entry',
    'do',
    'exit',
    'time_expression',
  ]) {
    final value = element.properties[key];
    if (value is List) {
      for (final item in value) {
        yield '$item';
      }
    } else if (value != null && '$value'.trim().isNotEmpty) {
      yield key == 'guard' ? '[$value]' : '$key: $value';
    }
  }
}

class UmlNodePainter extends CustomPainter {
  UmlNodePainter({
    required this.metaclass,
    required this.diagramType,
    required this.properties,
    required this.visual,
    required this.unknown,
    required this.selected,
    required this.colorScheme,
  });

  final String metaclass;
  final String diagramType;
  final Map<String, dynamic> properties;
  final bool visual;
  final bool unknown;
  final bool selected;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final style = properties['style'] is Map
        ? Map<String, dynamic>.from(properties['style'] as Map)
        : const <String, dynamic>{};
    final fill = Paint()
      ..color = unknown
          ? const Color(0xFFFFF7ED)
          : _colorFromHex(style['fill'], colorScheme.surface);
    final stroke = Paint()
      ..color = selected
          ? colorScheme.primary
          : (unknown
                ? const Color(0xFFF59E0B)
                : _colorFromHex(style['stroke'], const Color(0xFF475569)))
      ..strokeWidth = selected
          ? 3
          : ((style['strokeWidth'] as num?)?.toDouble() ?? 1.5)
      ..style = PaintingStyle.stroke;
    final rect = Offset.zero & size;
    final rounded = RRect.fromRectAndRadius(
      rect.deflate(1.5),
      const Radius.circular(8),
    );

    if (visual && properties['shape'] != 'text') {
      _visualShape(
        canvas,
        size,
        '${properties['shape'] ?? ''}',
        fill,
        stroke,
        dashed: style['dashed'] == true,
      );
      return;
    }
    if (visual) return;

    switch (metaclass) {
      case 'Actor':
        _actor(canvas, size, stroke);
      case 'UseCase':
        canvas.drawOval(rect.deflate(2), fill);
        canvas.drawOval(rect.deflate(2), stroke);
      case 'Package':
        final body = Path()
          ..moveTo(2, 18)
          ..lineTo(2, 2)
          ..lineTo(size.width * .42, 2)
          ..lineTo(size.width * .52, 18)
          ..lineTo(size.width - 2, 18)
          ..lineTo(size.width - 2, size.height - 2)
          ..lineTo(2, size.height - 2)
          ..close();
        canvas.drawPath(body, fill);
        canvas.drawPath(body, stroke);
      case 'DecisionNode' || 'MergeNode':
        final diamond = Path()
          ..moveTo(size.width / 2, 2)
          ..lineTo(size.width - 2, size.height / 2)
          ..lineTo(size.width / 2, size.height - 2)
          ..lineTo(2, size.height / 2)
          ..close();
        canvas.drawPath(diamond, fill);
        canvas.drawPath(diamond, stroke);
      case 'InitialNode':
        canvas.drawCircle(
          size.center(Offset.zero),
          math.min(size.width, size.height) / 2 - 3,
          Paint()..color = const Color(0xFF1E293B),
        );
      case 'ActivityFinalNode' || 'FinalState':
        final radius = math.min(size.width, size.height) / 2 - 3;
        canvas.drawCircle(size.center(Offset.zero), radius, stroke);
        canvas.drawCircle(
          size.center(Offset.zero),
          radius * .56,
          Paint()..color = const Color(0xFF1E293B),
        );
      case 'Component':
        canvas.drawRRect(rounded, fill);
        canvas.drawRRect(rounded, stroke);
        final icon = Rect.fromLTWH(size.width - 26, 8, 17, 15);
        canvas.drawRect(icon, stroke);
        canvas.drawRect(Rect.fromLTWH(icon.left - 5, icon.top + 2, 7, 4), fill);
        canvas.drawRect(
          Rect.fromLTWH(icon.left - 5, icon.top + 2, 7, 4),
          stroke,
        );
        canvas.drawRect(
          Rect.fromLTWH(icon.left - 5, icon.bottom - 6, 7, 4),
          fill,
        );
        canvas.drawRect(
          Rect.fromLTWH(icon.left - 5, icon.bottom - 6, 7, 4),
          stroke,
        );
      case 'Node':
        final cube = Path()
          ..moveTo(2, 12)
          ..lineTo(12, 2)
          ..lineTo(size.width - 2, 2)
          ..lineTo(size.width - 2, size.height - 12)
          ..lineTo(size.width - 12, size.height - 2)
          ..lineTo(2, size.height - 2)
          ..close();
        canvas.drawPath(cube, fill);
        canvas.drawPath(cube, stroke);
        canvas.drawLine(
          const Offset(2, 12),
          Offset(size.width - 12, 12),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width - 12, 12),
          Offset(size.width - 2, 2),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width - 12, 12),
          Offset(size.width - 12, size.height - 2),
          stroke,
        );
      case 'Lifeline':
        canvas.drawRect(
          Rect.fromLTWH(2, 2, size.width - 4, math.min(36, size.height * .35)),
          fill,
        );
        canvas.drawRect(
          Rect.fromLTWH(2, 2, size.width - 4, math.min(36, size.height * .35)),
          stroke,
        );
        _dashedLine(
          canvas,
          Offset(size.width / 2, math.min(38, size.height * .36)),
          Offset(size.width / 2, size.height - 2),
          stroke,
        );
      case 'TimeObservation':
        canvas.drawRRect(rounded, fill);
        canvas.drawRRect(rounded, stroke);
        final wave = Path()
          ..moveTo(8, size.height - 16)
          ..lineTo(size.width * .35, size.height - 16)
          ..lineTo(size.width * .35, size.height - 28)
          ..lineTo(size.width * .68, size.height - 28)
          ..lineTo(size.width * .68, size.height - 16)
          ..lineTo(size.width - 8, size.height - 16);
        canvas.drawPath(wave, stroke);
      case 'Port':
        canvas.drawRect(rect.deflate(2), fill);
        canvas.drawRect(rect.deflate(2), stroke);
      case 'Interface':
        canvas.drawCircle(
          size.center(Offset.zero),
          math.min(size.width, size.height) / 2 - 3,
          fill,
        );
        canvas.drawCircle(
          size.center(Offset.zero),
          math.min(size.width, size.height) / 2 - 3,
          stroke,
        );
      default:
        canvas.drawRRect(rounded, fill);
        canvas.drawRRect(rounded, stroke);
        if ({
          'Class',
          'Object',
          'Artifact',
          'State',
          'Region',
          'CombinedFragment',
        }.contains(metaclass)) {
          canvas.drawLine(
            Offset(2, math.min(30, size.height * .38)),
            Offset(size.width - 2, math.min(30, size.height * .38)),
            stroke,
          );
        }
        if (metaclass == 'Object') {
          canvas.drawLine(
            Offset(size.width * .25, 22),
            Offset(size.width * .75, 22),
            stroke,
          );
        }
    }
  }

  void _visualShape(
    Canvas canvas,
    Size size,
    String shape,
    Paint fill,
    Paint stroke, {
    required bool dashed,
  }) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 100);
    final visualStroke = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(3, 3, 174, 94);

    void drawPath(
      Path path, {
      bool onlyStroke = false,
      bool forceDashed = false,
    }) {
      if (!onlyStroke) canvas.drawPath(path, fill);
      if (dashed || forceDashed) {
        _drawDashedPath(canvas, path, visualStroke);
      } else {
        canvas.drawPath(path, visualStroke);
      }
    }

    Path polygon(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      return path..close();
    }

    switch (shape) {
      case 'ellipse' || 'attribute' || 'key-attribute':
        canvas.drawOval(const Rect.fromLTWH(4, 4, 172, 92), fill);
        canvas.drawOval(const Rect.fromLTWH(4, 4, 172, 92), visualStroke);
      case 'circle' || 'connector':
        canvas.drawOval(const Rect.fromLTWH(5, 3, 170, 94), fill);
        canvas.drawOval(const Rect.fromLTWH(5, 3, 170, 94), visualStroke);
      case 'multivalued-attribute':
        canvas.drawOval(const Rect.fromLTWH(4, 4, 172, 92), fill);
        canvas.drawOval(const Rect.fromLTWH(4, 4, 172, 92), visualStroke);
        canvas.drawOval(const Rect.fromLTWH(11, 11, 158, 78), visualStroke);
      case 'derived-attribute':
        final path = Path()..addOval(const Rect.fromLTWH(4, 4, 172, 92));
        canvas.drawPath(path, fill);
        _drawDashedPath(canvas, path, visualStroke);
      case 'diamond' || 'decision' || 'relationship':
        drawPath(
          polygon(const [
            Offset(90, 3),
            Offset(177, 50),
            Offset(90, 97),
            Offset(3, 50),
          ]),
        );
      case 'identifying-relationship':
        drawPath(
          polygon(const [
            Offset(90, 3),
            Offset(177, 50),
            Offset(90, 97),
            Offset(3, 50),
          ]),
        );
        drawPath(
          polygon(const [
            Offset(90, 11),
            Offset(164, 50),
            Offset(90, 89),
            Offset(16, 50),
          ]),
          onlyStroke: true,
        );
      case 'triangle':
        drawPath(
          polygon(const [Offset(90, 3), Offset(177, 97), Offset(3, 97)]),
        );
      case 'parallelogram' || 'data':
        drawPath(
          polygon(const [
            Offset(24, 3),
            Offset(177, 3),
            Offset(156, 97),
            Offset(3, 97),
          ]),
        );
      case 'hexagon' || 'preparation':
        drawPath(
          polygon(const [
            Offset(28, 3),
            Offset(152, 3),
            Offset(177, 50),
            Offset(152, 97),
            Offset(28, 97),
            Offset(3, 50),
          ]),
        );
      case 'cylinder' || 'database':
        final body = Path()
          ..moveTo(4, 16)
          ..cubicTo(4, 0, 176, 0, 176, 16)
          ..lineTo(176, 84)
          ..cubicTo(176, 100, 4, 100, 4, 84)
          ..close();
        drawPath(body);
        canvas.drawOval(const Rect.fromLTWH(4, 3, 172, 26), fill);
        canvas.drawOval(const Rect.fromLTWH(4, 3, 172, 26), visualStroke);
        canvas.drawPath(
          Path()
            ..moveTo(4, 84)
            ..cubicTo(4, 68, 176, 68, 176, 84),
          visualStroke,
        );
      case 'document' || 'flow-document':
        drawPath(
          Path()
            ..moveTo(3, 3)
            ..lineTo(177, 3)
            ..lineTo(177, 80)
            ..cubicTo(145, 105, 120, 68, 90, 88)
            ..cubicTo(60, 108, 35, 70, 3, 90)
            ..close(),
        );
      case 'note':
        drawPath(
          Path()
            ..moveTo(3, 3)
            ..lineTo(145, 3)
            ..lineTo(177, 35)
            ..lineTo(177, 97)
            ..lineTo(3, 97)
            ..close(),
        );
        canvas.drawPath(
          Path()
            ..moveTo(145, 3)
            ..lineTo(145, 35)
            ..lineTo(177, 35),
          visualStroke,
        );
      case 'cloud':
        drawPath(
          Path()
            ..moveTo(37, 82)
            ..cubicTo(8, 82, 3, 59, 20, 45)
            ..cubicTo(13, 22, 43, 10, 61, 24)
            ..cubicTo(75, 2, 115, 5, 124, 29)
            ..cubicTo(157, 20, 176, 40, 167, 62)
            ..cubicTo(177, 83, 145, 95, 126, 83)
            ..close(),
        );
      case 'callout':
        drawPath(
          polygon(const [
            Offset(3, 3),
            Offset(177, 3),
            Offset(177, 78),
            Offset(65, 78),
            Offset(38, 98),
            Offset(45, 78),
            Offset(3, 78),
          ]),
        );
      case 'rounded-rectangle' || 'terminator':
        final radius = shape == 'terminator' ? 47.0 : 16.0;
        final rounded = RRect.fromRectAndRadius(rect, Radius.circular(radius));
        canvas.drawRRect(rounded, fill);
        canvas.drawRRect(rounded, visualStroke);
      case 'manual-input':
        drawPath(
          polygon(const [
            Offset(3, 22),
            Offset(177, 3),
            Offset(177, 97),
            Offset(3, 97),
          ]),
        );
      case 'delay':
        drawPath(
          Path()
            ..moveTo(3, 3)
            ..lineTo(125, 3)
            ..cubicTo(193, 3, 193, 97, 125, 97)
            ..lineTo(3, 97)
            ..close(),
        );
      case 'off-page-connector':
        drawPath(
          polygon(const [
            Offset(3, 3),
            Offset(177, 3),
            Offset(177, 70),
            Offset(90, 97),
            Offset(3, 70),
          ]),
        );
      case 'subprocess':
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, visualStroke);
        canvas.drawLine(
          const Offset(18, 3),
          const Offset(18, 97),
          visualStroke,
        );
        canvas.drawLine(
          const Offset(162, 3),
          const Offset(162, 97),
          visualStroke,
        );
      case 'weak-entity':
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, visualStroke);
        canvas.drawRect(const Rect.fromLTWH(10, 10, 160, 80), visualStroke);
      default:
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, visualStroke);
    }
    canvas.restore();
  }

  void _actor(Canvas canvas, Size size, Paint stroke) {
    final center = Offset(size.width / 2, size.height * .22);
    final radius = math.min(size.width, size.height) * .13;
    canvas.drawCircle(center, radius, stroke);
    final neck = Offset(center.dx, center.dy + radius);
    final hips = Offset(center.dx, size.height * .63);
    canvas.drawLine(neck, hips, stroke);
    canvas.drawLine(
      Offset(size.width * .2, size.height * .43),
      Offset(size.width * .8, size.height * .43),
      stroke,
    );
    canvas.drawLine(hips, Offset(size.width * .24, size.height - 2), stroke);
    canvas.drawLine(hips, Offset(size.width * .76, size.height - 2), stroke);
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    for (var y = from.dy; y < to.dy; y += 9) {
      canvas.drawLine(
        Offset(from.dx, y),
        Offset(from.dx, math.min(y + 5, to.dy)),
        paint,
      );
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 7, metric.length)),
          paint,
        );
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant UmlNodePainter oldDelegate) =>
      oldDelegate.metaclass != metaclass ||
      oldDelegate.visual != visual ||
      oldDelegate.selected != selected ||
      oldDelegate.unknown != unknown ||
      oldDelegate.properties != properties;
}

Color _colorFromHex(dynamic value, Color fallback) {
  final raw = value?.toString().replaceFirst('#', '');
  if (raw == null || (raw.length != 6 && raw.length != 8)) return fallback;
  final parsed = int.tryParse(raw, radix: 16);
  if (parsed == null) return fallback;
  return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
}

class UmlEdgesPainter extends CustomPainter {
  UmlEdgesPainter({
    required this.nodes,
    required this.edges,
    required this.relationships,
    this.origin = Offset.zero,
  });

  final List<UmlDiagramNode> nodes;
  final List<UmlDiagramEdge> edges;
  final List<UmlRelationship> relationships;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final node in nodes) node.id: node};
    final relations = {
      for (final relation in relationships) relation.id: relation,
    };
    for (final edge in edges) {
      final source = byId[edge.sourceNodeId];
      final target = byId[edge.targetNodeId];
      if (source == null || target == null) continue;
      final relation = relations[edge.relationshipId];
      final presentation = edge.properties['presentation'] is Map
          ? Map<String, dynamic>.from(edge.properties['presentation'] as Map)
          : edge.properties;
      final style = presentation['style'] is Map
          ? Map<String, dynamic>.from(presentation['style'] as Map)
          : const <String, dynamic>{};
      final paint = Paint()
        ..color = const Color(0xFF475569)
        ..strokeWidth = (style['strokeWidth'] as num?)?.toDouble() ?? 1.5
        ..style = PaintingStyle.stroke;
      final start = source.bounds.center - origin;
      final end = target.bounds.center - origin;
      final route = Path()..moveTo(start.dx, start.dy);
      if (style['routing'] == 'orthogonal') {
        route.lineTo(start.dx, end.dy);
      } else if (style['routing'] == 'curved') {
        route.quadraticBezierTo(
          (start.dx + end.dx) / 2,
          start.dy - 50,
          end.dx,
          end.dy,
        );
      }
      route.lineTo(end.dx, end.dy);
      if (style['lineStyle'] == 'dashed' || relation?.type == 'Dependency') {
        _drawDashedPath(canvas, route, paint);
      } else {
        canvas.drawPath(route, paint);
      }
      _arrow(
        canvas,
        start,
        end,
        paint,
        relation?.type ?? '${presentation['shape'] ?? ''}',
      );
      final label =
          '${presentation['label'] ?? relation?.properties['label'] ?? relation?.type ?? ''}'
              .trim();
      if (label.isNotEmpty) {
        final paragraph = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 10,
              backgroundColor: Color(0xE6FFFFFF),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 160);
        paragraph.paint(
          canvas,
          Offset(
            (start.dx + end.dx) / 2 - paragraph.width / 2,
            (start.dy + end.dy) / 2 - paragraph.height,
          ),
        );
      }
    }
  }

  void _arrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    String type,
  ) {
    if (type.isEmpty || type == 'Association') return;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const length = 11.0;
    final left =
        end -
        Offset(math.cos(angle - .55) * length, math.sin(angle - .55) * length);
    final right =
        end -
        Offset(math.cos(angle + .55) * length, math.sin(angle + .55) * length);
    final path = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(right.dx, right.dy);
    canvas.drawPath(path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 7, metric.length)),
          paint,
        );
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant UmlEdgesPainter oldDelegate) =>
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges ||
      oldDelegate.relationships != relationships ||
      oldDelegate.origin != origin;
}

class UmlMiniMapPainter extends CustomPainter {
  UmlMiniMapPainter({
    required this.bounds,
    required this.nodes,
    required this.selectedNodeId,
  });
  final Rect bounds;
  final List<UmlDiagramNode> nodes;
  final String? selectedNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xE6FFFFFF),
    );
    canvas.drawRect(
      (Offset.zero & size).deflate(1),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke,
    );
    final scale = math.min(
      size.width / math.max(bounds.width, 1),
      size.height / math.max(bounds.height, 1),
    );
    for (final node in nodes) {
      final mini = Rect.fromLTWH(
        (node.bounds.left - bounds.left) * scale,
        (node.bounds.top - bounds.top) * scale,
        math.max(3, node.bounds.width * scale),
        math.max(3, node.bounds.height * scale),
      );
      canvas.drawRect(
        mini,
        Paint()
          ..color = node.id == selectedNodeId
              ? const Color(0xFF0F766E)
              : const Color(0xFFCBD5E1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant UmlMiniMapPainter oldDelegate) =>
      oldDelegate.nodes != nodes ||
      oldDelegate.selectedNodeId != selectedNodeId ||
      oldDelegate.bounds != bounds;
}
