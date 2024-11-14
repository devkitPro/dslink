// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: Copyright fincs, devkitPro
#include <nds.h>
#include <dswifi9.h>

#include <errno.h>
#include <stdlib.h>
#include <string.h>

#include <sys/ioctl.h>
#include <sys/socket.h>
#include <netinet/in.h>

void miniconsoleInit(void);
void miniconsoleSetCursorX(unsigned pos);

extern void *fake_heap_start, *fake_heap_end;

void systemUserStartup(void)
{
	// Override heap limit
	fake_heap_end = (void*)0x02380000;
	if (fake_heap_start > fake_heap_end) {
		for (;;);
	}
}

void systemUserExit(void)
{
	// Clean up graphics
	REG_DISPCNT     = 0;
	REG_DISPCNT_SUB = 0;

	// Clear palettes
	armFillMem32((void*)MM_PALRAM, 0, MM_PALRAM_SZ);

	// Clear VRAM_A
	REG_VRAMCNT_A = VRAM_CONFIG(0, 0);
	armFillMem32((void*)MM_VRAM_A, 0, MM_VRAM_A_SZ);
	REG_VRAMCNT_A = 0;
}

static int _dslinkFindHost(in_addr_t* out_addr)
{
	// Set up listening port/address
	struct sockaddr_in sa;
	sa.sin_family = AF_INET;
	sa.sin_addr.s_addr = INADDR_ANY;
	sa.sin_port = htons(17491);

	// Create and bind sockets
	int sock_udp = socket(PF_INET, SOCK_DGRAM,  0);
	int sock_tcp = socket(PF_INET, SOCK_STREAM, 0);
	bind(sock_udp, (struct sockaddr*)&sa, sizeof(sa));
	bind(sock_tcp, (struct sockaddr*)&sa, sizeof(sa));

	// Set sockets to non-blocking
	int i = 1;
	ioctl(sock_udp, FIONBIO, &i);
	ioctl(sock_tcp, FIONBIO, &i);

	// Begin listening for TCP host connections
	listen(sock_tcp, 2);

	int fd = -1;

	for (;;) {
		struct sockaddr_in sa_remote;
		socklen_t dummy;

		// Probe if we have an incoming connection
		static const char request[6] = "dsboot";
		static const char reply[6] = "bootds";
		fd = accept(sock_tcp, (struct sockaddr*)&sa_remote, &dummy);
		if (fd >= 0) {
			*out_addr = sa_remote.sin_addr.s_addr;
			break;
		}

		// Reply to UDP requests
		char recvbuf[256];
		ssize_t len = recvfrom(sock_udp, recvbuf, sizeof(recvbuf), 0, (struct sockaddr*)&sa_remote, &dummy);
		if (len == sizeof(request)) {
			sa_remote.sin_family = AF_INET;
			sa_remote.sin_port = htons(17491);
			sendto(sock_udp, reply, sizeof(reply), 0, (struct sockaddr*)&sa_remote, sizeof(sa_remote));
		}

		threadWaitForVBlank();
	}

	// Set the host connection socket to blocking
	i = 0;
	ioctl(fd, FIONBIO, &i);

	// Cleanup
	closesocket(sock_tcp);
	closesocket(sock_udp);
	return fd;
}

static bool _dslinkReadData(int fd, void* out, size_t size, bool show_progress)
{
	size_t orig_size = size;

	while (size) {
		ssize_t cursize = recv(fd, out, size, 0);
		if (cursize == 0) {
			dietPrint("Error: host closed connection\n");
			return false;
		}
		if (cursize < 0) {
			dietPrint("recv() fail, errno = %d\n", errno);
			return false;
		}

		size -= cursize;
		out = (u8*)out + cursize;

		if (show_progress) {
			miniconsoleSetCursorX(32-5);
			dietPrint("%3u%%\n", (orig_size - size) * 100U / orig_size);
		}
	}

	return true;
}

typedef enum DSLinkError {
	DSLinkError_None = 0,
	DSLinkError_InvalidArm9 = 1,
	DSLinkError_InvalidArm7 = 2,
} DSLinkError;

#define DSLINK_FLAG_TWL_HEADER (1U << 16)

#define ARM9_MAIN_START  0x2000000
#define ARM9_MAIN_END    0x2300000
#define ARM7_MAIN_START  0x2380000
#define ARM7_MAIN_END    0x23c0000
#define ARM7_WRAM_START  0x37f8000
#define ARM7_WRAM_END    0x380f000

#define ARM9i_MAIN_START 0x2400000
#define ARM9i_MAIN_END   0x2680000
#define ARM7i_MAIN_START 0x2e80000
#define ARM7i_MAIN_END   0x2f88000

