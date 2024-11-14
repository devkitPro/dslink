// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: Copyright fincs, devkitPro
#include <calico.h>
#include <nds/arm9/video.h>
#include <nds/arm9/background.h>

extern const u8 default_font_bin[];

static Mutex s_conMutex;
static u16* s_conTilemap;
static int s_conCursorX, s_conCursorY;

static void _consoleNewRow(void)
{
	s_conCursorY ++;
	if (s_conCursorY >= 24) {
		s_conCursorY --;
		svcCpuSet(&s_conTilemap[32], &s_conTilemap[0], SVC_SET_UNIT_16 | SVC_SET_SIZE_16(23*32*2));
	}
	u16 fill = 0;
	svcCpuSet(&fill, &s_conTilemap[s_conCursorY*32], SVC_SET_UNIT_16 | SVC_SET_FIXED | SVC_SET_SIZE_16(32*2));
}

static void _consolePutChar(int c)
{
	if (s_conCursorX >= 32 && c != '\n') {
		s_conCursorX = 0;
		_consoleNewRow();
	}

	switch (c) {
		default:
			s_conTilemap[s_conCursorY*32 + s_conCursorX] = c;
			s_conCursorX++;
			break;

		case '\t':
			s_conCursorX = (s_conCursorX + 4) &~ 3;
			break;

		case '\n':
			_consoleNewRow();
			/* fallthrough */

		case '\r':
			s_conCursorX = 0;
			break;
	}
}

static void consoleWrite(const char* buf, size_t size)
{
	mutexLock(&s_conMutex);

	if_likely (buf) {
		for (size_t i = 0; i < size; i ++) {
			_consolePutChar(buf[i]);
		}
	} else {
		for (size_t i = 0; i < size; i ++) {
			_consolePutChar(' ');
		}
	}

	mutexUnlock(&s_conMutex);
}

void miniconsoleInit(void)
{
	vramSetBankA(VRAM_A_MAIN_BG);

	SvcBitUnpackParams params = {
		.in_length_bytes = 256*8,
		.in_width_bits   = 1,
		.out_width_bits  = 4,
		.data_offset     = 14, // 1+14 = 15
		.zero_data_flag  = 0,
	};
	svcBitUnpack(default_font_bin, (void*)MM_VRAM_BG_A, &params);

	REG_BG0CNT = BG_PRIORITY_0 | BG_TILE_BASE(0) | BG_MOSAIC_OFF | BG_32x32 | BG_MAP_BASE(4);

	s_conTilemap = BG_MAP_RAM(4);
	armFillMem32(s_conTilemap, 0, 32*32*2);

	REG_DISPCNT     = MODE_0_2D | DISPLAY_BG0_ACTIVE;
	REG_DISPCNT_SUB = MODE_0_2D;

	BG_PALETTE[0]     = RGB15( 7, 14, 21);
	BG_PALETTE[15]    = RGB15(31, 31, 31);
	BG_PALETTE_SUB[0] = RGB15( 7, 14, 21);

	dietPrintSetFunc(consoleWrite);
	installArm7DebugSupport(consoleWrite, MAIN_THREAD_PRIO-1);

	threadWaitForVBlank();
}

void miniconsoleSetCursorX(unsigned pos)
{
	mutexLock(&s_conMutex);
	if (s_conCursorY >= 0) {
		s_conCursorY --;
	}
	s_conCursorX = pos;
	mutexUnlock(&s_conMutex);
}
