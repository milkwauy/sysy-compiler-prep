// ============================================================================
// SysY 上机预备作业 —— 冻结源程序（两人共用，原则上不再修改）
//
// 覆盖：宏/条件编译、全局变量、全局常量、全局数组、各类数值运算、浮点运算、
//       赋值、if/else、while/for、break/continue、嵌套循环、多参数函数、
//       递归、数组作参数、提前 return、运行时库 IO
//
// 注意：本文件是 SysY 程序，用 C 编译器/工具链处理（SysY 是 C 的子集）。
//       SysY 的输入输出由运行时库提供，没有头文件，因此这里显式给出原型声明；
//       clang 21 / C99 之后不再允许"隐式函数声明"，不声明会直接报错。
// ============================================================================
#include <stdio.h>

// ---- SysY 运行时库接口（实现见 libsysy）----
int  getint(void);
int  getch(void);
void putint(int x);
void putch(int x);

#define SCALE 10
#define SQUARE(x) ((x) * (x))

#if SCALE > 5
#define TAG 1
#else
#define TAG 0
#endif

int g_seed = 3;              /* 全局变量 */
const int MOD = 1000000;     /* 全局常量 */
int g_trace = 0;             /* 全局累加器（验证运算顺序） */
int mat[3][3];               /* 全局数组（未初始化） */

/* ---- 数学工具：while 循环 + 取模 ---- */
int gcd(int a, int b)
{
    int t;
    while (b != 0) {
        t = a % b;
        a = b;
        b = t;
    }
    return a;
}

/* ---- 递归 + 提前 return ---- */
int fib(int n)
{
    if (n < 0) return -1;
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int fact(int n)
{
    if (n <= 1) return 1;
    return n * fact(n - 1);
}

/* ---- 嵌套循环 + 全局数组 + break/continue ---- */
int fill_mat(int n)
{
    int i;
    int j;
    int s = 0;
    for (i = 0; i < 3; i = i + 1) {
        for (j = 0; j < 3; j = j + 1) {
            if (i == j) continue;              /* continue 分支 */
            if (j > n) break;                  /* break 分支 */
            mat[i][j] = g_seed + i * 3 + j;    /* 数组赋值 */
            s = s + mat[i][j];
        }
    }
    return s;
}

/* ---- 数组作参数 + 浮点运算 + 强制类型转换 ---- */
int trace_sum(int m[3][3], int n)
{
    int i;
    int s = 0;
    float f = 0.0;
    for (i = 0; i < n; i = i + 1) {
        s = s + m[i][i];          /* 数组读 */
        f = f + (float)(i + 1) * 0.5;
    }
    return s + (int)f;
}

/* ---- 各类数值运算的集中检验 ---- */
int arith(int x, int y)
{
    int r;
    int t;
    r = x + y;        /* + */
    r = r - y;        /* - */
    t = x * y;        /* * */
    r = r + t;        /* 乘后加 */
    if (y != 0) {
        r = r + x / y;    /* / */
        r = r + x % y;    /* % */
    }
    r = r + SQUARE(TAG);  /* 宏展开 */
    r = r + SCALE;        /* 宏常量 */
    return r;
}

int main()
{
    int a;
    int b;
    int r;
    float fr;
    int i;
    int n;
    int s;

    a = getint();
    b = getint();

    fr = (float)a / 2.0;          /* 浮点 */
    r = (int)fr;                  /* 强制转换 */

    putint(arith(a, b) % MOD);
    putch(10);

    putint(gcd(a, b));
    putch(10);

    putint(fact(5));
    putch(10);

    putint(fib(10));
    putch(10);

    s = fill_mat(a);              /* 嵌套循环 + 数组 */
    for (i = 0; i < 3; i = i + 1) {
        s = s + trace_sum(mat, 3);   /* 函数 + 数组参数 */
    }
    g_trace = s + r;

    n = 0;
    while (n < 2) {
        g_trace = g_trace + n;
        n = n + 1;
    }

    putint(g_trace);
    putch(10);

    putint(g_seed);
    putch(10);

    return 0;
}
