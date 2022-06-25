extends KinematicBody

const CAMERA_HEIGHT_STANDING = 1.6
const CAMERA_HEIGHT_DUCKED = 0.7
const TIME_TO_DUCK = 0.4

export var acceleration = 1.66
export var friction = 0.3
export var gravity = 9.8
export var jump_force = 10.0
export(NodePath) var head = null

# Not used in this script, but might be useful for child nodes because
# this controller will most likely be on the root
export(NodePath) var terrain = null

onready var _camera = $Camera
onready var _collision_shape = $CollisionShape
onready var _mesh_instance = $MeshInstance

var _duck_time: float = 0.0
var _fully_ducking: bool = false
var _in_duck: bool = false # in process of ducking
var _velocity = Vector3()
var _head = null
var _box_mover = VoxelBoxMover.new()
var initial_load_done: bool = false


func _ready():
	_head = get_node(head)

func _process(_delta):
	DDD.set_text("FPS", Engine.get_frames_per_second());
	DDD.set_text("On floor", is_on_floor());
	DDD.set_text("On wall", is_on_wall());
	DDD.set_text("On ceiling", is_on_ceiling());
	if !initial_load_done:
		var tasks = VoxelServer.get_stats().get("tasks")
		if tasks.generation == 0 and tasks.meshing == 0 and tasks.main_thread == 0 and tasks.streaming == 0:
			initial_load_done = true
				
	reduce_timers(_delta)
	set_duck_camera()

func set_duck_camera():
	# TODO only set if not scrolled away
	#if _fully_ducking:
	#	_camera.translation.y = CAMERA_HEIGHT_DUCKED
	#	return
	
	if !_in_duck:
		_camera.translation.y = CAMERA_HEIGHT_STANDING
		return
	
	var time = max(0.0, (1.0 - _duck_time / 1000.0))
	var _duck_fraction = player_move_spline_fraction(time, ( 1.0 / TIME_TO_DUCK ))
	_camera.translation.y = _duck_fraction * CAMERA_HEIGHT_DUCKED + (1-_duck_fraction) * CAMERA_HEIGHT_STANDING

func _physics_process(delta):
	if !initial_load_done:
		return
	player_move(delta)
	
	if is_on_floor() and Input.is_action_pressed("jump"):
		_velocity.y = jump_force
	
	var _result = move_and_slide(_velocity, Vector3.UP)

func reduce_timers(delta: float):
	if (_duck_time > 0):
		_duck_time = max(0, _duck_time - delta*1000)

func player_move(delta):
	# Todo: Handle water code, ladder code, spectator mode etc.
	player_move_duck()
	player_move_add_gravity(delta)
	player_move_friction()
	if is_on_floor():
		player_move_accelerate()

func player_move_duck():
	if !(Input.is_action_pressed("duck") or _in_duck or _fully_ducking):
		# Nothing to do
		return

	if !Input.is_action_pressed("duck"):
		# Try to unduck
		player_move_unduck()
		return

	if Input.is_action_just_pressed("duck") and !_fully_ducking:
		_duck_time = 1000
		_in_duck = true

	if _in_duck:
		var on_floor = is_on_floor()
		# Finish ducking if duck time is over or player is not on floor
		if (_duck_time / 1000.0 <= ( 1.0 - TIME_TO_DUCK ) ) || ( !on_floor ):
			_collision_shape.shape.extents.y = 0.45
			_collision_shape.translation.y = 1.35
			_mesh_instance.mesh.size.y = 0.9
			_mesh_instance.translation.y = 1.35
			if (on_floor):
				# if player was on floor, teleport down to stay on floor
				move_and_collide(Vector3(0, -0.9, 0))

			#Working version without duck-jump:
			#_collision_shape.shape.extents.y = 0.45
			#_collision_shape.translation.y = 0.45
			#_mesh_instance.mesh.size.y = 0.9
			#_mesh_instance.translation.y = 0.45
			
			_fully_ducking = true
			_in_duck = false

func player_move_spline_fraction(value: float, scale: float):
	var valueScaled = scale * value;
	var valueSquared = valueScaled * valueScaled
	return 3 * valueSquared - 2 * valueSquared * valueScaled;
	
func player_move_unduck():
	if test_move(transform, Vector3(0, 0.9, 0)):
		# no room to stand up
		return
	
	# For working version without duck jump, just comment out the move_and_collide below:
	move_and_collide(Vector3(0, 0.9, 0))
	_collision_shape.shape.extents.y = 0.9
	_collision_shape.translation.y = 0.9
	_mesh_instance.mesh.size.y = 1.8
	_mesh_instance.translation.y = 0.9

	
	_duck_time = 0
	_fully_ducking = false
	_in_duck = false

func player_move_add_gravity(delta):
	# Todo: check for water jump time
	_velocity.y -= gravity * delta

func player_move_friction():
	if !is_on_floor():
		return
	# Add friction
	_velocity.x = lerp(_velocity.x, 0, friction)
	_velocity.z = lerp(_velocity.z, 0, friction)

func player_move_accelerate():
	var forward = _head.get_transform().basis.z.normalized()
	forward = Plane(Vector3(0, 1, 0), 0).project(forward)
	var right = _head.get_transform().basis.x.normalized()
	
	var motor = Vector3()
	
	if Input.is_action_pressed("forward"):
		motor -= forward
	if Input.is_action_pressed("back"):
		motor += forward
	if Input.is_action_pressed("moveleft"):
		motor -= right
	if Input.is_action_pressed("moveright"):
		motor += right
	
	motor = motor.normalized() * acceleration
	
	_velocity.x += motor.x
	_velocity.z += motor.z
