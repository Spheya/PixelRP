Shader "PixelRP/Unlit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MainColor ("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        [Toggle(_ALPHA_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Blend Off
        ZWrite On

        Pass
        {
            HLSLPROGRAM
            #pragma multi_compile_instancing
            #pragma shader_feature _ALPHA_CLIPPING
            #pragma vertex vertex
            #pragma fragment fragment
            #include "Unlit.hlsl"
            ENDHLSL
        }
    }
}
