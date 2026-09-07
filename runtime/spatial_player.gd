extends CharacterBody3D

var direction := Vector2.ZERO
var speed := 3.0
var enabled := true

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.3
	shape.shape = capsule
	shape.position.y = 0.65
	add_child(shape)
	var visible_body = MeshInstance3D.new()
	var mesh_shape = CapsuleMesh.new()
	mesh_shape.radius = 0.32
	mesh_shape.height = 1.3
	visible_body.mesh = mesh_shape
	visible_body.position.y = 0.65
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("ec955e")
	material.roughness = 0.9
	visible_body.material_override = material
	add_child(visible_body)

func _physics_process(delta: float) -> void:
	var axis = direction.limit_length(1.0) if enabled else Vector2.ZERO
	velocity.x = axis.x * speed
	velocity.z = axis.y * speed
	velocity.y = 0.0 if is_on_floor() else maxf(velocity.y - 18 * delta, -20)
	move_and_slide()

func reset_at(point: Vector2) -> void:
	position = Vector3(point.x, 0.02, point.y)
	velocity = Vector3.ZERO
	direction = Vector2.ZERO
	enabled = true
