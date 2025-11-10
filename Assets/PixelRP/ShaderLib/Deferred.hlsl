#ifndef INCLUDE_PIXELRP_DEFERRED_HLSL
#define INCLUDE_PIXELRP_DEFERRED_HLSL

#include "PixelRP.hlsl"
#include "Surface.hlsl"

TEXTURE2D(_GBufferAlbedo);
TEXTURE2D(_GBufferNormal);
TEXTURE2D(_GBufferMaterial);
TEXTURE2D(_LoResDepthTarget);
TEXTURE2D(_LoResColorTarget);
SAMPLER(sampler_point_clamp);

Surface sampleSurface(float2 screenUv) {
    Surface surf;
    surf.albedo = SAMPLE_TEXTURE2D_LOD(_GBufferAlbedo, sampler_point_clamp, screenUv, 0).rgb;
    surf.normal = normalize(SAMPLE_TEXTURE2D_LOD(_GBufferNormal, sampler_point_clamp, screenUv, 0).xyz * 2.0 - 1.0);
    surf.material = SAMPLE_TEXTURE2D_LOD(_GBufferMaterial, sampler_point_clamp, screenUv, 0).rgba;
    return surf;
}

float3 reconstructViewSpacePosition(float2 uv) {
    float depth = SAMPLE_DEPTH_TEXTURE_LOD(_LoResDepthTarget, sampler_point_clamp, uv, 0).r;
#if UNITY_REVERSED_Z
    depth = 1.0 - depth;
#endif
    float2 ndc = uv * 2.0 - 1.0;
    float4 clipPos = float4(ndc, depth * 2.0 - 1.0, 1.0);
    float4 viewPos = mul(UNITY_MATRIX_I_P, clipPos);
    return viewPos.xyz / viewPos.w;
}

#endif