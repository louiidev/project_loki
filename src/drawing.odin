package main
import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"

MAX_QUADS :: 8000

state: struct {
	pass_action: sg.Pass_Action,
	pip:         sg.Pipeline,
	bind:        sg.Bindings,
	rx, ry:      f32,
}

Vertex :: struct {
	pos:   Vector2,
	color: Vector4,
	uv:    Vector2,
}

Quad :: [4]Vertex
DEFAULT_UV :: v4{0, 0, 1, 1}

GfxFilterMode :: enum {
	NEAREST,
	LINEAR,
}

QuadType :: enum {
	REGULAR,
	TEXT,
	CIRCLE,
}

GfxShaderExtension :: struct {
	shader_id: u32,
}


DrawQuad :: struct {
	size:   Vector2,
	color:  Vector4,
	uv:     [4]Vector2,
	img_id: ImageId,
}


DrawFrame :: struct {
	projection:       Matrix4,
	camera_xform:     Matrix4,
	textures:         [MAX_QUADS]sg.Image,
	quads:            [MAX_QUADS]Quad,
	quad_count:       int,
	shader_extension: sg.Pipeline,
}
draw_frame: DrawFrame


default_pipeline: sg.Pipeline
default_image: sg.Image
default_sampler: sg.Sampler

vbo: sg.Buffer
ibo: sg.Buffer

gfx_init :: proc() {

	default_sampler = sg.make_sampler({})

	// make the vertex buffer
	state.bind.vertex_buffers[0] = sg.make_buffer(
		{usage = .DYNAMIC, size = size_of(Quad) * len(draw_frame.quads)},
	)

	// make & fill the index buffer
	index_buffer_count :: MAX_QUADS * 6
	indices: [index_buffer_count]u16
	i := 0
	for i < index_buffer_count {
		// vertex offset pattern to draw a quad
		// { 0, 1, 2,  0, 2, 3 }
		indices[i + 0] = auto_cast ((i / 6) * 4 + 0)
		indices[i + 1] = auto_cast ((i / 6) * 4 + 1)
		indices[i + 2] = auto_cast ((i / 6) * 4 + 2)
		indices[i + 3] = auto_cast ((i / 6) * 4 + 0)
		indices[i + 4] = auto_cast ((i / 6) * 4 + 2)
		indices[i + 5] = auto_cast ((i / 6) * 4 + 3)
		i += 6
	}

	state.bind.index_buffer = sg.make_buffer(
		{type = .INDEXBUFFER, data = {ptr = &indices, size = size_of(indices)}},
	)

	state.bind.samplers[SMP_default_sampler] = sg.make_sampler({})

	// default pass action
	state.pass_action = {
		colors = {0 = {load_action = .CLEAR, clear_value = {0, 0, 0, 1}}},
	}


	pipeline_desc: sg.Pipeline_Desc = {
		shader = sg.make_shader(quad_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		layout = {
			attrs = {
				ATTR_quad_position = {format = .FLOAT2},
				ATTR_quad_color0 = {format = .FLOAT4},
				ATTR_quad_uv0 = {format = .FLOAT2},
			},
		},
	}


	blend_state: sg.Blend_State = {
		enabled          = true,
		src_factor_rgb   = .SRC_ALPHA,
		dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
		op_rgb           = .ADD,
		src_factor_alpha = .ONE,
		dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
		op_alpha         = .ADD,
	}


	pipeline_desc.colors[0] = {
		blend = blend_state,
	}


	state.pip = sg.make_pipeline(pipeline_desc)
}


draw_quad_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	img_id: ImageId = .nil,
	uv: Vector4 = DEFAULT_UV,
	col: Vector4 = COLOR_WHITE,
) {
	draw_quad_xform_in_frame(
		{size = size, uv = {uv.xy, uv.xw, uv.zw, uv.zy}, color = col, img_id = img_id},
		xform,
		&draw_frame,
	)
}

draw_quad_center_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	img_id: ImageId = .nil,
	uv: Vector4 = DEFAULT_UV,
	col: Vector4 = COLOR_WHITE,
) {
	xform := xform * linalg.matrix4_translate(Vector3{-size.x * 0.5, -size.y * 0.5, 0.0})
	draw_quad_xform_in_frame(
		{size = size, uv = {uv.xy, uv.xw, uv.zw, uv.zy}, color = col, img_id = img_id},
		xform,
		&draw_frame,
	)
}


draw_quad_xform_in_frame :: proc(quad: DrawQuad, xform: Matrix4, frame: ^DrawFrame) {
	if draw_frame.quad_count >= MAX_QUADS {
		assert(false)
		return
	}

	uv0 := quad.uv
	default_uv: [4]Vector2 = {DEFAULT_UV.xy, DEFAULT_UV.xw, DEFAULT_UV.zw, DEFAULT_UV.zy}
	if quad.uv == default_uv {
		atlas_uvs := images[quad.img_id].atlas_uvs
		uv0 = {atlas_uvs.xy, atlas_uvs.xw, atlas_uvs.zw, atlas_uvs.zy}
	}


	world_to_clip := draw_frame.projection * draw_frame.camera_xform * xform

	verts := cast(^[4]Vertex)&draw_frame.quads[draw_frame.quad_count]
	draw_frame.quad_count += 1

	verts[0].pos = (world_to_clip * v4{0, 0, 0.0, 1.0}).xy
	verts[1].pos = (world_to_clip * Vector4{0, quad.size.y, 0.0, 1.0}).xy
	verts[2].pos = (world_to_clip * Vector4{quad.size.x, quad.size.y, 0.0, 1.0}).xy
	verts[3].pos = (world_to_clip * Vector4{quad.size.x, 0, 0.0, 1.0}).xy
	verts[0].color = quad.color
	verts[1].color = quad.color
	verts[2].color = quad.color
	verts[3].color = quad.color

	verts[0].uv = uv0[0]
	verts[1].uv = uv0[1]
	verts[2].uv = uv0[2]
	verts[3].uv = uv0[3]


}


gfx_render_draw_frame :: proc(frame: ^DrawFrame) {
	number_of_quads := frame.quad_count

	if (number_of_quads == 0) {
		return
	}

	state.bind.images[IMG_tex0] = atlas.sg_image

	// state.bind.images[0] = draw_call.texture
	sg.update_buffer(
		state.bind.vertex_buffers[0],
		{ptr = &draw_frame.quads[0], size = size_of(Quad) * len(draw_frame.quads)},
	)

	sg.begin_pass({action = state.pass_action, swapchain = sglue.swapchain()})
	sg.apply_pipeline(state.pip)
	sg.apply_bindings(state.bind)

	sg.draw(0, 6 * draw_frame.quad_count, 1)
	sg.end_pass()
}


gfx_update :: proc() {
	if (!sapp.isvalid()) {
		return
	}

	// Clear window & render global draw frame to window
	gfx_render_draw_frame(&draw_frame)
	sg.commit()

	draw_frame_reset(&draw_frame)

}

draw_frame_reset :: proc(frame: ^DrawFrame) {
	using runtime, linalg

	memset(&draw_frame, 0, size_of(draw_frame))
	draw_frame.shader_extension = default_pipeline

	pixel_width: f32 = 320
	pixel_height: f32 = 180

	frame.projection = matrix_ortho3d_f32(
		pixel_width * -0.5,
		pixel_width * 0.5,
		pixel_height * -0.5,
		pixel_height * 0.5,
		-1,
		1,
	)
	frame.camera_xform = Matrix4(1)
}
