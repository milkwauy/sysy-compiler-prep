// ============================================================================
// 参考实现：把 SysY 的 getint()/putint()/putch() 映射到 C 标准库。
// 用途：在本机（不用 SysY 运行库）算出 common/expected/*.out 的"真值"，
//       作为两条 lane 的验收基准。它不参与 A/B 两条流水线的交付。
//
// 编译运行：
//   gcc -O0 -o ref sysy_main_ref.c && ./ref < ../testdata/case1.in
// 或直接：
//   bash common/verify_expected.sh
// ============================================================================
#include <stdio.h>

// 先声明成静态函数，再用宏把源程序里的同名调用重定向过来。
// 这样就不会与 libc 里的 putch 等符号冲突，源程序本身保持"纯 SysY"。
static int  ref_getint(void);
static void ref_putint(int);
static void ref_putch(int);

#define getint  ref_getint
#define getch   ref_getint
#define putint  ref_putint
#define putch   ref_putch

#include "sysy_main.c"

#undef getint
#undef getch
#undef putint
#undef putch

static int ref_getint(void)
{
    int x;
    if (scanf("%d", &x) != 1) return 0;
    return x;
}

static void ref_putint(int x)
{
    printf("%d", x);
}

static void ref_putch(int c)
{
    putchar(c);
}
