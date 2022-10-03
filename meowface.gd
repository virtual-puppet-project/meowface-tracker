extends TrackingBackendTrait

const ConfigTrackerAddress: String = "MEOWFACE_TRACKER_ADDRESS"

const EMPTY_VEC3_DICT := {"x": 0.0, "y": 0.0, "z": 0.0}

class MeowFaceData:
	var has_data := false
	
	var blend_shapes := {}

	var head_rotation := Vector3.ZERO
	var head_position := Vector3.ZERO

	var left_eye_rotation := Vector3.ZERO
	var right_eye_rotation := Vector3.ZERO

	func set_blend_shape(name: String, value: float) -> void:
		blend_shapes[name] = value

	func set_head_rotation(data: Dictionary) -> void:
		head_rotation = Vector3(data.y, data.x, -data.z)

	func set_head_position(data: Dictionary) -> void:
		head_position = Vector3(data.y, data.x, -data.z)

	func set_left_eye_rotation(data: Dictionary) -> void:
		left_eye_rotation = Vector3(-data.x, -data.y, data.z) / 100.0

	func set_right_eye_rotation(data: Dictionary) -> void:
		right_eye_rotation = Vector3(-data.x, -data.y, data.z) / 100.0
var mf_data := MeowFaceData.new()

var logger := Logger.new(get_name())

var client: PacketPeerUDP
var server_poll_interval: int = 10

var stop_reception := false

var receive_thread: Thread

#-----------------------------------------------------------------------------#
# Builtin functions                                                           #
#-----------------------------------------------------------------------------#

func _init() -> void:
	start_receiver()

#-----------------------------------------------------------------------------#
# Connections                                                                 #
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Private functions                                                           #
#-----------------------------------------------------------------------------#

func _perform_reception() -> void:
	while not stop_reception:
		_receive()
		OS.delay_msec(server_poll_interval)

func _receive() -> void:
	client.put_packet(JSON.print({
		"messageType": "iOSTrackingDataRequest", # HMMMM
		"time": 1.0,
		"sentBy": "vpuppr",
		"ports": [
			21412
		]
	}).to_utf8())
	
	if client.get_available_packet_count() < 1:
		return
	if client.get_packet_error() != OK:
		return
	
	var packet := client.get_packet()
	if packet.size() < 1:
		return

	var data: Dictionary = parse_json(packet.get_string_from_utf8())

	mf_data.has_data = data.get("FaceFound", false)
	mf_data.set_head_position(data.get("Position", EMPTY_VEC3_DICT))
	mf_data.set_head_rotation(data.get("Rotation", EMPTY_VEC3_DICT))
	mf_data.set_left_eye_rotation(data.get("EyeLeft", EMPTY_VEC3_DICT))
	mf_data.set_right_eye_rotation(data.get("EyeRight", EMPTY_VEC3_DICT))
	for key in data.get("BlendShapes", []):
		mf_data.set_blend_shape(key.k, key.v)

#-----------------------------------------------------------------------------#
# Public functions                                                            #
#-----------------------------------------------------------------------------#

func get_name() -> String:
	return tr("MEOWFACE_TRACKER_NAME")

func start_receiver() -> void:
	logger.info("Starting receiver")

	var address: String = AM.cm.get_data(ConfigTrackerAddress)
	var port: int = 21412
	
	client = PacketPeerUDP.new()
	client.set_broadcast_enabled(true)
	client.set_dest_address(address, port)
	client.listen(port)

	stop_reception = false

	receive_thread = Thread.new()
	receive_thread.start(self, "_perform_reception")

func stop_receiver() -> void:
	if stop_reception:
		return

	logger.info("Stopping face tracker")

	stop_reception = true

	if receive_thread != null and receive_thread.is_active():
		receive_thread.wait_to_finish()
		receive_thread = null
	
	if client != null and client.is_connected_to_host():
		client.close()
		client = null

func set_offsets() -> void:
	stored_offsets.translation_offset = mf_data.head_position
	stored_offsets.rotation_offset = mf_data.head_rotation
	stored_offsets.left_eye_gaze_offset = mf_data.left_eye_rotation
	stored_offsets.right_eye_gaze_offset = mf_data.right_eye_rotation

func has_data() -> bool:
	return mf_data.has_data

func apply(interpolation_data: InterpolationData, model: PuppetTrait) -> void:
	interpolation_data.bone_translation.target_value = stored_offsets.translation_offset - mf_data.head_position
	interpolation_data.bone_rotation.target_value = stored_offsets.rotation_offset - mf_data.head_rotation

	interpolation_data.left_gaze.target_value = stored_offsets.left_eye_gaze_offset - mf_data.left_eye_rotation
	interpolation_data.right_gaze.target_value = stored_offsets.right_eye_gaze_offset - mf_data.right_eye_rotation
	
	for key in mf_data.blend_shapes.keys():
		match key:
			"eyeBlinkLeft":
				interpolation_data.right_blink.target_value = 1.0 - mf_data.blend_shapes[key]
			"eyeBlinkRight":
				interpolation_data.left_blink.target_value = 1.0 - mf_data.blend_shapes[key]
			_:
				for mesh_instance in model.skeleton.get_children():
					mesh_instance.set("blend_shapes/%s" % key, mf_data.blend_shapes[key])