MK_INLINE bool _dslinkValidateSection(u32 start, u32 size, u32 sect_start, u32 sect_end, const char* name)
{
	u32 max_size;
	if (start >= sect_start && start < sect_end) {
		max_size = sect_end - start;
	} else {
		dietPrint("Invalid %s load address\n", name);
		return false;
	}

	if (size > max_size) {
		dietPrint("%s section is too large\n", name);
		return false;
	}

	return true;
}

MK_INLINE bool _dslinkValidateArm7(u32 start, u32 size)
{
	u32 max_size;
	if (start >= ARM7_MAIN_START && start < ARM7_MAIN_END) {
		max_size = ARM7_MAIN_END - start;
	} else if (start >= ARM7_WRAM_START && start < ARM7_WRAM_END) {
		max_size = ARM7_WRAM_END - start;
	} else {
		dietPrint("Invalid arm7 load address\n");
		return false;
	}

	if (size > max_size) {
		dietPrint("arm7 section is too large\n");
		return false;
	}

	return true;
}

static bool _dslinkLoadFromHost(int fd, struct in_addr addr)
{
	dietPrint("Host: %s\n", inet_ntoa(addr));

	dietPrint("Reading NDS header...\n");
	if (!_dslinkReadData(fd, g_envAppNdsHeader, sizeof(EnvNdsHeader), false)) {
		return false;
	}

	// Unused
	u8 footer[0x200 - sizeof(EnvNdsHeader)];
	if (!_dslinkReadData(fd, footer, sizeof(footer), false)) {
		return false;
	}

	bool has_twl_support = g_envAppNdsHeader->unitcode & (1U<<1);
	bool is_twl_only     = has_twl_support && (g_envAppNdsHeader->unitcode & (1U<<0));

	u32 response = DSLinkError_None;

	// Sanity checks
	if (systemIsTwlMode()) {
		if (!has_twl_support) {
			dietPrint(
				"Error:\n"
				"This program is not compatible\n"
				"with TWL mode. Switching to NTR\n"
				"mode is not implemented yet.\n"
			);
			return false;
		}
		response |= DSLINK_FLAG_TWL_HEADER;
	} else if (is_twl_only) {
		dietPrint(
			"Error:\n"
			"This program can only run on a\n"
			"DSi in TWL mode.\n"
		);
		return false;
	}

	dietPrint("arm9  addr:%.8lX size:%.lX\n", g_envAppNdsHeader->arm9_ram_address, g_envAppNdsHeader->arm9_size);
	dietPrint("arm7  addr:%.8lX size:%.lX\n", g_envAppNdsHeader->arm7_ram_address, g_envAppNdsHeader->arm7_size);

	if (!_dslinkValidateSection(g_envAppNdsHeader->arm9_ram_address, g_envAppNdsHeader->arm9_size, ARM9_MAIN_START, ARM9_MAIN_END, "arm9")) {
		response = DSLinkError_InvalidArm9;
	} else if (!_dslinkValidateArm7(g_envAppNdsHeader->arm7_ram_address, g_envAppNdsHeader->arm7_size)) {
		response = DSLinkError_InvalidArm7;
	}

	// Calculate command line buffer address
	char* cmdline = (char*)(g_envAppNdsHeader->arm9_ram_address + g_envAppNdsHeader->arm9_size);
	u32 cmdline_max_len = ARM9_MAIN_END - (u32)cmdline;

	send(fd, &response, sizeof(response), 0);
	if ((response & 0xffff) != DSLinkError_None) {
		return false;
	}

	if (response & DSLINK_FLAG_TWL_HEADER) {
		dietPrint("Reading DSi header...\n");
		if (!_dslinkReadData(fd, g_envAppTwlHeader, sizeof(EnvTwlHeader), false)) {
			return false;
		}

		if (memcmp(g_envAppTwlHeader, g_envAppNdsHeader, sizeof(EnvNdsHeader)) != 0) {
			dietPrint(
				"Error:\n"
				"DSi & NDS headers do not match\n"
			);
			return false;
		}

		dietPrint("arm9i addr:%.8lX size:%.lX\n", g_envAppTwlHeader->arm9i_ram_address, g_envAppTwlHeader->arm9i_size);
		dietPrint("arm7i addr:%.8lX size:%.lX\n", g_envAppTwlHeader->arm7i_ram_address, g_envAppTwlHeader->arm7i_size);

		if (!_dslinkValidateSection(g_envAppTwlHeader->arm9i_ram_address, g_envAppTwlHeader->arm9i_size, ARM9i_MAIN_START, ARM9i_MAIN_END, "arm9i")) {
			return false;
		}

		if (!_dslinkValidateSection(g_envAppTwlHeader->arm7i_ram_address, g_envAppTwlHeader->arm7i_size, ARM7i_MAIN_START, ARM7i_MAIN_END, "arm7i")) {
			return false;
		}
	}

	if (g_envAppNdsHeader->arm7_size) {
		// Special case for ARM7 binaries loaded directly into private ARM7 WRAM
		void* arm7_dest = (void*)g_envAppNdsHeader->arm7_ram_address;
		if ((u32)arm7_dest >= ARM7_WRAM_START) {
			arm7_dest = (void*)ARM7_MAIN_START;
		}

		dietPrint("Reading ARM7 section...\n");
		if (!_dslinkReadData(fd, arm7_dest, g_envAppNdsHeader->arm7_size, true)) {
			return false;
		}
	}

	if (g_envAppNdsHeader->arm9_size) {
		dietPrint("Reading ARM9 section...\n");
		if (!_dslinkReadData(fd, (void*)g_envAppNdsHeader->arm9_ram_address, g_envAppNdsHeader->arm9_size, true)) {
			return false;
		}
	}

	if (response & DSLINK_FLAG_TWL_HEADER) {
		if (g_envAppTwlHeader->arm7i_size) {
			dietPrint("Reading ARM7i section...\n");
			if (!_dslinkReadData(fd, (void*)g_envAppTwlHeader->arm7i_ram_address, g_envAppTwlHeader->arm7i_size, true)) {
				return false;
			}
		}

		if (g_envAppTwlHeader->arm9i_size) {
			dietPrint("Reading ARM9i section...\n");
			if (!_dslinkReadData(fd, (void*)g_envAppTwlHeader->arm9i_ram_address, g_envAppTwlHeader->arm9i_size, true)) {
				return false;
			}
		}
	}

	u32 cmdline_len = 0;
	dietPrint("Reading command line...\n");
	if (!_dslinkReadData(fd, &cmdline_len, sizeof(u32), false) ||
		cmdline_len > cmdline_max_len ||
		!_dslinkReadData(fd, cmdline, cmdline_len, false)) {
		return false;
	}

	// Set up argv header
	g_envNdsArgvHeader->magic = ENV_NDS_ARGV_MAGIC;
	g_envNdsArgvHeader->args_str = cmdline;
	g_envNdsArgvHeader->args_str_size = cmdline_len;
	g_envNdsArgvHeader->dslink_host_ipv4 = addr.s_addr;

	// Set up boot parameter block
	armFillMem32(g_envBootParam, 0, sizeof(EnvBootParam));
	g_envBootParam->boot_src = EnvBootSrc_Wireless;
	// XX: do we want to fill the rest?

	// Enable chainload
	g_envExtraInfo->pm_chainload_flag = 1;

	dietPrint("Taking the plunge\n");
	return true;
}

