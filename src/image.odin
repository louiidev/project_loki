package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"

import sg "../sokol/gfx"
import stbi "vendor:stb/image"
import stbrp "vendor:stb/rect_pack"

Image_Id :: enum {
	nil,
	player,
	projectiles,
}

Image_Column_Rows_Count := [Image_Id][2]int {
	.nil         = {0, 0},
	.player      = {7, 2},
	.projectiles = {3, 2},
}


Image :: struct {
	width, height:    i32,
	data:             [^]byte,
	atlas_x, atlas_y: int, // probs not useful
	atlas_uvs:        Vector4,
}
images: [128]Image
blank: []byte = {255, 255, 255, 255}

init_images :: proc() {
	using fmt

	img_dir := "./assets/sprites/"

	highest_id := 0
	// buffer: [^]byte // Pointer to a dynamic array of bytes
	// image_data := make([^]byte, 4) // Allocate a dynamic array of 10 bytes
	// // // defer free(buffer)

	// image_data[0] = 255 // Red
	// image_data[1] = 255 // Green
	// image_data[2] = 255 // Blue
	// image_data[3] = 255 // Alpha
	images[Image_Id.nil] = Image {
		width  = 1,
		height = 1,
		data   = raw_data(blank),
	}


	for img_name, id in Image_Id {
		if id == 0 {continue}

		if id > highest_id {
			highest_id = id
		}

		path := tprint(img_dir, img_name, ".png", sep = "")
		img, succ := load_image_from_disk(path)
		if !succ {
			fmt.println("failed to load image:", img_name)
			continue
		}

		images[id] = img
	}
	pack_images_into_atlas()

	//images[0].atlas_uvs = {0.99, 0.99, 1.0, 1.0}
}


// load_white_image :: proc() -> (Image, bool) {

// 	blank: []byte = {255, 255, 255, 255}

// 	img_data := stbi.write_png_to_func()(
// 		raw_data(blank),
// 		auto_cast len(blank),
// 		&1,
// 		&1,
// 		&channels,
// 		4,
// 	)
// 	if img_data == nil {
// 		fmt.println("stbi load failed, invalid image?")
// 		return {}, false
// 	}

// 	ret: Image
// 	ret.width = 1
// 	ret.height = 1
// 	ret.data = img_data

// 	return ret, true
// }

load_image_from_disk :: proc(path: string) -> (Image, bool) {
	stbi.set_flip_vertically_on_load(1)

	png_data, succ := os.read_entire_file(path)
	if !succ {
		fmt.println("read file failed")
		return {}, false
	}

	width, height, channels: i32
	img_data := stbi.load_from_memory(
		raw_data(png_data),
		auto_cast len(png_data),
		&width,
		&height,
		&channels,
		4,
	)
	if img_data == nil {
		fmt.println("stbi load failed, invalid image?")
		return {}, false
	}

	ret: Image
	ret.width = width
	ret.height = height
	ret.data = img_data

	fmt.println(ret)

	return ret, true
}

Atlas :: struct {
	w, h:     int,
	sg_image: sg.Image,
}
atlas: Atlas
// We're hardcoded to use just 1 atlas now since I don't think we'll need more
// It would be easy enough to extend though. Just add in more texture slots in the shader
pack_images_into_atlas :: proc() {

	// 8192 x 8192 is the WGPU recommended max I think
	atlas.w = 128
	atlas.h = 128

	cont: stbrp.Context
	nodes: [128]stbrp.Node // #volatile with atlas.w
	stbrp.init_target(&cont, auto_cast atlas.w, auto_cast atlas.h, &nodes[0], auto_cast atlas.w)

	rects: [dynamic]stbrp.Rect
	for img, id in images {
		if img.width == 0 {
			continue
		}
		append(
			&rects,
			stbrp.Rect{id = auto_cast id, w = auto_cast img.width, h = auto_cast img.height},
		)
	}

	succ := stbrp.pack_rects(&cont, &rects[0], auto_cast len(rects))
	if succ == 0 {
		assert(false, "failed to pack all the rects, ran out of space?")
	}

	// allocate big atlas
	raw_data, err := mem.alloc(atlas.w * atlas.h * 4)
	defer mem.free(raw_data)
	mem.set(raw_data, 0, atlas.w * atlas.h * 4)

	// copy rect row-by-row into destination atlas
	for rect in rects {
		img := &images[rect.id]

		// copy row by row into atlas
		for row in 0 ..< rect.h {
			src_row := mem.ptr_offset(&img.data[0], row * rect.w * 4)
			dest_row := mem.ptr_offset(
				cast(^u8)raw_data,
				((rect.y + row) * auto_cast atlas.w + rect.x) * 4,
			)
			mem.copy(dest_row, src_row, auto_cast rect.w * 4)
		}

		// yeet old data
		if (rect.id != auto_cast Image_Id.nil) {stbi.image_free(img.data)}
		img.data = nil

		img.atlas_x = auto_cast rect.x
		img.atlas_y = auto_cast rect.y

		img.atlas_uvs.x = cast(f32)img.atlas_x / cast(f32)atlas.w
		img.atlas_uvs.y = cast(f32)img.atlas_y / cast(f32)atlas.h
		img.atlas_uvs.z = img.atlas_uvs.x + cast(f32)img.width / cast(f32)atlas.w
		img.atlas_uvs.w = img.atlas_uvs.y + cast(f32)img.height / cast(f32)atlas.h
	}

	stbi.write_png(
		"atlas.png",
		auto_cast atlas.w,
		auto_cast atlas.h,
		4,
		raw_data,
		4 * auto_cast atlas.w,
	)


	// setup image for GPU
	desc: sg.Image_Desc
	desc.width = auto_cast atlas.w
	desc.height = auto_cast atlas.h
	desc.pixel_format = .RGBA8
	desc.data.subimage[0][0] = {
		ptr  = raw_data,
		size = auto_cast (atlas.w * atlas.h * 4),
	}
	atlas.sg_image = sg.make_image(desc)
	if atlas.sg_image.id == sg.INVALID_ID {
		fmt.println("failed to make image")
	}
}


get_frame_uvs :: proc(sprite_id: Image_Id, sprite_index: Vector2, frame_size: Vector2) -> Vector4 {

	row_column_data := Image_Column_Rows_Count[sprite_id]

	// We want to reverse the y sprite index since we need to flip the image on load
	sprite_index_y: f32 = f32(0 + max(row_column_data.y - 1)) - sprite_index.y


	sprite := images[sprite_id]
	// Convert sprite's UV coordinates to pixel coordinates
	x := int(sprite.atlas_uvs.x * f32(atlas.w))
	y := int(sprite.atlas_uvs.y * f32(atlas.h))

	// Calculate the pixel coordinates for the top-left corner of the frame
	frame_x := x + auto_cast (sprite_index.x * frame_size.x)
	frame_y := y + auto_cast (sprite_index_y * frame_size.y)

	// Convert back to UV coordinates
	left := f32(frame_x) / f32(atlas.w)
	top := f32(frame_y) / f32(atlas.h)
	right := f32(frame_x + auto_cast frame_size.x) / f32(atlas.w)
	bottom := f32(frame_y + auto_cast frame_size.y) / f32(atlas.h)

	return Vector4{left, top, right, bottom}
}
