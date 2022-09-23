extends PanelContainer

var logger := Logger.new("MeowFaceGUI")

func _init() -> void:
	var sc := ScrollContainer.new()
	ControlUtil.all_expand_fill(sc)

	add_child(sc)

	var vbox := VBoxContainer.new()
	ControlUtil.h_expand_fill(vbox)

	sc.add_child(vbox)

	vbox.add_child(_usage())

	vbox.add_child(_toggle_tracking())

func _usage() -> Label:
	var r := Label.new()
	ControlUtil.h_expand_fill(r)
	r.autowrap = true

	r.text = tr("MEOWFACE_USAGE_LABEL_TEXT")

	return r

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

		var res: Result = Safely.wrap(AM.em.load_resource("MeowFace", "tracker.gd"))
		if res.is_err():
			logger.error(res)
			return

		var meowface_tracker = res.unwrap().new()

		trackers[meowface_tracker.get_name()] = meowface_tracker

		button.text = tr("MEOWFACE_TOGGLE_TRACKING_STOP")
	
	AM.ps.publish(Globals.TRACKER_TOGGLED, not found, tr("MEOWFACE_TRACKER_NAME"))
