import bpy
import json
from pathlib import Path

result = {
    'version': bpy.app.version_string,
    'executable': bpy.app.binary_path,
    'background': bpy.app.background,
    'gltf_export_available': hasattr(bpy.ops.export_scene, 'gltf'),
    'model_assets_created': False,
}
Path('P:/GameDev/AllusionsTooGrandeur/setup/blender-verification.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print('ALLUSIONS_BLENDER_OK ' + json.dumps(result))
