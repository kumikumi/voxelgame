extends Spatial

export var sensitivity = 0.006
const MIN_ANGLE = -0.5*PI
const MAX_ANGLE = 0.5*PI
export var capture_mouse = true
export var distance = 0

var _yaw = 0
var _pitch = 0
var _offset = Vector3()


func _ready():
	_offset = get_translation()
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			if capture_mouse:
				# Capture the mouse
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		if event.button_index == BUTTON_WHEEL_UP:
			distance = max(distance - 1 - distance * 0.1, 0)
			update_rotations()
		
		elif event.button_index == BUTTON_WHEEL_DOWN:
			distance = max(distance + 1 + distance * 0.1, 0)
			update_rotations()
	
	elif event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED || not capture_mouse:
			# Get mouse delta
			var motion = event.relative
			
			# Add to rotations
			_yaw -= motion.x * sensitivity
			_pitch += motion.y * sensitivity
			
			# Clamp pitch
			var e = 0.0001
			if _pitch > MAX_ANGLE-e:
				_pitch = MAX_ANGLE-e
			elif _pitch < MIN_ANGLE+e:
				_pitch = MIN_ANGLE+e
			
			# Apply rotations
			update_rotations()
	
	elif event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_ESCAPE:
				# Get the mouse back
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
			elif event.scancode == KEY_I:
				var pos = get_translation()
				var fw = -transform.basis.z
				print("Position: ", pos, ", Forward: ", fw)


func update_rotations():
	set_translation(Vector3())
	set_rotation(Vector3(0, _yaw, 0))
	rotate(get_transform().basis.x.normalized(), -_pitch)
	set_translation(get_transform().basis.z * distance + _offset)


