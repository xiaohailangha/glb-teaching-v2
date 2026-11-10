/// Select an already authored mip, preserving its color/normal filtering and
/// complete remaining chain. A base-only source is never guessed or resampled.
int textureBaseMip(int width, int height, int levels, {int? maxSide}) {
  var base = 0;
  if (maxSide == null || maxSide < 1) return base;
  while (base + 1 < levels && (width > maxSide || height > maxSide)) {
    width = (width >> 1).clamp(1, width);
    height = (height >> 1).clamp(1, height);
    base++;
  }
  return base;
}
