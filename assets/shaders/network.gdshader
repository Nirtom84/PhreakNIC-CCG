shader_type canvas_item;
uniform bool effects = true;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
 vec2 p = UV * vec2(160.0, 90.0);
 float t = effects ? TIME : 0.0;
 vec2 cell = floor(p);
 vec2 g = fract(p);
 // Procedural terminal glyphs: sparse vertical stems and cross strokes.
 float seed = hash(vec2(cell.x, floor(cell.y + t * (1.0 + hash(vec2(cell.x,0.0))))));
 float glyph = step(g.x, 0.17) * step(0.16,g.y) * step(g.y,0.85);
 glyph += step(abs(g.y - 0.3),0.055) * step(g.x,0.7);
 glyph += step(abs(g.y - 0.65),0.045) * step(g.x,seed);
 float rain = glyph * step(0.72, seed) * (0.3 + 0.7 * pow(fract(cell.y / 23.0 + t * 0.08 + hash(vec2(cell.x,1.0))), 5.0));
 vec2 grid = abs(fract(UV * vec2(40.0,22.5)) - 0.5);
 float trace = step(0.492, max(grid.x,grid.y));
 float vignette = clamp(1.0 - length((UV - 0.5) * 1.25),0.2,1.0);
 float scan = effects ? sin(UV.y * 1080.0 * 3.14159) * 0.008 : 0.0;
 vec3 base = vec3(0.0196,0.0353,0.051);
 COLOR = vec4((base + vec3(0.16,0.9,1.0) * (rain * 0.075 + trace * 0.017 + scan)) * vignette, 1.0);
}
