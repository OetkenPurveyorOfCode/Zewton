#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include <stdio.h>

typedef unsigned char u8;

int main(void) {
    int width, height, channels;
    u8* buffer = stbi_load("zig_light.png", &width, &height, &channels, 4);
    printf("width: %d, height %d\n", width, height);
    FILE* fd = fopen("ziglogo_light.bin", "wb");
    fwrite(buffer, 1, width*height*4, fd);
    fclose(fd);
}
