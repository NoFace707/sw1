export const DEFAULT_CLASS_ATTRIBUTE = "+ atributo: Tipo";

export function normalizeClassAttributes(attributes) {
  if (!Array.isArray(attributes)) return [];
  return attributes.filter((item) => typeof item === "string").map((item) => item.trim()).filter(Boolean);
}

export function addClassAttribute(attributes) {
  return [...normalizeClassAttributes(attributes), DEFAULT_CLASS_ATTRIBUTE];
}

export function commitClassAttribute(attributes, index, value) {
  const next = Array.isArray(attributes) ? [...attributes] : [];
  const normalized = typeof value === "string" ? value.trim() : "";
  if (!normalized) next.splice(index, 1);
  else next[index] = normalized;
  return normalizeClassAttributes(next);
}

export function removeClassAttribute(attributes, index) {
  return normalizeClassAttributes(attributes).filter((_, itemIndex) => itemIndex !== index);
}

export function requiredClassHeight(currentHeight, attributeCount, operationCount = 0) {
  return Math.max(Number(currentHeight) || 110, 72 + (attributeCount * 22) + (operationCount * 18));
}
