SECTIONS {
	. = 0xFFFFFFFF80000000;

	.kernel_start : ALIGN(4K) {
		KEEP(*(.kernel_start))
	}

	.text : ALIGN(4K) {
		*(.text .text.*)
	}

	.rodata : ALIGN(4K) {
		*(.rodata .rodata.*)
	}

	.data : ALIGN(4K) {
		*(.data .data.*)
	} 

	.bss (NOLOAD) : ALIGN(4K) {
		__bss_start = .;
		*(.bss .bss.*)
		__bss_end = .;
	} 

	.bss.stack (NOLOAD) : ALIGN(4K) {
		__stack_start = .;
		. += 10M;
		__stack_end = .;
	}
}

