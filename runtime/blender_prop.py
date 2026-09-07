"""Trusted Blender-only recipe runner. Blender Z-up -> GLB Y-up."""
import bpy
import json
import math
from pathlib import Path
import sys
from mathutils import Vector

work=Path(sys.argv[sys.argv.index('--')+1])
recipe=json.loads((work/'recipe.json').read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
objects=[]
for part in recipe['parts']:
    shape=part['shape']
    if shape=='box': bpy.ops.mesh.primitive_cube_add(size=1)
    elif shape=='sphere': bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.5)
    elif shape=='cylinder': bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.5,depth=1)
    else: bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.5,radius2=0,depth=1)
    ob=bpy.context.object;ob.name=part['name'];ob.dimensions=part['size']
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.location=part['position'];ob.rotation_euler=[math.radians(x) for x in part['rotation']]
    mat=bpy.data.materials.new(part['name']);mat.use_nodes=True
    rgb=[int(part['color'][i:i+2],16)/255 for i in (0,2,4)]
    rgba=tuple((v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4) for v in rgb)+(1,)
    mat.diffuse_color=rgba;node=mat.node_tree.nodes.get('Principled BSDF');node.inputs['Base Color'].default_value=rgba;node.inputs['Roughness'].default_value=.8
    ob.data.materials.append(mat);objects.append(ob)
bpy.context.view_layer.update()
# Reject wholly detached pieces using conservative transformed bounds. This does
# not prove actual surface contact: human review remains necessary for curved parts.
bounds=[]
for ob in objects:
    corners=[ob.matrix_world@Vector(c) for c in ob.bound_box]
    bounds.append((Vector([min(p[i] for p in corners) for i in range(3)]),Vector([max(p[i] for p in corners) for i in range(3)])))
connected={0}
while True:
    added={j for j,b in enumerate(bounds) if j not in connected and any(all(b[0][axis]<=bounds[i][1][axis]+.005 and bounds[i][0][axis]<=b[1][axis]+.005 for axis in range(3)) for i in connected)}
    if not added: break
    connected.update(added)
assert len(connected)==len(objects), '模型存在明显悬空部件，请调整描述让部件相接'
points=[ob.matrix_world@Vector(c) for ob in objects for c in ob.bound_box]
low=Vector([min(p[i] for p in points) for i in range(3)]);high=Vector([max(p[i] for p in points) for i in range(3)])
extent=high-low
assert min(extent)>.001 and max(extent)<=8,'模型整体尺寸超出范围'
shift=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
for ob in objects:ob.location-=shift
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(work/'model.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_morph=False,export_lights=False,export_cameras=False,export_yup=True)
# Keep an editable source before adding render-only camera and lights.
bpy.ops.wm.save_as_mainfile(filepath=str(work/'source.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene.world.color=(.35,.35,.35)
center=Vector((0,0,extent.z/2));radius=max(extent)
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=radius*1.9;scene.camera=camera
for position,power in [((3,-4,5),700),((-3,2,4),450)]:
    bpy.ops.object.light_add(type='AREA',location=center+Vector(position)*radius);light=bpy.context.object;light.data.energy=power*radius*radius;light.data.shape='DISK';light.data.size=radius*4;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
for name,direction in [('front',(3,-4,2.8)),('back',(-3,4,2.8))]:
    camera.location=center+Vector(direction)*radius;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(work/(name+'.png'));bpy.ops.render.render(write_still=True)
(work/'report.json').write_text(json.dumps(dict(parts=len(objects),blender_version=bpy.app.version_string,size=list(extent))))
print('PLAYSEED_PROP_OK')
