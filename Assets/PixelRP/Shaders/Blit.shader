Shader "Hidden/PixelRP/Blit"
{
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite On

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vertex
            #pragma fragment fragment
            
            #include "Assets/PixelRP/ShaderLib/PixelRP.hlsl"

            struct Attributes {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            struct FragOut {
                float4 color : SV_Target;
                float depth : SV_Depth;
            };

            TEXTURE2D(_LoResPostProcessingTarget);
            TEXTURE2D(_LoResDepthTarget);
            SAMPLER(sampler_point_clamp);

            Varyings vertex(Attributes attribs) {
                Varyings varyings;
                varyings.uv = attribs.uv;
                varyings.vertex = TransformWorldToHClip(attribs.vertex);
                return varyings;
            }

            FragOut fragment(Varyings varyings) {
                FragOut fragOut;
                fragOut.color = SAMPLE_TEXTURE2D_LOD(_LoResPostProcessingTarget, sampler_point_clamp, varyings.uv, 0);
                fragOut.depth = SAMPLE_DEPTH_TEXTURE_LOD(_LoResDepthTarget, sampler_point_clamp, varyings.uv, 0).r;
                return fragOut;
            }

            ENDHLSL
        }
    }
}
