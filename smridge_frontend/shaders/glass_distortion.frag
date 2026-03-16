#include <flutter/runtime_effect.glsl>

uniform float u_time;
uniform vec2 u_resolution;

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / u_resolution;

    float distortion = sin(uv.y * 40.0 + u_time * 2.0) * 0.004;
    uv.x += distortion;

    vec3 baseColor = vec3(0.05, 0.12, 0.20);
    float highlight = pow(1.0 - uv.y, 3.0);
    baseColor += highlight * 0.15;

    fragColor = vec4(baseColor, 0.10);
}
