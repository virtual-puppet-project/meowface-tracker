extends PanelContainer

const ConfigTrackerAddress: String = "MEOWFACE_TRACKER_ADDRESS"

var logger := Logger.new("MeowFaceGUI")

var regex: RegEx

func _init() -> void:
	var res := Safely.wrap(AM.cm.runtime_subscribe_to_signal(ConfigTrackerAddress))
	if res.is_err():
		logger.error(res)

	regex = RegEx.new()
	# https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
	if regex.compile("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$") != OK:
		logger.error("Unable to compile IPv4 regex, ip address checking will not work")
		regex.compile("[\\s\\S]")

	var sc := ScrollContainer.new()
	ControlUtil.all_expand_fill(sc)

	add_child(sc)

	var vbox := VBoxContainer.new()
	ControlUtil.h_expand_fill(vbox)

	sc.add_child(vbox)

	vbox.add_child(_usage())

	vbox.add_child(HSeparator.new())

	var toggle_tracking: Button = _toggle_tracking()
	vbox.add_child(_ip_address(toggle_tracking))

	vbox.add_child(HSeparator.new())

	vbox.add_child(toggle_tracking)

func _usage() -> Label:
	var r := Label.new()
	ControlUtil.h_expand_fill(r)
	r.autowrap = true

	r.text = tr("MEOWFACE_USAGE_LABEL_TEXT")

	return r

func _ip_address(toggle: Button) -> HBoxContainer:
	var r := HBoxContainer.new()
	ControlUtil.h_expand_fill(r)
	r.hint_tooltip = tr("MEOWFACE_IP_ADDRESS_HINT")

	var label := Label.new()
	ControlUtil.h_expand_fill(label)
	label.text = tr("MEOWFACE_IP_ADDRESS_LABEL_TEXT")
	label.hint_tooltip = tr("MEOWFACE_IP_ADDRESS_HINT")

	r.add_child(label)

	var line_edit := LineEdit.new()
	ControlUtil.h_expand_fill(line_edit)
	line_edit.text = AM.cm.get_data(ConfigTrackerAddress, "*")
	line_edit.hint_tooltip = tr("MEOWFACE_IP_ADDRESS_HINT")

	line_edit.connect("text_changed", self, "_on_ip_address_changed", [toggle])

	r.add_child(line_edit)

	return r

func _on_ip_address_changed(text: String, toggle: Button) -> void:
	if regex.search(text) == null:
		toggle.disabled = true
		return
	else:
		toggle.disabled = false
		AM.ps.publish(ConfigTrackerAddress, text)

func _toggle_tracking() -> Button:
	var r := Button.new()
	ControlUtil.h_expand_fill(r)

	r.text = tr("MEOWFACE_TOGGLE_TRACKING_START")
	r.hint_tooltip = tr("MEOWFACE_TOGGLE_TRACKING_BUTTON_HINT")
	r.focus_mode = Control.FOCUS_NONE
	r.connect("pressed", self, "_on_toggle_tracking", [r])

	return r

func _on_toggle_tracking(button: Button) -> void:
	var trackers = get_tree().current_scene.get("trackers")
	if typeof(trackers) != TYPE_DICTIONARY:
		logger.error("Incompatible runner, aborting")
		return

	var tracker: TrackingBackendTrait
	var found := false
	for i in trackers.values():
		if i is TrackingBackendTrait and i.get_name() == tr("MEOWFACE_TRACKER_NAME"):
			tracker = i
			found = true
			break
		
	if found:
		logger.debug("Stopping MeowFace tracker")

		tracker.stop_receiver()
		trackers.erase(tracker.get_name())

		button.text = tr("MEOWFACE_TOGGLE_TRACKING_START")
	else:
		logger.debug("Starting MeowFace tracker")

		var res: Result = Safely.wrap(AM.em.load_resource("MeowFace", "meowface.gd"))
		if res.is_err():
			logger.error(res)
			return

		var meowface_tracker = res.unwrap().new()

		trackers[meowface_tracker.get_name()] = meowface_tracker

		button.text = tr("MEOWFACE_TOGGLE_TRACKING_STOP")
	
	AM.ps.publish(Globals.TRACKER_TOGGLED, not found, tr("MEOWFACE_TRACKER_NAME"))
