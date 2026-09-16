export function selectedItems(items) {
  return items.filter((item) => item.selected);
}

export function copyPosition(position, offset = 32) {
  return { x: Number(position?.x || 0) + offset, y: Number(position?.y || 0) + offset };
}

export function isTextEditingTarget(target) {
  return Boolean(target?.closest?.("input, textarea, select, [contenteditable=\"true\"]"));
}

export function cloneNodeForCopy(node, id, position) {
  return { ...node, id, position: position || copyPosition(node.position), selected: false, data: { ...node.data } };
}
