package main
import sapp "../sokol/app"
import "core:fmt"
import "core:math"
import "core:math/linalg"

draw_rect_bordered_center_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	border_size: f32,
	col: Vector4 = COLOR_WHITE,
	border_color: Vector4 = COLOR_WHITE,
) {
	border_size_v := size + border_size
	center_xform :=
		xform *
		linalg.matrix4_translate(Vector3{-border_size_v.x * 0.5, -border_size_v.y * 0.5, 0.0})
	draw_quad_xform_in_frame(
		{
			size = size + border_size,
			uv = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy},
			color = border_color,
			img_id = .nil,
		},
		center_xform,
		&draw_frame,
	)

	center_xform = xform * linalg.matrix4_translate(Vector3{-size.x * 0.5, -size.y * 0.5, 0.0})
	draw_quad_xform_in_frame(
		{
			size = size,
			uv = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy},
			color = col,
			img_id = .nil,
		},
		center_xform,
		&draw_frame,
	)
}

draw_rect_bordered_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	border_size: f32,
	col: Vector4 = COLOR_WHITE,
	border_color: Vector4 = COLOR_WHITE,
) {
	border_size_v := size + border_size
	border_xform :=
		xform * linalg.matrix4_translate(Vector3{-border_size * 0.5, -border_size * 0.5, 0.0})
	draw_quad_xform_in_frame(
		{
			size = size + border_size,
			uv = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy},
			color = border_color,
			img_id = .nil,
		},
		border_xform,
		&draw_frame,
	)

	draw_quad_xform_in_frame(
		{
			size = size,
			uv = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy},
			color = col,
			img_id = .nil,
		},
		xform,
		&draw_frame,
	)
}


BUTTON_BORDER_SIZE :: 8
BUTTON_COLOR: Vector4 : {0.5, 0.5, 0.5, 1}
BUTTON_HOVER_COLOR: Vector4 : {0.3, 0.3, 0.3, 1}
BUTTON_BORDER_COLOR: Vector4 : {1, 1, 1, 1}
BUTTON_DISABLED_COLOR: Vector4 : {0.1, 0.1, 0.1, 1.0}
bordered_button :: proc(
	position: Vector2,
	size: Vector2,
	text: string,
	font_size: f32,
	id: UiID,
	disabled: bool = false,
) -> bool {
	xform := transform_2d(position)


	color := BUTTON_COLOR
	if !disabled && aabb_contains(position, size, mouse_world_position) {
		ui_state.hover_id = id
		color = BUTTON_HOVER_COLOR
	}

	if !disabled && inputs.mouse_down[sapp.Mousebutton.LEFT] && ui_state.hover_id == id {
		ui_state.down_clicked_id = id
	}


	if disabled {
		color = BUTTON_DISABLED_COLOR
	}

	pressed := false

	if !disabled &&
	   ui_state.hover_id == id &&
	   !ui_state.click_captured &&
	   inputs.mouse_just_pressed[sapp.Mousebutton.LEFT] &&
	   ui_state.down_clicked_id == id {
		pressed = true
		ui_state.click_captured = true
	}


	draw_rect_bordered_center_xform(xform, size, BUTTON_BORDER_SIZE, color, BUTTON_BORDER_COLOR)


	draw_text_center_center(position, text, font_size)


	return pressed
}
