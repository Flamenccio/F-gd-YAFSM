@tool
class_name StateMachineHandler
extends Node

## The state machine that this should reflect.
## [br]
## If left **null**, searches for a `StateMachinePlayer` in its children.
@export var _state_machine_player: StateMachinePlayer

@export_group('Create behavior states')
## Create blank BehaviorStates to reflect the StateMachinePlayer.
@export_tool_button('Create BehaviorStates') var _create_behavior_states_button: Callable = _create_behavior_states
@export var _confirm: bool = false
@export var _create_mode: CreateStateMode = CreateStateMode.UPDATE

var active_state: BehaviorState = null
var _behavior_states: Dictionary

const ARCHIVE_NODE_NAME = '_Archive'
const SUPER_STATE_META = 'super_state'

enum CreateStateMode {
	## Moves all old behavior states to under an 'Old' node
	## and recreates the StateMachine with blank BehaviorStates.
	ARCHIVE,
	## Keeps all untouched nodes. Creates new BehaviorStates for new states
	## and removes existing BehaviorStates that associate to a deleted state.
	UPDATE,
	## Destroys all nodes and replaces them with new ones.
	REPLACE
}

func _ready() -> void:
	if not Engine.is_editor_hint():
		if _state_machine_player == null:
			push_error('[StateMachineHandler] _state_machine_player is null!')

		_behavior_states.clear()

		# Load states and supply callables
		for child in _get_children_recursive(self):
			if child is BehaviorState:
				var behavior = child as BehaviorState
				_behavior_states['{0}'.format({'0': get_path_to(child)})] = behavior
				behavior.set_state_machine_param = _state_machine_player.set_param
				behavior.get_state_machine_param = _state_machine_player.get_param

		# Check if all states are accounted for
		var states = _get_state_paths(_state_machine_player.state_machine)

		for state_path in states:
			if not _behavior_states.keys().has(state_path):
				push_error('[StateMachineHandler] does not have state "{0}"'.format({'0': state_path}))

		if _behavior_states.keys().size() > states:
			push_warning('[StateMachineHandler] has behavior states that do not correlate to any state machine state!')

		# Check if signals are connected
		if not _state_machine_player.transited.is_connected(_on_state_transited):
			_state_machine_player.transited.connect(_on_state_transited)
		if not _state_machine_player.updated.is_connected(_on_state_update):
			_state_machine_player.updated.connect(_on_state_update)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		# Connect to child changing signals, if necessary
		if not child_entered_tree.is_connected(_on_child_entered_tree):
			child_entered_tree.connect(_on_child_entered_tree)
		if not child_exiting_tree.is_connected(_on_child_exited_tree):
			child_exiting_tree.connect(_on_child_exited_tree)


func _search_for_state_machine_player() -> void:
	if Engine.is_editor_hint() and _state_machine_player == null:
		# Search in children
		var children = get_children()
		var index = children.find_custom(func(n: Node): return n is StateMachinePlayer)
		if index < 0:
			return
		_state_machine_player = children[index] as StateMachinePlayer
		print('[StateMachineHandler] using state machine ', _state_machine_player)
		# Connect to signals
		_state_machine_player.transited.connect(_on_state_transited)
		_state_machine_player.updated.connect(_on_state_update)


