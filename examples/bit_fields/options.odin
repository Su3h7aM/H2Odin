package bit_fields

import "core:c"

Example_Options :: struct {
	Size:          c.uint,
	IndexPriority: c.uchar,
	EditPriority:  c.uchar,
	using _:       bit_field u16 {
		Enabled:  u16 | 1,
		Verbose:  u16 | 1,
		InMemory: u16 | 1,
		_:        u16 | 13,
	},
	UserData:      rawptr,
}
