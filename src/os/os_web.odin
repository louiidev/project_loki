#+build freestanding
#+build wasm32, wasm64p32
/*
This implements some often-used procs from `core:os` but using the libc stuff
that emscripten links in.
*/


package web_compatible_os

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:strings"

// These will be linked in by emscripten.
@(default_calling_convention = "c")
foreign _ {
	fopen :: proc(filename, mode: cstring) -> ^FILE ---
	fseek :: proc(stream: ^FILE, offset: c.long, whence: Whence) -> c.int ---
	ftell :: proc(stream: ^FILE) -> c.long ---
	fclose :: proc(stream: ^FILE) -> c.int ---
	fread :: proc(ptr: rawptr, size: c.size_t, nmemb: c.size_t, stream: ^FILE) -> c.size_t ---
	fwrite :: proc(ptr: rawptr, size: c.size_t, nmemb: c.size_t, stream: ^FILE) -> c.size_t ---
}

FILE :: struct {}

Whence :: enum c.int {
	SET,
	CUR,
	END,
}

@(default_calling_convention = "c")
foreign _ {
	mount_idbfs :: proc() ---
	sync_fs :: proc() -> int ---
	access :: proc(path: cstring, mode: int) -> int ---
}

F_OK :: 0
_exists :: proc(name: string) -> bool {
	value := access(strings.clone_to_cstring(name, allocator = context.temp_allocator), F_OK)
	return value == 0
}

// Similar to rl.LoadFileData
_read_entire_file :: proc(
	name: string,
	allocator := context.allocator,
	loc := #caller_location,
	from_persist := false,
) -> (
	data: []byte,
	success: bool,
) {
	if name == "" {
		log.error("No file name provided")
		return
	}

	//sync_fs()
	name := name
	if from_persist {
		name = fmt.tprintf("/persist/%v", name)
	}

	file := fopen(strings.clone_to_cstring(name, context.temp_allocator), "rb")

	if file == nil {
		log.errorf("Failed to open file %v", name)
		return
	}

	defer fclose(file)

	fseek(file, 0, .END)
	size := ftell(file)
	fseek(file, 0, .SET)

	if size <= 0 {
		log.errorf("Failed to read file %v", name)
		return
	}

	data_err: runtime.Allocator_Error
	data, data_err = make([]byte, size, allocator, loc)

	if data_err != nil {
		log.errorf("Error allocating memory: %v", data_err)
		return
	}

	read_size := fread(raw_data(data), 1, c.size_t(size), file)

	if read_size != c.size_t(size) {
		log.warnf("File %v partially loaded (%i bytes out of %i)", name, read_size, size)
	}

	//log.debugf("Successfully loaded %v", name)
	return data, true
}

// Similar to rl.SaveFileData.
//
// Note: This can save during the current session, but I don't think you can
// save any data between sessions. So when you close the tab your saved files
// are gone. Perhaps you could communicate back to emscripten and save a cookie.
// Or communicate with a server and tell it to save data.
_write_entire_file :: proc(
	name: string,
	data: []byte,
	truncate := true,
	persist := false,
) -> (
	success: bool,
) {
	if name == "" {
		log.error("No file name provided")
		return
	}

	name := name
	if persist {
		name = fmt.tprintf("/persist/%v", name)
	}

	file := fopen(strings.clone_to_cstring(name, context.temp_allocator), truncate ? "wb" : "ab")


	if file == nil {
		log.errorf("Failed to open '%v' for writing", name)
		return
	}

	bytes_written := fwrite(raw_data(data), 1, len(data), file)

	if bytes_written == 0 {
		log.errorf("Failed to write file %v", name)
		return
	} else if bytes_written != len(data) {
		log.errorf("File partially written, wrote %v out of %v bytes", bytes_written, len(data))
		return
	}

	fclose(file)
	log.debugf("File written successfully: %v", name)

	if persist {
		sync_fs()
	}

	return true
}
