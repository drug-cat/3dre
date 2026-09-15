#version 330 core

in vec3 vColor;
in vec3 vNormal;
in vec3 vWorldPos;
in vec2 vUV;
in vec4 vLightSpacePos;

uniform sampler2D uAlbedo;
uniform sampler2D uNormalMap;
uniform sampler2D uShadowMap;

uniform vec3  uColor;
uniform vec3  uSunDir;
uniform vec3  uSunColor;
uniform float uAmbient;

uniform vec3  uCameraPos;
uniform vec3  uSpecularColor;
uniform float uShininess;

uniform vec3  lightA_pos;
uniform vec3  lightA_color;
uniform vec3  lightB_pos;
uniform vec3  lightB_color;
uniform float uPointIntensity;

uniform float uUnlit;
uniform float uShadowEnabled;
uniform float uNormalStrength;      // 0 = off, 1 = full

out vec4 FragColor;

vec3 applyNormalMap(vec3 N, vec3 worldPos, vec2 uv)
{
    if (uNormalStrength < 0.001) return N;

    vec3 nT = texture(uNormalMap, uv * 4.0).rgb * 2.0 - 1.0;
    nT.xy *= uNormalStrength;

    // Reconstruct TBN from screen-space derivatives
    vec3 dp1  = dFdx(worldPos);
    vec3 dp2  = dFdy(worldPos);
    vec2 duv1 = dFdx(uv * 4.0);
    vec2 duv2 = dFdy(uv * 4.0);

    vec3 dp2perp = cross(dp2, N);
    vec3 dp1perp = cross(N, dp1);
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

    float invLen = inversesqrt(max(dot(T, T), 1e-8));
    T *= invLen;
    invLen = inversesqrt(max(dot(B, B), 1e-8));
    B *= invLen;

    return normalize(mat3(T, B, N) * nT);
}

float computeShadow()
{
    if (uShadowEnabled < 0.5) return 1.0;

    vec3 proj = vLightSpacePos.xyz / vLightSpacePos.w;
    proj = proj * 0.5 + 0.5;
    if (proj.z > 1.0) return 1.0;

    float bias = 0.0035;
    float shadow = 0.0;
    vec2 texel = 1.0 / textureSize(uShadowMap, 0);
    for (int x = -1; x <= 1; ++x) {
        for (int y = -1; y <= 1; ++y) {
            float d = texture(uShadowMap, proj.xy + vec2(x, y) * texel).r;
            shadow += (proj.z - bias > d) ? 0.0 : 1.0;
        }
    }
    return shadow / 9.0;
}

void main()
{
    if (uUnlit > 0.5) {
        FragColor = vec4(vColor * uColor, 1.0);
        return;
    }

    vec3 tex  = texture(uAlbedo, vUV).rgb;
    vec3 base = vColor * uColor * tex;

    vec3 N = normalize(vNormal);
    N = applyNormalMap(N, vWorldPos, vUV);

    vec3 V = normalize(uCameraPos - vWorldPos);

    // Directional sun
    vec3  L    = normalize(uSunDir);
    float ndl  = max(dot(N, L), 0.0);
    vec3  H    = normalize(L + V);
    float spec = pow(max(dot(N, H), 0.0), uShininess);
    spec *= step(0.0001, ndl);
    float sh   = computeShadow();
    vec3 lit = (base * (uAmbient + ndl * uSunColor) + uSpecularColor * spec) * sh;

    // Point light A
    {
        vec3  toL   = lightA_pos - vWorldPos;
        float d2    = dot(toL, toL);
        float d     = sqrt(d2);
        vec3  Lp    = toL / max(d, 0.0001);
        float atten = uPointIntensity / (1.0 + d2 * 0.4);
        float n     = max(dot(N, Lp), 0.0);
        lit += base * n * atten * lightA_color;
    }

    // Point light B
    {
        vec3  toL   = lightB_pos - vWorldPos;
        float d2    = dot(toL, toL);
        float d     = sqrt(d2);
        vec3  Lp    = toL / max(d, 0.0001);
        float atten = uPointIntensity / (1.0 + d2 * 0.4);
        float n     = max(dot(N, Lp), 0.0);
        lit += base * n * atten * lightB_color;
    }

    FragColor = vec4(lit, 1.0);
}