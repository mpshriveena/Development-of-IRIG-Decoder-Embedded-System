"build/irigacq-pru1.out"
-b
-image
ROMS {
	PAGE 0:
	text: o = 0x0, l = 0x2000, files={build/text1.bin}
	PAGE 1:
	data: o = 0x0, l = 0x2000, files={build/data1.bin}
}