static int _dslinkThreadMain(void* arg)
{
	for (;;) {
		struct in_addr addr;
		int fd = _dslinkFindHost(&addr.s_addr);
		if (fd < 0) {
			break;
		}

		bool ok = _dslinkLoadFromHost(fd, addr);
		closesocket(fd);

		if (ok) {
			pmPrepareToReset();
			break;
		}
	}

	return 0;
}

int main(int argc, char* argv[])
{
	Thread thr;
	alignas(8) u8 thr_stack[4096];

	miniconsoleInit();

	dietPrint("dslink started in %s mode\n", systemIsTwlMode() ? "TWL" : "NTR");
	dietPrint("Developed by devkitPro\n\n");

	dietPrint("Connecting to Wi-Fi... ");

	if (Wifi_InitDefault(WFC_CONNECT)) {
		struct in_addr ip = Wifi_GetIPInfo(NULL, NULL, NULL, NULL);
		dietPrint("[OK]\n\n  DS IP: %s\n\n", inet_ntoa(ip));

		threadPrepare(&thr, _dslinkThreadMain, NULL, &thr_stack[sizeof(thr_stack)], MAIN_THREAD_PRIO+1);
		threadStart(&thr);
	} else {
		dietPrint(
			"[FAIL]\n\n"
			"Make sure your Nintendo WFC\n"
			"settings are correct, and that\n"
			"a configured Access Point is\n"
			"in range of your Nintendo DS.\n\n"
		);
	}

	dietPrint("Push START to exit\n");

	Keypad pad;
	keypadRead(&pad);

	while (pmMainLoop()) {
		threadWaitForVBlank();
		keypadRead(&pad);

		if (keypadDown(&pad) & KEY_START) {
			break;
		}
	}

	return 0;
}
