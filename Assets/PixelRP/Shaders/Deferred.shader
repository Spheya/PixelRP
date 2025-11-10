Shader "Hidden/PixelRP/Deferred"
{
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off

        Pass
        {
            Name "AmbientLight"

            HLSLPROGRAM
            #pragma vertex vertex
            #pragma fragment fragment

            #include "Assets/PixelRP/ShaderLib/PixelRP.hlsl"
            #include "Assets/PixelRP/ShaderLib/Deferred.hlsl"
            #include "Assets/PixelRP/ShaderLib/Light.hlsl"

            struct Attributes {
                 float4 vertex : POSITION;
                 float2 uv : TEXCOORD0;
             };

            struct Varyings {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            Varyings vertex(Attributes attribs) {
                Varyings varyings;
                varyings.uv = attribs.uv;
                varyings.vertex = attribs.vertex;
                return varyings;
            }

            float4 fragment(Varyings varyings) : SV_Target {
                float3 albedo = SAMPLE_TEXTURE2D_LOD(_GBufferAlbedo, sampler_point_clamp, varyings.uv, 0).rgb;
                float4 material = SAMPLE_TEXTURE2D_LOD(_GBufferMaterial, sampler_point_clamp, varyings.uv, 0);
                return float4(processAmbientLight(albedo, _AmbientLight, material), 1.0);
            }

            ENDHLSL
        }

        Pass
        {
            Name "DirectionalLight"
            Blend One One

            HLSLPROGRAM
            #pragma vertex vertex
            #pragma fragment fragment

            #include "Assets/PixelRP/ShaderLib/PixelRP.hlsl"
            #include "Assets/PixelRP/ShaderLib/Deferred.hlsl"
            #include "Assets/PixelRP/ShaderLib/Light.hlsl"

            struct Attributes {
                 float4 vertex : POSITION;
                 float2 uv : TEXCOORD0;
             };

            struct Varyings {
                float2 uv : TEXCOORD0;
                float3 lightDirVS : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            float3 _LightDir;
            float3 _LightCol;

            Varyings vertex(Attributes attribs) {
                Varyings varyings;
                varyings.uv = attribs.uv;
                varyings.lightDirVS = mul((float3x3)UNITY_MATRIX_V, -_LightDir);
                varyings.vertex = attribs.vertex;
                return varyings;
            }

            float4 fragment(Varyings varyings) : SV_Target {
                float3 positionVS = reconstructViewSpacePosition(varyings.uv);
                
                Surface surface = sampleSurface(varyings.uv);
                
                Light light;
                light.direction = varyings.lightDirVS;
                light.color = _LightCol;

                return float4(processLight(surface, light, normalize(positionVS), positionVS), 1.0);
            }

            ENDHLSL
        }
    }
}
