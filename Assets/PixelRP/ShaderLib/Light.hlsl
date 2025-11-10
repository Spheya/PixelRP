#ifndef INCLUDE_PIXELRP_LIGHT_HLSL
#define INCLUDE_PIXELRP_LIGHT_HLSL

#include "PixelRP.hlsl"
#include "Surface.hlsl"

float3 _AmbientLight;

struct Light {
    float3 color;
    float3 direction;
};

float D_GGX(float NoH, float roughness)
{
    float n2 = NoH * NoH;
    float r2 = roughness * roughness;
    float d = (1.0 - n2 + n2 * r2);
    return r2 / (d * d);
}

float3 F_Schlick(float nDotV, float3 r0) {
    float f = (1.0 - nDotV);
    return r0 + (1.0 - r0) * f * f * f * f * f;
}

float G_SchlickGGX(float nDotL, float nDotV, float roughness)
{
    float k = roughness / 2;
    float smithL = (nDotL) / (nDotL * (1.0 - k) + k);
    float smithV = (nDotV) / (nDotV * (1.0 - k) + k);
    return smithL * smithV;
}

float3 processAmbientLight(float3 albedo, float3 lightColor, float4 material)
{
    return albedo * lightColor * lerp(1.0, 0.5, material.r);
}

float3 processLight(inout Surface surface, Light light, float3 view, float3 positionVS) {
    float metallic = surface.material.r;
    float roughness = max(surface.material.g, 0.01);

    float3 halfVector = normalize(light.direction - view);
    float nDotH = dot(surface.normal, halfVector);
    float nDotV = -dot(surface.normal, view);
    float nDotL = dot(light.direction, surface.normal);
    float lDotH = dot(light.direction, halfVector);


    float3 F = F_Schlick(lDotH, lerp(0.15, surface.albedo, metallic)) * (1.0 - roughness * roughness * (1.0 - metallic));
    float D = D_GGX(nDotH, roughness);
    float G = G_SchlickGGX(max(nDotL + 0.2, 0.0), max(nDotV, 0.0), roughness);

    float cappedNotL = max(nDotL, 0.0);

    float reflectionBands = 0.5 + roughness * 3.0;
    float3 reflection = F * (D * G / (4.0 * max(nDotV, 0.01)));
    reflection = round(sqrt(reflection) * reflectionBands) / reflectionBands;
    reflection *= reflection;

    float diffuse = (1.0 - F) * (ceil(pow(cappedNotL, 0.8) * 2.0) / 2.0) * (1.0 - metallic);

    return light.color * (reflection + diffuse * surface.albedo);
}

#endif