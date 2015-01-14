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
		swiIntrWait(1,IRQ_FIFO_NOT_EMPTY);
		if (fifoCheckValue32(FIFO_USER_01)) {
			int cmd = fifoGetValue32(FIFO_USER_01);
			switch(cmd) {
				case 1:
					memcpy32((void*)__NDSHeader->arm7destination,(void*)0x02000000 ,((__NDSHeader->arm7binarySize)+3)>>2);
					fifoSendValue32(FIFO_USER_01,0);
					break;
				case 2:
					REG_IPC_SYNC = 0;
					swiSoftReset();
					break;
			}
		}

		if ( 0 == (REG_KEYINPUT & (KEY_SELECT | KEY_START | KEY_L | KEY_R))) {
			exitflag = true;
		}
	}
	return 0;

}


