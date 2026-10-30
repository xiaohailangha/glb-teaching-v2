// Composite display-referred premultiplied character coverage against the
// exact Flutter page gradient before FXAA and the browser ImageBitmap bridge.
// An opaque final image avoids platform-specific alpha fringes at silhouettes.
uniform sampler2D input_color;
in vec2 v_uv;
out vec4 frag_color;
void main() {
  vec4 character = texture(input_color, v_uv);
  float y = clamp(v_uv.y, 0.0, 1.0);
  float gray = y <= 0.72
      ? mix(68.0 / 255.0, 125.0 / 255.0, y / 0.72)
      : mix(125.0 / 255.0, 128.0 / 255.0, (y - 0.72) / 0.28);
  frag_color = vec4(character.rgb + vec3(gray) * (1.0 - character.a), 1.0);
}
