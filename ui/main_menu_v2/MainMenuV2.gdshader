 shader_type canvas_item;

// Controls the direction and speed of the scroll
// Positive X moves the texture left, Negative Y moves the texture down
uniform vec2 scroll_speed = vec2(0.2, -0.2);

void fragment() {
    // fract() forces the math to loop perfectly between 0.0 and 1.0
    // This entirely bypasses the engine's clamping issue!
    vec2 shifted_uv = fract(UV + TIME * scroll_speed);
    
    // Apply the perfectly looped UVs to the texture
    COLOR = texture(TEXTURE, shifted_uv);
}