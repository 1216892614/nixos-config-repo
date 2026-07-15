// Squircle SDF shader — superellipse n≈4.5 + 径向渐变烟熏玻璃
// 用于灵动岛遮罩：超出边界 alpha=0，内部径向渐变控制透明度

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  // 自定义 uniform
  float maskWidth;       // 遮罩宽度（像素）
  float maskHeight;      // 遮罩高度（像素）
  float radius;          // 圆角半径（像素）
  float gradientCenterX; // 渐变中心 X 偏移（0~1，0.5=居中）
  float gradientCenterY; // 渐变中心 Y 偏移（0~1，0.5=居中）
  float opaqueRadius;    // 不透明区域半径（归一化 0~1）
  float edgeSoftness;    // 边缘抗锯齿宽度（像素）
};

// Superellipse SDF（n=4.5）
float squircleSDF(vec2 p, vec2 halfSize, float r) {
  vec2 d = abs(p) - halfSize + vec2(r);
  vec2 dn = max(d, 0.0);
  // n=4.5 → 使用 pow(x, 4.5) 近似
  float n = 4.5;
  float outside = pow(pow(dn.x, n) + pow(dn.y, n), 1.0 / n) - r;
  float inside = min(max(d.x, d.y), 0.0);
  return outside + inside;
}

void main() {
  vec2 pixelPos = qt_TexCoord0 * vec2(maskWidth, maskHeight);
  vec2 center = vec2(maskWidth, maskHeight) * 0.5;
  vec2 halfSize = center;

  // SDF 距离
  float dist = squircleSDF(pixelPos - center, halfSize, radius);

  // 抗锯齿边缘
  float shapeMask = 1.0 - smoothstep(-edgeSoftness, 0.0, dist);

  // 径向渐变：从偏移中心到边缘
  vec2 gradCenter = vec2(gradientCenterX, gradientCenterY) * vec2(maskWidth, maskHeight);
  float gradDist = length(pixelPos - gradCenter) / length(vec2(maskWidth, maskHeight));
  float gradAlpha = 1.0 - smoothstep(opaqueRadius, opaqueRadius + 0.4, gradDist);

  // 最终 alpha = 形状遮罩 × 渐变透明度 × 基础不透明度
  float baseOpacity = 0.92;
  float alpha = shapeMask * mix(0.0, baseOpacity, gradAlpha);

  // 输出黑色 + alpha
  fragColor = vec4(0.0, 0.0, 0.0, alpha * qt_Opacity);
}
