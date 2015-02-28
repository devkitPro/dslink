#include <nds.h>
#include <dswifi7.h>


#include "memcpy.h"

//---------------------------------------------------------------------------------
void VcountHandler() {
//---------------------------------------------------------------------------------
	inputGetAndSend();
}

//---------------------------------------------------------------------------------
void VblankHandler(void) {
//---------------------------------------------------------------------------------
	Wifi_Update();
}

volatile bool exitflag = false;

//---------------------------------------------------------------------------------
void powerButtonHandler() {
//---------------------------------------------------------------------------------
	exitflag = true;
}

void arm7Reset();

//---------------------------------------------------------------------------------
void reboot(u32 arm9start) {
//---------------------------------------------------------------------------------

	irqDisable(IRQ_ALL);

	REG_IME=0;
	REG_IPC_SYNC = 0;

	while((REG_IPC_SYNC &0xf)!=5);
	// copy NDS ARM9 start address into the header, starting ARM9
	*((vu32*)0x02FFFE24) = arm9start;
	// Start ARM7
	arm7Reset();

}

//---------------------------------------------------------------------------------
int main() {
//---------------------------------------------------------------------------------
	REG_SOUNDCNT &= ~SOUND_ENABLE;
	writePowerManagement(PM_CONTROL_REG, ( readPowerManagement(PM_CONTROL_REG) & ~PM_SOUND_AMP ) | PM_SOUND_MUTE );
	powerOff(POWER_SOUND);

	// read User Settings from firmware
	readUserSettings();

	irqInit();
	fifoInit();


	// Start the RTC tracking IRQ
	initClockIRQ();

	SetYtrigger(80);

	installWifiFIFO();

	installSystemFIFO();

	irqSet(IRQ_VCOUNT, VcountHandler);
	irqSet(IRQ_VBLANK, VblankHandler);

	irqEnable( IRQ_VBLANK | IRQ_VCOUNT | IRQ_NETWORK);

	irqSetAUX(IRQ_I2C, powerButtonHandler);
	irqEnableAUX(IRQ_I2C);

	// Keep the ARM7 mostly idle
	while (!exitflag) {
		swiHalt();
		if (fifoCheckValue32(FIFO_USER_01)) {
			int cmd = fifoGetValue32(FIFO_USER_01);
			switch(cmd) {
				case 1:
					memcpy32((void*)__NDSHeader->arm7destination,(void*)0x02000000 ,((__NDSHeader->arm7binarySize)+3)>>2);
					fifoSendValue32(FIFO_USER_01,0);
					break;
				case 2:
					irqDisable(IRQ_VCOUNT);
					while(!fifoCheckValue32(FIFO_USER_01));
					reboot(fifoGetValue32(FIFO_USER_01));
					break;
			}
		}

		if ( 0 == (REG_KEYINPUT & (KEY_SELECT | KEY_START | KEY_L | KEY_R))) {
			exitflag = true;
		}
	}
	return 0;

}


