using UnityEngine;
using UnityEngine.Rendering;

namespace PixelRP {

	[CreateAssetMenu(menuName = "PixelRP/Pipeline Asset")]
	public class PixelRPAsset : RenderPipelineAsset<PixelRP> {

		protected override RenderPipeline CreatePipeline() {
			return new PixelRP(this);
		}

	}

}