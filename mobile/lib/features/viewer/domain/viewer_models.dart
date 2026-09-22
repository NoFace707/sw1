import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ProjectAccess { owner, editor, viewer }

enum ViewerSyncState { updated, offline, syncing, pending, conflict }

ProjectAccess projectAccessFromJson(Object? value) => switch (value) {
  'owner' => ProjectAccess.owner,
  'editor' => ProjectAccess.editor,
  _ => ProjectAccess.viewer,
};

ViewerSyncState viewerSyncStateFromJson(Object? value) => switch (value) {
  'offline' => ViewerSyncState.offline,
  'syncing' => ViewerSyncState.syncing,
  'pending' => ViewerSyncState.pending,
  'conflict' => ViewerSyncState.conflict,
  _ => ViewerSyncState.updated,
};

class UmlProjectSummary {
  const UmlProjectSummary({
    required this.id,
    required this.name,
    required this.access,
    required this.updatedAt,
    required this.revision,
    this.syncState = ViewerSyncState.updated,
    this.availableOffline = false,
  });

  final String id;
  final String name;
  final ProjectAccess access;
  final DateTime? updatedAt;
  final int revision;
  final ViewerSyncState syncState;
  final bool availableOffline;

  factory UmlProjectSummary.fromJson(Map<String, dynamic> json) {
    return UmlProjectSummary(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Proyecto sin nombre'}',
      access: projectAccessFromJson(
        json['membership_role'] ?? json['permission'],
      ),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
      revision: _integer(json['revision']),
      syncState: viewerSyncStateFromJson(
        json['sync_state'] ?? json['local_state'],
      ),
      availableOffline: json['available_offline'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'membership_role': access.name,
    'updated_at': updatedAt?.toIso8601String(),
    'revision': revision,
    'sync_state': syncState.name,
    'available_offline': availableOffline,
  };

  UmlProjectSummary copyWith({
    ViewerSyncState? syncState,
    bool? availableOffline,
    int? revision,
  }) {
    return UmlProjectSummary(
      id: id,
      name: name,
      access: access,
      updatedAt: updatedAt,
      revision: revision ?? this.revision,
      syncState: syncState ?? this.syncState,
      availableOffline: availableOffline ?? this.availableOffline,
    );
  }
}

class UmlDiagram {
  const UmlDiagram({
    required this.id,
    required this.name,
    required this.type,
    this.properties = const {},
  });

  final String id;
  final String name;
  final String type;
  final Map<String, dynamic> properties;

  factory UmlDiagram.fromJson(Map<String, dynamic> json) => UmlDiagram(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? 'Diagrama'}',
    type: '${json['diagram_type'] ?? json['type'] ?? 'unknown'}',
    properties: _map(json['properties']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'diagram_type': type,
    'properties': properties,
  };
}

class UmlElement {
  const UmlElement({
    required this.id,
    required this.name,
    required this.metaclass,
    this.mdaLevel,
    this.properties = const {},
  });

  final String id;
  final String name;
  final String metaclass;
  final String? mdaLevel;
  final Map<String, dynamic> properties;

  factory UmlElement.fromJson(Map<String, dynamic> json) {
    final properties = _map(json['properties']);
    return UmlElement(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? properties['label'] ?? 'Elemento'}',
      metaclass: '${json['metaclass'] ?? properties['metaclass'] ?? 'Unknown'}',
      mdaLevel: (json['mda_level'] ?? properties['mda_level'])?.toString(),
      properties: properties,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'metaclass': metaclass,
    if (mdaLevel != null) 'mda_level': mdaLevel,
    'properties': properties,
  };
}

class UmlRelationship {
  const UmlRelationship({
    required this.id,
    required this.type,
    required this.sourceId,
    required this.targetId,
    this.properties = const {},
  });

  final String id;
  final String type;
  final String sourceId;
  final String targetId;
  final Map<String, dynamic> properties;

  factory UmlRelationship.fromJson(Map<String, dynamic> json) =>
      UmlRelationship(
        id: '${json['id'] ?? ''}',
        type: '${json['relationship_type'] ?? json['type'] ?? 'unknown'}',
        sourceId: '${json['source'] ?? json['source_id'] ?? ''}',
        targetId: '${json['target'] ?? json['target_id'] ?? ''}',
        properties: _map(json['properties']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'relationship_type': type,
    'source': sourceId,
    'target': targetId,
    'properties': properties,
  };
}

class UmlDiagramNode {
  const UmlDiagramNode({
    required this.id,
    required this.diagramId,
    required this.elementId,
    required this.bounds,
    this.properties = const {},
  });

  final String id;
  final String diagramId;
  final String? elementId;
  final Rect bounds;
  final Map<String, dynamic> properties;

  bool get isVisual => properties['kind'] == 'visual';

  factory UmlDiagramNode.fromJson(Map<String, dynamic> json) => UmlDiagramNode(
    id: '${json['id'] ?? ''}',
    diagramId: '${json['diagram'] ?? json['diagram_id'] ?? ''}',
    elementId: (json['element'] ?? json['element_id'])?.toString(),
    bounds: Rect.fromLTWH(
      _number(json['x']),
      _number(json['y']),
      math.max(24, _number(json['width'], 180)),
      math.max(24, _number(json['height'], 80)),
    ),
    properties: _map(json['properties']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'diagram': diagramId,
    'element': elementId,
    'x': bounds.left,
    'y': bounds.top,
    'width': bounds.width,
    'height': bounds.height,
    'properties': properties,
  };
}

class UmlDiagramEdge {
  const UmlDiagramEdge({
    required this.id,
    required this.diagramId,
    required this.sourceNodeId,
    required this.targetNodeId,
    this.relationshipId,
    this.properties = const {},
  });

  final String id;
  final String diagramId;
  final String sourceNodeId;
  final String targetNodeId;
  final String? relationshipId;
  final Map<String, dynamic> properties;

  factory UmlDiagramEdge.fromJson(Map<String, dynamic> json) => UmlDiagramEdge(
    id: '${json['id'] ?? ''}',
    diagramId: '${json['diagram'] ?? json['diagram_id'] ?? ''}',
    sourceNodeId: '${json['source_node'] ?? json['source_node_id'] ?? ''}',
    targetNodeId: '${json['target_node'] ?? json['target_node_id'] ?? ''}',
    relationshipId: (json['relationship'] ?? json['relationship_id'])
        ?.toString(),
    properties: _map(json['properties']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'diagram': diagramId,
    'source_node': sourceNodeId,
    'target_node': targetNodeId,
    'relationship': relationshipId,
    'properties': properties,
  };
}

class UmlSnapshot {
  const UmlSnapshot({
    required this.project,
    required this.diagrams,
    required this.elements,
    required this.relationships,
    required this.nodes,
    required this.edges,
    required this.loadedFromOffline,
    this.syncedAt,
  });

  final UmlProjectSummary project;
  final List<UmlDiagram> diagrams;
  final List<UmlElement> elements;
  final List<UmlRelationship> relationships;
  final List<UmlDiagramNode> nodes;
  final List<UmlDiagramEdge> edges;
  final bool loadedFromOffline;
  final DateTime? syncedAt;

  factory UmlSnapshot.fromJson(
    Map<String, dynamic> json, {
    UmlProjectSummary? fallbackProject,
    bool loadedFromOffline = false,
  }) {
    final payload = _map(json['payload']).isNotEmpty
        ? _map(json['payload'])
        : json;
    final projectJson = _map(payload['project']).isNotEmpty
        ? _map(payload['project'])
        : fallbackProject?.toJson() ?? const <String, dynamic>{};
    final storedSyncState = viewerSyncStateFromJson(
      '${projectJson['sync_state'] ?? fallbackProject?.syncState.name ?? 'updated'}',
    );
    final visibleSyncState = loadedFromOffline
        ? switch (storedSyncState) {
            ViewerSyncState.pending ||
            ViewerSyncState.conflict => storedSyncState,
            _ => ViewerSyncState.offline,
          }
        : fallbackProject?.syncState ?? storedSyncState;
    final project = UmlProjectSummary.fromJson({
      ...projectJson,
      if (fallbackProject != null) ...fallbackProject.toJson(),
      if (json['revision'] != null) 'revision': json['revision'],
      'sync_state': visibleSyncState.name,
      'available_offline':
          loadedFromOffline || fallbackProject?.availableOffline == true,
    });
    return UmlSnapshot(
      project: project,
      diagrams: _maps(
        payload['diagrams'],
      ).map(UmlDiagram.fromJson).toList(growable: false),
      elements: _maps(
        payload['elements'],
      ).map(UmlElement.fromJson).toList(growable: false),
      relationships: _maps(
        payload['relationships'],
      ).map(UmlRelationship.fromJson).toList(growable: false),
      nodes: _maps(
        payload['diagram_nodes'] ?? payload['diagramNodes'],
      ).map(UmlDiagramNode.fromJson).toList(growable: false),
      edges: _maps(
        payload['diagram_edges'] ?? payload['diagramEdges'],
      ).map(UmlDiagramEdge.fromJson).toList(growable: false),
      loadedFromOffline: loadedFromOffline,
      syncedAt: DateTime.tryParse(
        '${json['synced_at'] ?? json['created_at'] ?? ''}',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'project': project.toJson(),
    'revision': project.revision,
    'synced_at': (syncedAt ?? DateTime.now()).toIso8601String(),
    'payload': {
      'project': project.toJson(),
      'diagrams': diagrams.map((item) => item.toJson()).toList(),
      'elements': elements.map((item) => item.toJson()).toList(),
      'relationships': relationships.map((item) => item.toJson()).toList(),
      'diagram_nodes': nodes.map((item) => item.toJson()).toList(),
      'diagram_edges': edges.map((item) => item.toJson()).toList(),
    },
  };

  UmlElement? elementById(String? id) => id == null
      ? null
      : elements.cast<UmlElement?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );

  UmlDiagram? diagramById(String? id) => id == null
      ? null
      : diagrams.cast<UmlDiagram?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );

  List<UmlDiagramNode> nodesFor(String diagramId) => nodes
      .where((node) => node.diagramId == diagramId)
      .toList(growable: false);

  List<UmlDiagramEdge> edgesFor(String diagramId) => edges
      .where((edge) => edge.diagramId == diagramId)
      .toList(growable: false);

  Rect boundsFor(String diagramId) {
    final diagramNodes = nodesFor(diagramId);
    if (diagramNodes.isEmpty) return const Rect.fromLTWH(0, 0, 800, 600);
    var bounds = diagramNodes.first.bounds;
    for (final node in diagramNodes.skip(1)) {
      bounds = bounds.expandToInclude(node.bounds);
    }
    return bounds.inflate(80);
  }
}

class ViewerSearchResult {
  const ViewerSearchResult({
    required this.element,
    required this.diagram,
    required this.node,
  });
  final UmlElement element;
  final UmlDiagram diagram;
  final UmlDiagramNode node;
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList()
    : const [];

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : const <String, dynamic>{};

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _number(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
