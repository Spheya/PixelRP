using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace PixelRP {

	public class PixelRP : RenderPipeline {

		private static ShaderTagId _unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
		private static ShaderTagId _litGBufferShaderTagId = new ShaderTagId("PixelGBuffer");

		private static int _hiResTargetId = Shader.PropertyToID("_HiResTarget");
		private static int _loResDepthTargetId = Shader.PropertyToID("_LoResDepthTarget");
		private static int _loResColorTargetId = Shader.PropertyToID("_LoResColorTarget");
		private static int _loResPostProcessingTargetId = Shader.PropertyToID("_LoResPostProcessingTarget");
		private static int _gbufferAlbedoId = Shader.PropertyToID("_GBufferAlbedo");
		private static int _gbufferNormalId = Shader.PropertyToID("_GBufferNormal");
		private static int _gbufferMaterialId = Shader.PropertyToID("_GBufferMaterial");

		private static int _ambientLightId = Shader.PropertyToID("_AmbientLight");
		private static int _lightColId = Shader.PropertyToID("_LightCol");
		private static int _lightDirId = Shader.PropertyToID("_LightDir");
		private static int _inverseProjMatId = Shader.PropertyToID("_InverseProjectionMatrix");

		private int _ambientLightPassId;
		private int _directionalLightPassId;

		private static RenderTargetIdentifier[] _colorTargets = {
			new RenderTargetIdentifier(_gbufferAlbedoId),
			new RenderTargetIdentifier(_gbufferNormalId),
			new RenderTargetIdentifier(_gbufferMaterialId),
		};

		private static RenderTargetIdentifier[] _unlitTargets = {
			new RenderTargetIdentifier(_loResColorTargetId),
			new RenderTargetIdentifier(_gbufferNormalId),
			new RenderTargetIdentifier(_gbufferMaterialId),
		};

		private Mesh _blitMesh;
		private Material _deferredMaterial;
		private Material _outlineMaterial;
		private Material _blitMaterial;

		public PixelRP(PixelRPAsset asset) {
			GraphicsSettings.useScriptableRenderPipelineBatching = true;

			_outlineMaterial = new Material(Shader.Find("Hidden/PixelRP/Outline"));
			_outlineMaterial.hideFlags = HideFlags.HideAndDontSave;

			_blitMaterial = new Material(Shader.Find("Hidden/PixelRP/Blit"));
			_blitMaterial.hideFlags = HideFlags.HideAndDontSave;

			_deferredMaterial = new Material(Shader.Find("Hidden/PixelRP/Deferred"));
			_deferredMaterial.hideFlags = HideFlags.HideAndDontSave;
			_ambientLightPassId = _deferredMaterial.FindPass("AmbientLight");
			_directionalLightPassId = _deferredMaterial.FindPass("DirectionalLight");

			_blitMesh = new Mesh();
			_blitMesh.hideFlags = HideFlags.HideAndDontSave;
			_blitMesh.vertices = new Vector3[] { new Vector3(-1.0f, -1.0f, 0.0f), new Vector3(3.0f, -1.0f, 0.0f), new Vector3(-1.0f, 3.0f, 0.0f) };
			_blitMesh.SetUVs(0, new Vector2[] { new Vector2(0.0f, 1.0f), new Vector2(2.0f, 1.0f), new Vector2(0.0f, -1.0f) });
			_blitMesh.SetIndices(new int[] { 0, 1, 2 }, MeshTopology.Triangles, 0);
		}

		protected override void Render(ScriptableRenderContext context, Camera[] cameras) {
			var cmd = new CommandBuffer() { name = "PixelRP CommandBuffer" };
			Shader.SetGlobalColor(_ambientLightId, RenderSettings.ambientLight * RenderSettings.ambientIntensity);

			foreach (Camera camera in cameras) {
				BeginCameraRendering(context, camera);
				RenderCamera(ref context, camera, cmd);
				EndCameraRendering(context, camera);
			}
		}

		private void RenderCamera(ref ScriptableRenderContext context, Camera camera, CommandBuffer cmd) {
			cmd.BeginSample(camera.name);
			context.SetupCameraProperties(camera);
			Shader.SetGlobalMatrix(_inverseProjMatId, camera.projectionMatrix.inverse);

			CullingResults cullResults;
			if (camera.TryGetCullingParameters(out var cullingParams)) {
				cullResults = context.Cull(ref cullingParams);
			} else {
				Debug.LogWarning("Could not get culling parameters from camera \'" + camera.name + "\'", camera);
				return;
			}

			int loResTargetWidth = camera.scaledPixelWidth / 4;
			int loResTargetHeight = camera.scaledPixelHeight / 4;

			cmd.GetTemporaryRT(_hiResTargetId, loResTargetWidth, loResTargetHeight, 24, FilterMode.Point, RenderTextureFormat.DefaultHDR);
			cmd.GetTemporaryRT(_loResDepthTargetId, loResTargetWidth, loResTargetHeight, 24, FilterMode.Point, RenderTextureFormat.Depth);
			cmd.GetTemporaryRT(_loResColorTargetId, loResTargetWidth, loResTargetHeight, 0, FilterMode.Point, RenderTextureFormat.DefaultHDR, RenderTextureReadWrite.Linear);
			cmd.GetTemporaryRT(_loResPostProcessingTargetId, loResTargetWidth, loResTargetHeight, 0, FilterMode.Point, RenderTextureFormat.DefaultHDR, RenderTextureReadWrite.Linear);
			cmd.GetTemporaryRT(_gbufferAlbedoId, loResTargetWidth, loResTargetHeight, 0, FilterMode.Point, RenderTextureFormat.DefaultHDR, RenderTextureReadWrite.Linear);
			cmd.GetTemporaryRT(_gbufferNormalId, loResTargetWidth, loResTargetHeight, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
			cmd.GetTemporaryRT(_gbufferMaterialId, loResTargetWidth, loResTargetHeight, 0, FilterMode.Point, RenderTextureFormat.Default, RenderTextureReadWrite.Linear);

			cmd.BeginSample("Lo Res");

			LoResDrawPass(ref context, ref cullResults, cmd, camera);

			cmd.EndSample("Lo Res");
			cmd.BeginSample("Hi Res");


			cmd.SetRenderTarget(_hiResTargetId);
			cmd.DrawMesh(_blitMesh, Matrix4x4.identity, _blitMaterial);

			cmd.Blit(_hiResTargetId, BuiltinRenderTextureType.CameraTarget, _blitMaterial);

			cmd.EndSample("Hi Res");

			cmd.ReleaseTemporaryRT(_hiResTargetId);
			cmd.ReleaseTemporaryRT(_loResDepthTargetId);
			cmd.ReleaseTemporaryRT(_loResColorTargetId);
			cmd.ReleaseTemporaryRT(_loResPostProcessingTargetId);
			cmd.ReleaseTemporaryRT(_gbufferAlbedoId);
			cmd.ReleaseTemporaryRT(_gbufferNormalId);
			cmd.ReleaseTemporaryRT(_gbufferMaterialId);
			cmd.EndSample(camera.name);

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();

#if UNITY_EDITOR
			if (Handles.ShouldRenderGizmos()) {
				context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
				context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
			}
#endif

			context.Submit();
		}

		private void LoResDrawPass(ref ScriptableRenderContext context, ref CullingResults cullResults, CommandBuffer cmd, Camera camera) {
			cmd.SetRenderTarget(_colorTargets, new RenderTargetIdentifier(_loResDepthTargetId));
			cmd.ClearRenderTarget(true, true, Color.clear);

			// GBuffer
			{
				cmd.BeginSample("GBuffer");

				var sortSettings = new SortingSettings(camera) {
					criteria = SortingCriteria.CommonOpaque
				};
				var drawSettings = new DrawingSettings(_litGBufferShaderTagId, sortSettings) {
					enableDynamicBatching = true,
					enableInstancing = true
				};
				var filterSettings = new FilteringSettings(RenderQueueRange.opaque);
				var renderListParams = new RendererListParams(cullResults, drawSettings, filterSettings);

				cmd.DrawRendererList(context.CreateRendererList(ref renderListParams));

				cmd.EndSample("GBuffer");
			}

			// Lights
			{
				cmd.BeginSample("Lights");

				cmd.SetRenderTarget(_loResColorTargetId);
				cmd.ClearRenderTarget(true, true, camera.backgroundColor);

				cmd.DrawMesh(_blitMesh, Matrix4x4.identity, _deferredMaterial, 0, _ambientLightPassId);

				foreach (var light in cullResults.visibleLights) {
					if (light.lightType == LightType.Directional) {
						_deferredMaterial.SetVector(_lightDirId, light.light.transform.forward);
						_deferredMaterial.SetColor(_lightColId, light.finalColor);
						cmd.DrawMesh(_blitMesh, Matrix4x4.identity, _deferredMaterial, 0, _directionalLightPassId);
					}
				}

				cmd.SetRenderTarget(_unlitTargets, new RenderTargetIdentifier(_loResDepthTargetId));

				cmd.EndSample("Lights");
			}

			// Unlit
			{
				cmd.BeginSample("Unlit");

				var sortSettings = new SortingSettings(camera) {
					criteria = SortingCriteria.CommonOpaque
				};
				var drawSettings = new DrawingSettings(_unlitShaderTagId, sortSettings) {
					enableDynamicBatching = true,
					enableInstancing = true
				};
				var filterSettings = new FilteringSettings(RenderQueueRange.opaque);
				var renderListParams = new RendererListParams(cullResults, drawSettings, filterSettings);

				cmd.DrawRendererList(context.CreateRendererList(ref renderListParams));

				cmd.EndSample("Lights");
			}

			cmd.DrawRendererList(context.CreateSkyboxRendererList(camera, camera.projectionMatrix, camera.transform.worldToLocalMatrix));

			// Outline
			{
				cmd.BeginSample("Outline");

				cmd.SetRenderTarget(_loResPostProcessingTargetId);
				cmd.DrawMesh(_blitMesh, Matrix4x4.identity, _outlineMaterial);

				cmd.EndSample("Outline");
			}

			// Transparent
			/*{
				cmd.BeginSample("Transparent");

				var sortSettings = new SortingSettings(camera) {
					criteria = SortingCriteria.CommonTransparent
				};
				var drawSettings = new DrawingSettings(_unlitShaderTagId, sortSettings) {
					enableDynamicBatching = true,
					enableInstancing = true
				};
				var filterSettings = new FilteringSettings(RenderQueueRange.transparent);
				var renderListParams = new RendererListParams(cullResults, drawSettings, filterSettings);

				cmd.DrawRendererList(context.CreateRendererList(ref renderListParams));

				cmd.EndSample("Transparent");
			}*/
		}
	}

}