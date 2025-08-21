class_name BehaviorState
## Represents a node in a StateMachine.
##
## Extend from this class to write your own behaviors.
extends Node

## Is this state currently active?
## Try not to modify this.
var state_active: bool = false

## **Parameters:**[br]
## - `String`: string identifier of the state machine parameter[br]
## - `Variant`: new value of the state machine parameter[br]
## **NOTE**: you can also use the method `set_param` for clearer parameter hints.
var set_state_machine_param: Callable

## **Parameters:**[br]
## - `String`: string identifier of the state machine parameter[br]
## **Returns:**[br]
## - `Variant`: current value of the state machine paramter, or `null` if the paramter name is invalid.[br]
## **NOTE**: you can also use the method `get_param` for clearer parameter hints.
var get_state_machine_param: Callable

## Called once when the state machine enters the associated state.
## Override this method to implement your own behaviors.
func enter_state() -> void:
	return


## Called once when the state machine enters the associated state.
## Override this method to implement your own behaviors.[br]
## - `from`: the last active state
func enter_state_from(from: String) -> void:
	return


## Called once when the state machine exits the associated state.
## Override this method to implement your own behaviors.
func exit_state() -> void:
	return


## Called once when the state machine exits the associated state.
## Override this method to implement your own behaviors.[br]
## - `to`: the state the machine will enter next
func exit_state_to(to: String) -> void:
	return


## Called repeatedly, depending on the update method set in the `StateMachinePlayer`.
## Override this method to implement your own behaviors.
func update_state(delta: float) -> void:
	return


## Sets state machine parameter `param` to `value`.[br]
## Wrapper function for `set_state_machine_param` Callable; both have the same effect.
func set_param(param: String, value: Variant) -> void:
	set_state_machine_param.call(param, value)


## Gets state machine parameter `param`.[br]
## Wrapper function for `get_state_machine_param` Callable; both have the same effect.
func get_param(param: String) -> Variant:
	return get_state_machine_param.call(param)

