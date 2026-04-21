@tool
extends EditorScenePostImport
class_name GoBlendScenePostImport

const V_EXTRAS = "extras"
const V_METADATA_NAME = "goblend"

const V_LIST = "list"

const V_COLLISIONS = "collisions"
const V_GEOMETRY = "geometry"
const V_VISUAL_LAYERS = "layers"

const V_COLLISION_ONLY = "collision_only"

const V_COLLISION_NAME = "name"
const V_COLLISION_TYPE = "type"
const V_COLLISION_SHAPE = "shape"
const V_COLLISION_COLOR = "color"
const V_COLLISION_LAYER = "layer"
const V_COLLISION_MASK = "mask"

const V_CAST_SHADOW = "cast_shadow"
const V_GI_MODE = "gi_mode"
const V_LIGHTMAP_TEXEL_SCALE = "lightmap_texel_scale"

const V_MATERIAL_UNSHADED = "shade_mode"

var COLLISION_TYPE := [
	Area3D,
	StaticBody3D,
	RigidBody3D,
	CharacterBody3D
]

enum CollisionShape {
	TRIMESH, # Concave
	CONVEX,
	BOUNDARIES
}

func _get_goblend(node: Node) -> Dictionary:
	return node.get_meta(V_EXTRAS, {}).get(V_METADATA_NAME, {})

func _post_import(scene: Node) -> Object:
	iterate(scene)
	return scene
	
func iterate(node: Node):
	if node == null:
		return
	
	iterate_node(node)
	for child in node.get_children():
		iterate(child)

#region NODE

func iterate_node(node: Node):
	if not node is Node3D: return
	var node3d := node as Node3D
	
	var extras: Dictionary = node3d.get_meta(V_EXTRAS, {})
	if extras.is_empty(): return
	
	var goblend: Dictionary = extras.get(V_METADATA_NAME, {})
	if goblend.is_empty(): return
	
	iterate_node_collisions(node3d, goblend.get(V_COLLISIONS, {}))
	iterate_node_geometry( node3d, goblend.get(V_GEOMETRY, {}))
	iterate_node_visual(   node3d, goblend.get(V_VISUAL_LAYERS, []))
	iterate_node_mesh(     node3d, {})

func iterate_node_collisions(node3d: Node3D, data: Dictionary) -> void:
	var collisions: Array = data.get(V_LIST, [])
	
	if not node3d is MeshInstance3D: return
	var instance := node3d as MeshInstance3D
	var node_name: String = instance.name
	
	#var collision_only: bool                 = bool(data.get(V_COLLISION_ONLY, 0))
	for col_idx in range(collisions.size()):
		var collision_data: Dictionary = collisions[col_idx]
		
		var collision_node := _create_collision_object(collision_data, instance, instance.mesh)
		_name_collision(collision_node, collision_data, node_name)
		
		#if col_idx == 0: #TODO: Replace this with another property in blender
			#_replace_node(collision_node, instance)
		#else:
			#instance.add_child(collision_node)
			#collision_node.owner = instance.owner
	
	#if collision_only: #WARNING: Only works with one collision
		#instance.queue_free()

func _name_collision(node: CollisionObject3D, collision_data: Dictionary, parent_name: String) -> void:
	var collision_name: String     = collision_data.get(V_COLLISION_NAME, "")
	var class_small_name := node.get_class().replace("Static", "").replace("Rigid", "").replace("Character", "")
	node.name = "{0}{1}".format([parent_name, class_small_name if collision_name.is_empty() else collision_name])

