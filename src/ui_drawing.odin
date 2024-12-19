package main
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
