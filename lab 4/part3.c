#include <stdio.h>
#include <stdlib.h>

void VGA_draw_point_ASM(int x, int y, short color);
void VGA_clear_pixelbuff_ASM();
void VGA_clear_charbuff_ASM();
int read_PS2_data_ASM(char *data);
void VGA_draw_line(int x1, int y1, int x2, int y2, short color);
void GoL_draw_grid(short color);
void GoL_draw_board();

// Importing Assembly Drivers
void VGA_clear_pixelbuff_ASM(){
    for (int x = 0; x < 320; x++){
        for (int y = 0; y < 240; y++){
            VGA_draw_point_ASM(x, y, 0x0000); // Black color
        }
    }
}
void VGA_draw_point_ASM(int x, int y, short color){
    if (x < 0 || x >= 320 || y < 0 || y >= 240){
        return; // Out of bounds
    }
    int address = 0xC8000000 | (y << 10) | (x << 1); // shift left by 10 is multiply by 1024, shift left by 1 is multiply by 2
    asm volatile(
        "strh %1, [%0]"                 // the instruction (%1 = color, %0 = address)
        :                               // no output
        : "r"(address), "r"(color)      // inputs
        : "memory"                      // clobber list = tells the compiler memory is changed
    );
    
}
int read_PS2_data_ASM(char *data){
    int rvalid = 0;
    int ps2_data = 0;

    asm volatile(
        "ldr %0, =0xFF200100\n\t"           // PS2 data register address
        "ldr %1, [%0]\n\t"                  // Load PS2 data
        : "=&r"(rvalid), "=r"(ps2_data)     // outputs
        :                                   // no inputs
        : "memory"                          // clobber list = tells the compiler memory is changed
    );
    if ((ps2_data & 0x8000) != 0){ // Check RVALID bit
        *data = (char)(ps2_data & 0xFF); // Get the data byte
        return 1; // Data is valid
    }
    return 0; // No valid data
}
void VGA_clear_charbuff_ASM(){
    for (int x = 0; x < 80; x++){
        for (int y = 0; y < 60; y++){
            int address = 0xC9000000 | (y << 7) | (x << 1); // shift left by 7 is multiply by 128, shift left by 1 is multiply by 2
            asm volatile(
                "mov r3, #0\n\t"            // ASCII code 0
                "strh r3, [%0]\n\t"         // Store 0 at the address
                :                           // no output
                : "r"(address)              // input
                : "r3", "memory"            // clobber list
            );
        }
    }
}





// Helper Functions
void VGA_draw_line(int x1, int y1, int x2, int y2, short color){

    if (x1 == x2){
        // Vertical line

        if (y1 > y2){
            int temp = y1;
            y1 = y2;
            y2 = temp;
        }
        for (int y_current = y1; y_current <= y2; y_current++){
                VGA_draw_point_ASM(x1, y_current, color);
        }
    }
    else if (y1 == y2){
        // Horizontal line
        if (x1 > x2){
            int temp = x1;
            x1 = x2;
            x2 = temp;
        }
        for (int x_current = x1; x_current <= x2; x_current++){
            VGA_draw_point_ASM(x_current, y1, color);
        }
    }
}
void GoL_draw_grid(short color){
    // Draw vertical lines
    // 320 pixels / 16 cells = 20 pixels wide
    for (int x = 0; x <= 320; x +=20){
        VGA_draw_line(x, 0, x, 240, color);
    }

    // Draw horizontal lines
    for (int y = 0; y <= 240; y +=20){
        VGA_draw_line(0, y, 320, y, color);
    }
}

// The Game Board (16x12)
int board[12][16] = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0}, // Glider top
    {0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0}, // Glider mid
    {0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0}, // Glider bot
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
};


int main() {
    VGA_clear_pixelbuff_ASM();
    VGA_clear_charbuff_ASM();

    GoL_draw_grid(0xFFFF); // Draw Grid


    while(1); 
    return 0;
}