func _on_child_entered_tree(child: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if child is StateMachinePlayer and _state_machine_player == null:
		_state_machine_player = child as StateMachinePlayer
		print('[StateMachineHandler] using state machine ', _state_machine_player)
		# Connect to signals
		_state_machine_player.transited.connect(_on_state_transited)
		_state_machine_player.updated.connect(_on_state_update)


func _on_child_exited_tree(child: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if child == _state_machine_player and _state_machine_player != null:
		_state_machine_player.transited.disconnect(_on_state_transited)
		_state_machine_player.updated.disconnect(_on_state_update)
		_state_machine_player = null
		print('[StateMachineHandler] lost state machine')
		_search_for_state_machine_player.call_deferred()


func _create_behavior_states() -> void:
	if not Engine.is_editor_hint():
		push_error('[StateMachineHandler] cannot create states while in play mode')
		return
	if not _confirm:
		push_error('[StateMachineHandler] confirm button is false')
		return
	if _state_machine_player == null:
		push_error('[StateMachineHandler] no state machine found')
		return
	
	match _create_mode:
		CreateStateMode.ARCHIVE:
			_create_behavior_states_archive()
		CreateStateMode.UPDATE:
			_create_behavior_states_update()
		CreateStateMode.REPLACE:
			_create_behavior_states_replace()
		_:
			push_error('[StateMachineHandler] how did we get here')


func _create_behavior_states_archive() -> void:

	if not Engine.is_editor_hint():
		return

	var children = get_children()

	# Count other _Archive nodes
	var count = 0
	for child in children:
		if child.name.contains(ARCHIVE_NODE_NAME):
			count += 1
	var archive_name = '{0}{1}'.format({'0': ARCHIVE_NODE_NAME, '1': count})

	# Add new archive & move states
	var new_archive = Node.new()
	new_archive.name = archive_name
	add_child(new_archive)

	for child in children:
		var is_child_super_state = child.has_meta(SUPER_STATE_META)
		if child is not BehaviorState and not is_child_super_state:
			continue
		child.reparent(new_archive)

	_set_owner_recursive(get_tree().edited_scene_root, new_archive)
	_reconstruct_state_machine()
	print('[StateMachineHandler] done')


func _create_behavior_states_update() -> void:

	if not Engine.is_editor_hint():
		return

	var children = _get_children_recursive(self)
	var node_paths: Array[String]

	# Find paths behavior states
	for child in children:
		var child_is_behavior_state = child is BehaviorState
		if not child_is_behavior_state:
			continue
		node_paths.append('{0}'.format({'0': get_path_to(child)}))

	var state_paths = _get_state_paths(_state_machine_player.state_machine)

	_remove_deleted_states(node_paths, state_paths)
	_reconstruct_state_machine()
	_update_changed_states()
	print('[StateMachineHandler] done')


func _remove_deleted_states(node_paths: Array[String], state_paths: Array[String]) -> void:

	# Find deleted states
	var deleted = node_paths.duplicate()
	for state in state_paths:
		deleted.erase(state)
	
	for deleted_state in deleted:
		print('[StateMachineHandler] removed child ', deleted_state)
		get_node(deleted_state).free()


# Update nodes whose state changed from super state -> behavior state, or vice versa
func _update_changed_states() -> void:
	for child in _get_children_recursive(self):
		# Make behavior state into super state
		if child.get_children().size() > 0 and child is BehaviorState:
			var super_state = Node.new()
			super_state.name = child.name
			super_state.set_meta(SUPER_STATE_META, true)
			child.replace_by(super_state)
			print('[StateMachineHandler] converted behavior state {0} into super state'.format({'0': super_state.name}))
		# Make super state into behavior state
		elif child.get_children().size() == 0 and child.has_meta(SUPER_STATE_META):
			var behavior_state = BehaviorState.new()
			behavior_state.name = child.name
			child.replace_by(behavior_state)
			print('[StateMachineHandler] converted super state {0} into behavior state'.format({'0': behavior_state.name}))


func _create_behavior_states_replace() -> void:
	if not Engine.is_editor_hint():
		return
	var children = get_children()
	for child in children:
		if child.has_meta(SUPER_STATE_META) or child is BehaviorState:
			print('[StateMachineHandler] removed child ', child.name)
			child.free()
	_reconstruct_state_machine()
	print('[StateMachineHandler] done')


# Reads the associated state machine states and creates a tree
# of BehaviorStates accordingly
func _reconstruct_state_machine() -> void:
	if not Engine.is_editor_hint():
		return
	if _state_machine_player == null:
		return
	var state_machine := _state_machine_player.state_machine
	var state_paths: Array[String] = []

	# Get state paths
	var paths = _get_state_paths(state_machine)

	for path in paths:
		if has_node(path):
			continue
		_create_state_behavior(path)


## Returns an array of state paths.
## A nested state path appears as: 'A/B/C', where 'C' is
## the end state.
func _get_state_paths(state_machine: StateMachine) -> Array[String]:
	var states: Array[String] = []
	for key in state_machine.states.keys():
		var state = state_machine.states[key]
		if state is StateMachine:
			var nested_paths = _get_state_paths(state as StateMachine)
			for i in range(nested_paths.size()):
				nested_paths[i] = '{0}/{1}'.format({'0': key, '1': nested_paths[i]})
			states.append_array(nested_paths)
		else:
			states.append(key)
	return states


func _create_state_behavior(state_name: String) -> void:

	var split = state_name.split('/')
	var end_state = split[split.size() - 1]
	var current_path = ''
	var root = get_tree().edited_scene_root
	var last_node: Node = self

	for i in range(split.size()):

		# Construct the node path
		var current_node_name = split[i]

		if current_path == '':
			current_path = current_node_name
		else:
			current_path = '{0}/{1}'.format({'0': current_path, '1': current_node_name})

		# Does it exist
		if has_node(current_path):
			last_node = get_node(current_path)
			continue

		if current_node_name == end_state:
			print('[StateMachineHandler] create behavior state "{0}"'.format({'0': current_path}))
			var state = BehaviorState.new()
			state.name = end_state
			last_node.add_child(state)
			state.owner = root
			return
		else:
			print('[StateMachineHandler] create super state "{0}"'.format({'0': current_path}))
			var new_node = Node.new()
			new_node.name = current_node_name
			new_node.set_meta(SUPER_STATE_META, true)
			last_node.add_child(new_node)
			new_node.owner = root
			last_node = new_node


func _set_owner_recursive(owner: Node, target: Node) -> void:
	target.owner = owner
	for child in target.get_children():
		_set_owner_recursive(owner, child)


func _get_children_recursive(target: Node) -> Array[Node]:
	var result: Array[Node]
	var children = target.get_children()
	for child in children:
		result.append_array(_get_children_recursive(child))
	result.append_array(children)
	return result


func _on_state_transited(old_state: String, new_state: String) -> void:

	if Engine.is_editor_hint():
		return

	var old = _behavior_states[old_state]
	var new = _behavior_states[new_state]

	if old != null:
		old.exit_state()
		old.state_active = false

	new.enter_state()
	new.state_active = true
	active_state = new


func _on_state_update(_s: String, delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if active_state == null:
		return
	active_state.update_state(delta)

