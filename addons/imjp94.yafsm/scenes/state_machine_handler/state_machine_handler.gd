@tool
class_name StateMachineHandler
extends Node

## The state machine that this should reflect.
## [br]
## If left **null**, searches for a `StateMachinePlayer` in its children.
@export var _state_machine_player: StateMachinePlayer

func _ready() -> void:
	if not Engine.is_editor_hint():
		if _state_machine_player == null:
			push_warning('StateMachineHandler: _state_machine_player is null!')


func _enter_tree() -> void:
	if Engine.is_editor_hint():
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


func _on_child_entered_tree(child: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if child is StateMachinePlayer and _state_machine_player == null:
		_state_machine_player = child as StateMachinePlayer


func _on_child_exited_tree(child: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if child == _state_machine_player and _state_machine_player != null:
		_state_machine_player = null
		_search_for_state_machine_player.call_deferred()



