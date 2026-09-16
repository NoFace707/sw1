function Geometry({ shape, fill, stroke, strokeWidth, dashed = false }) {
  const common = { fill, stroke, strokeWidth, strokeDasharray: dashed ? "7 5" : undefined, vectorEffect: "non-scaling-stroke" };
  switch (shape) {
    case "ellipse": case "attribute": case "key-attribute": return <ellipse cx="90" cy="50" rx="86" ry="46" {...common} />;
    case "circle": case "connector": return <ellipse cx="90" cy="50" rx="85" ry="47" {...common} />;
    case "multivalued-attribute": return <><ellipse cx="90" cy="50" rx="86" ry="46" {...common} /><ellipse cx="90" cy="50" rx="79" ry="39" fill="none" stroke={stroke} strokeWidth={strokeWidth} vectorEffect="non-scaling-stroke" /></>;
    case "derived-attribute": return <ellipse cx="90" cy="50" rx="86" ry="46" {...common} strokeDasharray="7 5" />;
    case "diamond": case "decision": case "relationship": return <polygon points="90,3 177,50 90,97 3,50" {...common} />;
    case "identifying-relationship": return <><polygon points="90,3 177,50 90,97 3,50" {...common} /><polygon points="90,11 164,50 90,89 16,50" fill="none" stroke={stroke} strokeWidth={strokeWidth} vectorEffect="non-scaling-stroke" /></>;
    case "triangle": return <polygon points="90,3 177,97 3,97" {...common} />;
    case "pentagon-right": return <polygon points="3,3 135,3 177,50 135,97 3,97" {...common} />;
    case "parallelogram": case "data": return <polygon points="24,3 177,3 156,97 3,97" {...common} />;
    case "hexagon": case "preparation": return <polygon points="28,3 152,3 177,50 152,97 28,97 3,50" {...common} />;
    case "cylinder": case "database": return <><path d="M4 16 C4 0 176 0 176 16 V84 C176 100 4 100 4 84 Z" {...common} /><ellipse cx="90" cy="16" rx="86" ry="13" fill={fill} stroke={stroke} strokeWidth={strokeWidth} vectorEffect="non-scaling-stroke" /><path d="M4 84 C4 68 176 68 176 84" fill="none" stroke={stroke} strokeWidth={strokeWidth} vectorEffect="non-scaling-stroke" /></>;
    case "document": case "flow-document": return <path d="M3 3 H177 V80 C145 105 120 68 90 88 C60 108 35 70 3 90 Z" {...common} />;
    case "note": return <><path d="M3 3 H145 L177 35 V97 H3 Z" {...common} /><path d="M145 3 V35 H177" fill="none" stroke={stroke} strokeWidth={strokeWidth} vectorEffect="non-scaling-stroke" /></>;
    case "cloud": return <path d="M37 82 C8 82 3 59 20 45 C13 22 43 10 61 24 C75 2 115 5 124 29 C157 20 176 40 167 62 C177 83 145 95 126 83 Z" {...common} />;
    case "callout": return <polygon points="3,3 177,3 177,78 65,78 38,98 45,78 3,78" {...common} />;
    case "rounded-rectangle": case "terminator": return <rect x="3" y="3" width="174" height="94" rx={shape === "terminator" ? 47 : 16} {...common} />;
    case "manual-input": return <polygon points="3,22 177,3 177,97 3,97" {...common} />;
    case "delay": return <path d="M3 3 H125 C193 3 193 97 125 97 H3 Z" {...common} />;
    case "off-page-connector": return <polygon points="3,3 177,3 177,70 90,97 3,70" {...common} />;
    case "subprocess": return <><rect x="3" y="3" width="174" height="94" {...common} /><path d="M18 3 V97 M162 3 V97" fill="none" stroke={stroke} strokeWidth={strokeWidth} vectorEffect="non-scaling-stroke" /></>;
    case "weak-entity": return <><rect x="3" y="3" width="174" height="94" {...common} /><rect x="10" y="10" width="160" height="80" fill="none" stroke={stroke} strokeWidth={strokeWidth} vectorEffect="non-scaling-stroke" /></>;
    case "process": case "entity": case "rectangle": default: return <rect x="3" y="3" width="174" height="94" {...common} />;
  }
}

export default function ShapeRenderer({ shape, style = {}, children, compact = false }) {
  const fill = style.fill || "#ffffff";
  const stroke = style.stroke || "#475569";
  const strokeWidth = Number(style.strokeWidth || 2);
  if (shape === "text") return <div className="grid h-full w-full place-items-center text-center" style={{ color: style.textColor || "#0f172a", fontSize: compact ? 9 : style.fontSize || 14 }}>{children}</div>;
  return <div className="relative h-full w-full" data-shape={shape}>
    <svg className="absolute inset-0 h-full w-full overflow-visible" viewBox="0 0 180 100" preserveAspectRatio="none" aria-hidden="true">
      <Geometry shape={shape} fill={fill} stroke={stroke} strokeWidth={strokeWidth} dashed={Boolean(style.dashed)} />
    </svg>
    <div className={`absolute inset-[12%] grid place-items-center overflow-hidden text-center leading-tight ${shape === "key-attribute" ? "underline" : ""}`} style={{ color: style.textColor || "#0f172a", fontSize: compact ? 8 : style.fontSize || 14 }}>
      {children}
    </div>
  </div>;
}