func _create_collision_object(collision_data: Dictionary, parent: Node, mesh: Mesh) -> CollisionObject3D:
	var collision_type: int                  = collision_data.get(V_COLLISION_TYPE, 1)
	var collision_shape_type: CollisionShape = collision_data.get(V_COLLISION_SHAPE, 0)
	var _collision_color_arr: Array          = collision_data.get(V_COLLISION_COLOR, [0.0, 0.319, 0.448, 0.42])
	var collision_color: Color               = Color(_collision_color_arr[0], _collision_color_arr[1], _collision_color_arr[2], _collision_color_arr[3])
	var collision_layer: Array               = collision_data.get(V_COLLISION_LAYER, [1])
	var collision_mask: Array                = collision_data.get(V_COLLISION_MASK, [1])

	# Create collision object
	var collision_class = COLLISION_TYPE[collision_type]
	var collision_node: CollisionObject3D = collision_class.new()
	parent.add_child(collision_node)
	collision_node.owner = parent.owner

	# Assign layer & mask
	for i in range(1, min(collision_layer.size(), 32)):
		var value := bool(collision_layer[i-1])
		collision_node.set_collision_layer_value(i, value)
	for i in range(1, min(collision_mask.size(), 32)):
		var value := bool(collision_mask[i-1])
		collision_node.set_collision_mask_value(i, value)
	
	# Create collision shape
	var collision_shape := _create_collision_shape(mesh, collision_shape_type)
	collision_shape.debug_color = collision_color
	collision_shape.name = collision_shape.get_class()
	collision_node.add_child(collision_shape)
	collision_shape.owner = parent.owner
	
	return collision_node

func iterate_node_geometry(node3d: Node3D, data: Dictionary) -> void:
	if not node3d is GeometryInstance3D: return
	var geometry := node3d as GeometryInstance3D
	
	geometry.cast_shadow             = data.get(V_CAST_SHADOW, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	geometry.gi_mode                 = data.get(V_GI_MODE, GeometryInstance3D.GI_MODE_STATIC)
	geometry.gi_lightmap_texel_scale = data.get(V_LIGHTMAP_TEXEL_SCALE, 1.0)


func iterate_node_visual(node3d: Node3D, layers: Array) -> void:
	if not node3d is VisualInstance3D: return
	var instance := node3d as VisualInstance3D
	
	for i in range(1, min(layers.size(), 20)):
		var value := bool(layers[i-1])
		instance.set_layer_mask_value(i, value)

func iterate_node_mesh(node3d: Node3D, data: Dictionary) -> void:
	if not node3d is MeshInstance3D: return
	var instance := node3d as MeshInstance3D
	var mesh := instance.mesh
	
	for i in range(mesh.get_surface_count()):
		iterate_material(mesh.surface_get_material(i))

func _replace_root_node(node: Node3D, target: Node3D) -> void:
	var parent = target.get_parent()
	if parent == null: return
	
	var scene_root = parent.owner if parent.owner != null else parent
	var idx = target.get_index()
	var transform = target.transform
	
	target.owner = null
	parent.remove_child(target)
	
	parent.add_child(node)
	parent.move_child(node, idx)
	node.owner = scene_root
	node.transform = transform
	
	node.add_child(target)
	target.owner = scene_root
	target.transform = Transform3D.IDENTITY

func _create_collision_shape(mesh: Mesh, shape_type: CollisionShape) -> CollisionShape3D:
	if shape_type == CollisionShape.TRIMESH:
		return _create_trimesh(mesh)
	elif shape_type == CollisionShape.CONVEX:
		return _create_convex_shape(mesh)
	elif shape_type == CollisionShape.BOUNDARIES:
		return _create_boundaries_shape(mesh)
		
	return null

func _create_trimesh(mesh: Mesh) -> CollisionShape3D:
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = mesh.create_trimesh_shape()
	return collision_shape

func _create_convex_shape(mesh: Mesh) -> CollisionShape3D:
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = mesh.create_convex_shape()
	return collision_shape

func _create_boundaries_shape(mesh: Mesh) -> CollisionShape3D:
	var collision_shape = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	
	var aabb = mesh.get_aabb()
	box_shape.size = aabb.size
	
	collision_shape.shape = box_shape
	collision_shape.position = aabb.position + aabb.size/2
	
	return collision_shape

#endregion
#region MATERIAL
func iterate_material(material: Material) -> void:
	var extras: Dictionary = material.get_meta(V_EXTRAS, {})
	if extras.is_empty(): return
	
	var goblend: Dictionary = extras.get(V_METADATA_NAME, {})
	if goblend.is_empty(): return
	
	if material is BaseMaterial3D:
		iterate_base_material(material as BaseMaterial3D, goblend)

func iterate_base_material(material: BaseMaterial3D, data: Dictionary) -> void:
	material.shading_mode = data.get(V_MATERIAL_UNSHADED, 1)
#endregion
