export function buildOfflineResolutionOperation(conflict, revision) {
  return {
    operation_id: crypto.randomUUID(),
    entity_type: conflict.entityType,
    entity_id: conflict.entityId,
    action: "resolve",
    path: conflict.path || "",
    base_revision: Number(revision || 0),
    previous_value: null,
    new_value: conflict.rejectedValue,
  };
}
