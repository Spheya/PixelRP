#include "Assets/PixelRP/ShaderLib/PixelRP.hlsl"

struct Attributes {
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
 };

struct Varyings {
    float2 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float4 vertex : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct FragOut {
    float4 albedo : SV_Target0;
    float4 normal : SV_Target1;
    float4 material : SV_Target2;
};

TEXTURE2D(_MetallicRoughnessTex);
SAMPLER(sampler_MetallicRoughnessTex);

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _MetallicFactor)
    UNITY_DEFINE_INSTANCED_PROP(float, _RoughnessFactor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
            
Varyings vertex(Attributes attribs) {
    Varyings varyings;

    UNITY_SETUP_INSTANCE_ID(attribs);
    UNITY_TRANSFER_INSTANCE_ID(attribs, varyings);

    float3 positionWS = TransformObjectToWorld(attribs.vertex);
    float4 st = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);

    varyings.uv = attribs.uv * st.xy + st.zw;
    varyings.normal = mul((float3x3) UNITY_MATRIX_V, mul((float3x3)unity_ObjectToWorld, attribs.normal));
    varyings.vertex = TransformWorldToHClip(positionWS);

    return varyings;
}

FragOut fragment(Varyings varyings) {
    FragOut fragOut;

    UNITY_SETUP_INSTANCE_ID(varyings);

    fragOut.albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, varyings.uv) * UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainColor);
    
    #ifdef _ALPHA_CLIPPING
    clip(fragOut.albedo.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
    #endif
    
    fragOut.normal = float4(normalize(varyings.normal) * 0.5 + 0.5, 1.0);
    
    float4 metallicRoughness = SAMPLE_TEXTURE2D(_MetallicRoughnessTex, sampler_MetallicRoughnessTex, varyings.uv);
    float metallic = metallicRoughness.b * UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MetallicFactor);
    float roughness = metallicRoughness.g * UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _RoughnessFactor);
    fragOut.material = float4(metallic, roughness, 0.0, 1.0);

    return fragOut;
}