// Rotation periods and color treatment adapted from Lyricify-Backgrounds.
// SPDX-License-Identifier: Apache-2.0
// See third_party/lyricify-backgrounds/NOTICE.txt for attribution and changes.
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uDark;
uniform float uCoverFirst;
uniform float uArtworkMix;
uniform sampler2D uPreviousArtwork;
uniform sampler2D uArtwork;
out vec4 fragColor;

vec2 rotatePoint(vec2 p, float angle) {
  float s = sin(angle), c = cos(angle);
  return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}
vec3 saturation(vec3 color, float amount) {
  return mix(vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))), color, amount);
}
void main() {
  vec2 p = FlutterFragCoord().xy / uSize - 0.5;
  p.x *= min(uSize.x / uSize.y, 1.8);
  p += 0.12 * vec2(sin(p.y * 4.0 + uTime * 0.06), cos(p.x * 4.0 - uTime * 0.05));
  vec2 a = rotatePoint(p, uTime * 6.2831853 / 120.0) / 1.4 + 0.5;
  vec2 b = rotatePoint(p + vec2(-0.25, 0.15), uTime * 6.2831853 / 70.0) / 0.7 + 0.5;
  vec2 c = rotatePoint(p + vec2(0.7), uTime * 6.2831853 / 90.0) / 0.7 + 0.5;
  vec3 color = texture(uArtwork, clamp(a, 0.0, 1.0)).rgb * 0.55
             + texture(uArtwork, clamp(b, 0.0, 1.0)).rgb * 0.25
             + texture(uArtwork, clamp(c, 0.0, 1.0)).rgb * 0.20;
  if (uArtworkMix < 0.999) {
    vec3 previous = texture(uPreviousArtwork, clamp(a, 0.0, 1.0)).rgb * 0.55
                  + texture(uPreviousArtwork, clamp(b, 0.0, 1.0)).rgb * 0.25
                  + texture(uPreviousArtwork, clamp(c, 0.0, 1.0)).rgb * 0.20;
    color = mix(previous, color, uArtworkMix);
  }
  color = saturation(clamp(saturation(color, 1.4), -0.752941, 1.25098), 0.70);
  color = mix(mix(vec3(0.96, 0.98, 0.97), color, mix(0.22, 0.58, uCoverFirst)),
              mix(vec3(0.035, 0.045, 0.045), color, mix(0.28, 0.58, uCoverFirst)), uDark);
  fragColor = vec4(color, 1.0);
}
