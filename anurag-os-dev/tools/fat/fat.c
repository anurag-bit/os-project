#include<stdio.h>

int main(int argc, char**  argv) 
{
 if (argc > 3) {
    printf("Syntax: %s  <disk image>  <file name>\n", argv[0]);
    return -1;
    }



    return 0;
}



