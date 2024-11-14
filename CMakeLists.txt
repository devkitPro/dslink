cmake_minimum_required(VERSION 3.13)

set(NDS_ARCH_THUMB TRUE)

project(dslink LANGUAGES C ASM)

add_executable(${PROJECT_NAME})

nds_create_rom(${PROJECT_NAME}
	ARM7      bobtail
	NAME      "dslink"
	SUBTITLE1 "The Wi-Fi code loader"
	SUBTITLE2 "Developed by devkitPro"
	ICON      dslink.bmp
)

dkp_target_generate_symbol_list(${PROJECT_NAME})

target_compile_options(${PROJECT_NAME} PRIVATE
	-Wall
)

target_link_options(${PROJECT_NAME} PRIVATE
	-Wl,--section-start,.crt0=0x02300000
)

target_sources(${PROJECT_NAME} PRIVATE
	source/main.c
	source/console.c
)

target_link_libraries(${PROJECT_NAME} PRIVATE dswifi9)
