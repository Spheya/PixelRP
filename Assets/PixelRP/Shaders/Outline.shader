Shader "Hidden/PixelRP/Outline"
{
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite On

        Pass
        {
            Name "OuterOutline"

            HLSLPROGRAM
            #pragma vertex vertex
            #pragma fragment fragment

            #include "Assets/PixelRP/ShaderLib/PixelRP.hlsl"
            #include "Assets/PixelRP/ShaderLib/Deferred.hlsl"

            float4 _GBufferAlbedo_TexelSize;


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

            bool validDepth(float depth) {
#if defined(UNITY_REVERSED_Z)
                return depth > 0.0;
#else
                return depth < 1.0;
#endif
            }

            float4 fragment(Varyings varyings) : SV_Target {
                float3 baseColor = SAMPLE_TEXTURE2D_LOD(_LoResColorTarget, sampler_point_clamp, varyings.uv, 0).rgb;

                // Depth-based outline
                float rds0 = SAMPLE_DEPTH_TEXTURE_LOD(_LoResDepthTarget, sampler_point_clamp, varyings.uv, 0).r;
                float rds1 = SAMPLE_DEPTH_TEXTURE_LOD(_LoResDepthTarget, sampler_point_clamp, varyings.uv + float2(_GBufferAlbedo_TexelSize.x, 0.0), 0).r;
                float rds2 = SAMPLE_DEPTH_TEXTURE_LOD(_LoResDepthTarget, sampler_point_clamp, varyings.uv - float2(_GBufferAlbedo_TexelSize.x, 0.0), 0).r;
                float rds3 = SAMPLE_DEPTH_TEXTURE_LOD(_LoResDepthTarget, sampler_point_clamp, varyings.uv + float2(0.0, _GBufferAlbedo_TexelSize.y), 0).r;
                float rds4 = SAMPLE_DEPTH_TEXTURE_LOD(_LoResDepthTarget, sampler_point_clamp, varyings.uv - float2(0.0, _GBufferAlbedo_TexelSize.y), 0).r;

                float ds0 = LinearEyeDepth(rds0, _ZBufferParams);
                float ds1 = LinearEyeDepth(rds1, _ZBufferParams);
                float ds2 = LinearEyeDepth(rds2, _ZBufferParams);
                float ds3 = LinearEyeDepth(rds3, _ZBufferParams);
                float ds4 = LinearEyeDepth(rds4, _ZBufferParams);

                float expectedX = (ds1 + ds2) * 0.5;
                float expectedY = (ds3 + ds4) * 0.5;
                float deltaX = ds0 - expectedX;
                float deltaY = ds0 - expectedY;

                const float cutoff = 0.1;
                float outline = max(deltaX, deltaY) - cutoff;
                outline = ceil(smoothstep(0.0, 0.15, outline) * 3.0) / 3.0;

                if(outline >= 1.0) {
                    float nearestDs = min(ds0, min(ds1, min(ds2, min(ds3, ds4))));
                    if(nearestDs == ds1) baseColor = SAMPLE_TEXTURE2D_LOD(_LoResColorTarget, sampler_point_clamp, varyings.uv + float2(_GBufferAlbedo_TexelSize.x, 0.0), 0).rgb;
                    if(nearestDs == ds2) baseColor = SAMPLE_TEXTURE2D_LOD(_LoResColorTarget, sampler_point_clamp, varyings.uv - float2(_GBufferAlbedo_TexelSize.x, 0.0), 0).rgb;
                    if(nearestDs == ds3) baseColor = SAMPLE_TEXTURE2D_LOD(_LoResColorTarget, sampler_point_clamp, varyings.uv + float2(0.0, _GBufferAlbedo_TexelSize.y), 0).rgb;
                    if(nearestDs == ds4) baseColor = SAMPLE_TEXTURE2D_LOD(_LoResColorTarget, sampler_point_clamp, varyings.uv - float2(0.0, _GBufferAlbedo_TexelSize.y), 0).rgb;
                    return float4(lerp(baseColor, min(pow(baseColor, 2) * float3(0.2, 0.1, 0.3), baseColor), outline), 1.0);
                }

                if(!validDepth(rds0)) return float4(baseColor, 1.0);

                // Normal-based outline
                float3 ns0 = normalize(SAMPLE_TEXTURE2D_LOD(_GBufferNormal, sampler_point_clamp, varyings.uv, 0).rgb - 0.5);
                float3 ns1 = validDepth(rds1) ? normalize(SAMPLE_TEXTURE2D_LOD(_GBufferNormal, sampler_point_clamp, varyings.uv + float2(_GBufferAlbedo_TexelSize.x, 0.0), 0).rgb - 0.5) : ns0;
                float3 ns2 = validDepth(rds2) ? normalize(SAMPLE_TEXTURE2D_LOD(_GBufferNormal, sampler_point_clamp, varyings.uv - float2(_GBufferAlbedo_TexelSize.x, 0.0), 0).rgb - 0.5) : ns0;
                float3 ns3 = validDepth(rds3) ? normalize(SAMPLE_TEXTURE2D_LOD(_GBufferNormal, sampler_point_clamp, varyings.uv + float2(0.0, _GBufferAlbedo_TexelSize.y), 0).rgb - 0.5) : ns0;
                float3 ns4 = validDepth(rds4) ? normalize(SAMPLE_TEXTURE2D_LOD(_GBufferNormal, sampler_point_clamp, varyings.uv - float2(0.0, _GBufferAlbedo_TexelSize.y), 0).rgb - 0.5) : ns0;

                float4 depthBias = float4(ds1 - ds0, ds2 - ds0, ds3 - ds0, ds4 - ds0);
                float avgDepthBias = (depthBias.x + depthBias.y + depthBias.z + depthBias.w) * 0.25;

                ns1 = abs(depthBias.x) < 0.2 ? ns1 : ns0;
                ns2 = abs(depthBias.y) < 0.2 ? ns2 : ns0;
                ns3 = abs(depthBias.z) < 0.2 ? ns3 : ns0;
                ns4 = abs(depthBias.w) < 0.2 ? ns4 : ns0;

                const float3 v = float3(1.0, 1.25847, 1.12345); // Random numbers to dicate priority

                float4 sharpness = float4(
                    1.0 - max(dot(ns0, ns1), 0.0),
                    1.0 - max(dot(ns0, ns2), 0.0),
                    1.0 - max(dot(ns0, ns3), 0.0),
                    1.0 - max(dot(ns0, ns4), 0.0)
                );

                float4 bias = float4(
                    smoothstep(-0.01, 0.01, dot(ns0 - ns1, v)),
                    smoothstep(-0.01, 0.01, dot(ns0 - ns2, v)),
                    smoothstep(-0.01, 0.01, dot(ns0 - ns3, v)),
                    smoothstep(-0.01, 0.01, dot(ns0 - ns4, v))
                );

                float normalIndicator = dot(sharpness, bias);
                normalIndicator = ceil(smoothstep(0.25, 1.0, normalIndicator) * 3.0) / 3.0;
                if(normalIndicator > 0.0) {
                    if(avgDepthBias > 0.0) {
                        baseColor *= 1.4;
                    } else {
                        outline = max(outline, 0.6);
                    }
                }

                return float4(lerp(baseColor, min(pow(baseColor, 2) * float3(0.2, 0.1, 0.3), baseColor), outline), 1.0);
            }

            ENDHLSL
        }
    }
}
