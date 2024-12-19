package main

import sg "../sokol/gfx"
import "core:fmt"
import "core:mem"
import "core:os"
import stbi "vendor:stb/image"
import stbrp "vendor:stb/rect_pack"
import stbtt "vendor:stb/truetype"

char_count :: 96
font_bitmap_w :: 256 * 2
font_bitmap_h :: 256 * 2
Font :: struct {
	char_data: [char_count]stbtt.bakedchar,
	font_info: stbtt.fontinfo,
}
font: Font
font_image: sg.Image
DEFAULT_FONT_SIZE :: 14

init_fonts :: proc() {
	using stbtt

	bitmap, _ := mem.alloc(font_bitmap_w * font_bitmap_h)
	font_height := DEFAULT_FONT_SIZE
	path := "assets/fonts/m6x11.ttf"
	ttf_data, err := os.read_entire_file(path)
	assert(ttf_data != nil, "failed to read font")

	ret := BakeFontBitmap(
		raw_data(ttf_data),
		0,
		auto_cast font_height,
		auto_cast bitmap,
		font_bitmap_w,
		font_bitmap_h,
		32,
		char_count,
		&font.char_data[0],
	)
	assert(ret > 0, "not enough space in bitmap")

	stbi.write_png(
		"font.png",
		auto_cast font_bitmap_w,
		auto_cast font_bitmap_h,
		1,
		bitmap,
		auto_cast font_bitmap_w,
	)

	InitFont(&font.font_info, raw_data(ttf_data), 0)


	// setup font atlas so we can use it in the shader
	desc: sg.Image_Desc
	desc.width = auto_cast font_bitmap_w
	desc.height = auto_cast font_bitmap_h
	desc.pixel_format = .R8
	desc.data.subimage[0][0] = {
		ptr  = bitmap,
		size = auto_cast (font_bitmap_w * font_bitmap_h),
	}
	font_image = sg.make_image(desc)
	if font_image.id == sg.INVALID_ID {
		fmt.println("failed to make image")
	}

}


add_glyphs_to_atlas :: proc(text: string, font_size: u32) {

}

FontAtlas :: struct {
	glyph_atlas_info: map[rune]stbtt.bakedchar,
	font_info:        stbtt.fontinfo,
}
