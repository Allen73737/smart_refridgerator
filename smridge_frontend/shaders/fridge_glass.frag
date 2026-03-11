#version 460 core
precision highp float;

uniform float u_time;
uniform vec2 u_resolution;

out vec4 fragColor;

void main() {

    vec2 uv = gl_FragCoord.xy / u_resolution;

    float wave =
        sin(uv.y * 40.0 + u_time * 3.0) * 0.004;

    uv.x += wave;

    float fresnel =
        pow(1.0 - uv.y, 3.0);

    vec3 base =
        vec3(0.05, 0.15, 0.25);

    base += fresnel * 0.25;

    fragColor =
        vec4(base, 0.15);
}
