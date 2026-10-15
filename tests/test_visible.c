#include <stdio.h>
#include "visible.h"

int main(void)
{
    if (visible_add(2, 3) != 5) {
        printf("FAIL: visible_add(2, 3) != 5\n");
        return 1;
    }
    printf("PASS: visible_add\n");
    return 0;
}
