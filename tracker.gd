extends TrackingBackendTrait

const EMPTY_VEC3_DICT := {"x": 0.0, "y": 0.0, "z": 0.0}

var tracking_data := {}

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
	if client.put_packet(JSON.print({
				"messsageType": "iOSTrackingDataRequest",
				"time": 1.0,
				"sentBy": "vpuppr",
				"ports": [
					21412
				]
			}).to_utf8()) != OK:
		logger.error("Unable to send packet")
	
	var packet := client.get_packet()
	if packet.size() < 1:
		return

	tracking_data = parse_json(packet.get_string_from_utf8())

#-----------------------------------------------------------------------------#
# Public functions                                                            #
#-----------------------------------------------------------------------------#

func get_name() -> String:
	return tr("MEOWFACE_TRACKER_NAME")

func start_receiver() -> void:
	# TODO many of these values are stubs

	logger.info("Starting receiver")

	var address: String = "192.168.88.229"
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
	
	if client.is_connected_to_host():
		client.close()
		client = null

func set_offsets() -> void:
	pass

func has_data() -> bool:
	return true # TODO stub

func apply(interpolation_data: InterpolationData, model: PuppetTrait) -> void:
	if not tracking_data.get("FaceFound", false):
		return
	
	var tx: Dictionary = tracking_data.get("Position", EMPTY_VEC3_DICT)
	var rx: Dictionary = tracking_data.get("Rotation", EMPTY_VEC3_DICT)
	var eye_l: Dictionary = tracking_data.get("EyeLeft", EMPTY_VEC3_DICT)
	var eye_r: Dictionary = tracking_data.get("EyeRight", EMPTY_VEC3_DICT)
	
	interpolation_data.bone_translation.target_value = Vector3(-tx.y, -tx.x, tx.z)
	interpolation_data.bone_rotation.target_value = Vector3(-rx.y, -rx.x, rx.z)
	interpolation_data.left_gaze.target_value = Vector3(eye_l.z, eye_l.y, eye_l.x)
	interpolation_data.right_gaze.target_value = Vector3(eye_r.z, eye_r.y, eye_r.x)
	
	for data in tracking_data.get("BlendShapes", []):
		for mesh_instance in model.skeleton.get_children():
			mesh_instance.set("blend_shapes/%s" % data.k, data.v)
