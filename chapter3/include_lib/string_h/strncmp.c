// include/string.h 文件中摘取,strncmp()字符串比较函数的一种实现
// 嵌入汇编 gcc
// 字符串1与字符串2的前count个字符进行比较
//参数: cs - 字符串1(char source), ct - 字符串2(char target), count - 比较的字符数目
// %0 - eax(__res)返回值, %1 - edi(cs)串1指针, %2 - esi(ct)串2指针, %3 - ecx(count)
//返回:如果串1>串2,则返回1;串1==串2,则返回0;串1<串2,则返回-1

extern inline int strncmp(const char *cs, const char *ct, int count)
{
register int __res;                 //__res是寄存器变量,让gcc自己分配,后面制定要求为eax
__asm__("cld\n"                     //清方向标志位,保证寻址为递增
          "1:\tdecl %3\n\t"           //count--
          "js 2f\n\t"                 //如果count<0,则向前跳转到标号2,意思是直接返回0了,此处不知标准是如何定义的,如果调用者直接传入count为非正数...
          "lodsd\n\t"                 //取串2字符ds:[esi]->al,并且esi++
          "scasb\n\t"                 //比较al与串1字符es:[edi],并且edi++,在现代OS设计中一般使intel处于平坦模式,4G空间所有段都可寻
          "jne 3f\n\t"                //如果不相等,则直接跳到标号3,而后稍作处理即可返回
          "testb %%al, %%al\n\t"      //看是否到了源字符串是否到了NULL字符(正常情况下串1长度短于串2)
          "jne 1b\n"                  //没到的话继续跳转到标号1重复循环
          "2:\txorl %%eax, %%eax\n\t" //到了末尾的话也就清零返回相等了
          "jmp 4f\n"                  //结束了
          "3:\tmovl $1, %%eax\n\t"    //eax置1
          "jl 4f\n\t"                 //如果串2字符<串1字符,则返回1
          "negl %%eax\n"              //否则就求补返回-1
          "4:"
          :"=a"(__res)                //输出寄存器栏,eax返回
          :"D"(cs),"S"(ct),"c"(count) //输入寄存器栏,edi,esi,ecx
          :"si","di","cx");           //改动寄存器
return __res;
}
