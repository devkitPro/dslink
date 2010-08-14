#ifndef _display_h_
#define _display_h_

void initDisplay();
void kprintf(const char *str, ...);
void setCursor(int row, int column);
void getCursor(int *row, int *column);

#endif
