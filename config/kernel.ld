ENTRY (_start)

SECTIONS {
	. = 0xFFFFFFFF80000000;

	.kernel_start : {
		KEEP(*(.kernel_start))
	}

	.text : {
		*(.text .text.*)
	}

	.rodata : {
		*(.rodata .rodata.*)
	}

	.data : {
		*(.data .data.*)
	}

	.bss : {
		__bss_start = .;
		*(.bss .bss.*)
		__bss_end = .;
	}
}

