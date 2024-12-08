
package main
import sapp "../sokol/app"
import "base:runtime"
import "core:fmt"


Inputs :: struct {
	button_down:                                                              [sapp.MAX_KEYCODES]bool,
	button_just_pressed:                                                      [sapp.MAX_KEYCODES]bool,
	mouse_down:                                                               [sapp.MAX_MOUSEBUTTONS]bool,
	mouse_just_pressed:                                                       [sapp.MAX_MOUSEBUTTONS]bool,
	mouse_pos, prev_mouse_pos, mouse_delta, mouse_down_pos, mouse_down_delta: Vector2,
	screen_mouse_pos, screen_mouse_down_pos, screen_mouse_down_delta:         Vector2,
	mouse_scroll_delta:                                                       Vector2,
}


inputs: Inputs
event_cb :: proc "c" (event: ^sapp.Event) {
	context = runtime.default_context()
	inputs.screen_mouse_pos.x = event.mouse_x
	inputs.screen_mouse_pos.y = auto_cast (sapp.height() - auto_cast event.mouse_y)
	// inputs.mouse_pos.x = event->mouse_x - graphics->viewport_pos.x
	// inputs.mouse_pos.y = event->mouse_y - graphics->viewport_pos.y

	using sapp.Event_Type
	#partial switch event.type {

	case .MOUSE_DOWN, .MOUSE_UP, .MOUSE_MOVE:
		if (event.type == .MOUSE_DOWN) {
			inputs.mouse_down_pos = inputs.mouse_pos
			inputs.screen_mouse_down_pos = inputs.screen_mouse_pos
			inputs.mouse_down[event.mouse_button] = true
		} else if (event.type == .MOUSE_UP) {
			inputs.mouse_down[event.mouse_button] = false
			inputs.mouse_just_pressed[event.mouse_button] = true
		} else if (event.type == .MOUSE_SCROLL) {
			inputs.mouse_scroll_delta = {event.scroll_x, event.scroll_y}
		}


	case .KEY_DOWN:
		inputs.button_down[event.key_code] = true

	case .KEY_UP:
		inputs.button_down[event.key_code] = false
		inputs.button_just_pressed[event.key_code] = true
	}
}


inputs_end_frame :: proc() {
	for i := 0; i < len(inputs.button_just_pressed); i += 1 {
		inputs.button_just_pressed[i] = false
	}

	for i := 0; i < len(inputs.mouse_just_pressed); i += 1 {
		inputs.mouse_just_pressed[i] = false
	}
}
