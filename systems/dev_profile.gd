extends RefCounted

const Guard = preload("res://systems/dev_guard.gd")
const SaveStore = preload("res://systems/save_store.gd")
const RunState = preload("res://systems/run_state.gd")

var normal_path := ""
var dev_path := ""
var baseline_path := ""
var active := false


func configure(path: String) -> void:
	normal_path = path
	dev_path = path + ".dev"
	baseline_path = path + ".dev.baseline"


func has_test_profile() -> bool:
	return Guard.authorized() and FileAccess.file_exists(dev_path)


func start_copy(run: RefCounted) -> bool:
	if not Guard.authorized() or active or run.save_path != normal_path or not run.save():
		return false
	var permanent: Dictionary = run.permanent.duplicate(true)
	var attempt: Dictionary = run.attempt.duplicate(true)
	if not SaveStore.save_data(permanent, attempt, baseline_path):
		return false
	if not SaveStore.save_data(permanent, attempt, dev_path):
		return false
	run.initialize(dev_path)
	active = true
	return true


func resume(run: RefCounted) -> bool:
	if not Guard.authorized() or active or not has_test_profile():
		return false
	run.initialize(dev_path)
	active = true
	return true


func restore_initial(run: RefCounted) -> bool:
	if not Guard.authorized() or not active:
		return false
	var payload: Dictionary = SaveStore.load_data(baseline_path)
	if payload.is_empty() or not SaveStore.save_data(payload.get("permanent", {}), payload.get("attempt", {}), dev_path):
		return false
	run.initialize(dev_path)
	return true


func reset_blank(run: RefCounted) -> bool:
	if not Guard.authorized() or not active:
		return false
	var fresh := RunState.new()
	fresh.permanent = fresh._default_permanent()
	fresh.attempt = {}
	if not SaveStore.save_data(fresh.permanent.duplicate(true), {}, baseline_path):
		return false
	if not SaveStore.save_data(fresh.permanent.duplicate(true), {}, dev_path):
		return false
	run.initialize(dev_path)
	return true


func return_normal(run: RefCounted) -> bool:
	if not Guard.authorized() or not active or run.save_path != dev_path or not run.save():
		return false
	run.initialize(normal_path)
	active = false
	return true
