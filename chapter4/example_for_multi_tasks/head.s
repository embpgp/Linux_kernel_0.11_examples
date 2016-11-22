/*
 *Filename:boot.s
 *
 *Description: kernel head codes for multiples tasks
 *
 *Author:rutk1t0r
 *
 *Data:2016.11.20
 *
 *GPL
 *
 */
#head.s 包含32位保护模式初始化设置、时钟中断代码、系统调用中断代码和两个任务的代码
#在初始化之后程序移动到任务0开始执行，并在时钟中断控制下进行任务0和任务1的切换操作

LATCH     = 11930       #定时器初始计数值，使得每隔10ms发生一次中断
SCRN_SEL  = 0x18        #屏幕显示内存段选择子
TSS0_SEL  = 0x20        #任务0的TSS段选择子
LDT0_SEL  = 0x28        #任务0的LDT段选择子
TSS1_SEL  = 0x30        #任务1的TSS段选择子
LDT1_SEL  = 0x38        #任务1的LDT段选择子

.code32
.text
.globl startup_32,scr_loc
startup_32:
#先得加载DS,SS和ESP,所有段的线性基地址均为0，为了编程方便,以下均为AT&T汇编了，不同于Intel格式

        movl    $0x10,%eax      #0x10为GDT中数据段选择符
        mov     %ax,%ds
        lss     init_stack,%esp
#在新的位置重新布置IDT和GDT
        call    setup_idt       #先把256全部填充为默认的处理过程描述符
        call    setup_gdt       #设置GDT
        movl    $0x10,%eax      #改变GDT后重新加载所有的段寄存器，均指向内核段描述符
        mov     %ax,%ds
        mov     %ax,%es
        mov     %ax,%fs
        mov     %ax,%gs
        lss     init_stack,%esp
#设置8253定时芯片，计数器通道0设置成每隔10ms向中断控制器发送一个IRQ,详情必须参考DataSheet
        movb    $0x36,%al       #控制字：设置通道0工作在方式3、计数初值采用二进制
        movl    $0x43,%edx      #8253芯片控制寄存器写端口地址
        outb    %al, %dx
        movl    $LATCH,%eax     #设置初始值为LATCH(1193180/100)，即频率为100Hz
        movl     $0x40, %edx     #通道0端口地址
        outb    %al,%dx         #分两次写入，之后定时芯片便开始照常工作了,但是中断没开，没关系
        movb    %ah,%al
        outb    %al,%dx
#在IDT第8和128(0x80)项分别设置定时器中断门描述符和系统调用陷阱门描述符
        mov     $0x00080000,%eax          #高字为内核代码段0x0008,安装在GDT中，具体看偏移
        movw    $timer_interrupt,%ax      #去中断处理程序地址
        movw    $0x8E00,%dx               #中断门类型是14(可屏蔽中断)，只可以供特权0使用
        movl    $0x08,%ecx                #开机的时候BIOS设置的时钟中断向量为8,这里没有对中断控制器编程便直接用了
        lea     idt(,%ecx,8),%esi         #先把IDT的第8项的偏移地址送esi,而后直接设置该地址处的值为中断处理过程地址
        movl    %eax,(%esi)               #段选择子0x0008,偏移为中断处理过程地址
        movl    %edx,4(%esi)              #中断描述符属性设置

        movw    $system_interrupt,%ax
        movw    $0xef00,%dx               #陷阱门type=15,特权级为3也可以用
        movl    $0x80,%ecx
        lea     idt(,%ecx,8),%esi         #等价于idt+ecx*8->esi,一条指令实现更快
        movl    %eax,(%esi)
        movl    %edx,4(%esi)

#现在开始转到任务0(任务A)来执行操作堆栈内容，欺骗CPU进行中断返回到特权级3的用户空间
        pushfl                  #复位eflags中的嵌套任务标志
        andl    $0xffffbfff,(%esp)
        popfl
        movl    $TSS0_SEL,%eax  #把任务0的TSS段选择符加载到TR
        ltr     %ax
        movl    $LDT0_SEL,%eax  #把任务0的LDT段选择符加载到LDTR
        lldt    %ax             #TR和LDTR只需要人工加载一次，以后的CPU会自动处理，前提是各项数据结构没有问题
        movl    $0, current     #当前任务号0放在current全局变量中，方便另外的程序作判断

        sti                     #可以开启中断了，并开始欺骗
        pushl   $0x17           #任务0当前局部空间数据段(堆栈段)选择子入栈
        pushl   $init_stack     #esp入栈
        pushfl                  #eflags入栈
        pushl   $0x0f           #任务0当前局部空间代码段选择子入栈
        pushl   $task0          #任务0代码指针入栈
        iret                    #执行中断返回指令，从而切换到特权级3的任务0中执行了

#以下是设置GDT和IDT描述符项的子程序
setup_gdt:
        lgdt    lgdt_opcode
        ret
#这段代码暂时设置IDT中256个中断描述符都是同一个默认值，处理过程为ignore_int.
setup_idt:
        lea     ignore_int,%edx
        movl    $0x00080000,%eax
        movw    %dx,%ax
        movw    $0x8E00,%dx
        lea     idt,%edi
        mov     $256,%ecx
rp_idt:
        movl    %eax,(%edi)
        movl    %edx,4(%edi)
        addl    $8,%edi
        dec     %ecx
        jne     rp_idt
        lidt    lidt_opcode
        ret

#显示字符子程序。取得当前光标位置并把AL中的字符显示在屏幕上。整个屏幕可以显示80*25个字符
write_char:
        push    %gs               #首先保存要用到的寄存器，此处利用gs寻址
        pushl   %ebx
        mov     $SCRN_SEL,%ebx     #然后让GS指向显存段(0xb800)
        mov    %bx, %gs
        movl    scr_loc,%ebx       #再从变量scr_loc取得当前字符的显示位置值
        shl     $1,%ebx           #由于显存控制每个字符需要两个字节，还有一个为属性字节，因此字符
        movb    %al,%gs:(%ebx)    #实际显示位置对应的显存偏移地址需要乘以2
        shr     $1,%ebx           #把字符放在显存后把位置值除以2+1就是位置值对应下一个显示位置，如果大于2000,则复位为0
        incl    %ebx
        cmpl    $2000,%ebx
        jb      1f
        movl    $0, %ebx
1:
        movl    %ebx, scr_loc     #更新scr_loc值
        popl    %ebx
        pop     %gs
        ret

#以下是3个中断处理程序过程
#ignore_int为默认的中断处理过程，若系统产生了其他中断，统一输出'C'
.align 4   #注意>>>老版本的编译器为2的n次方，新版本的将直接给出对齐值
ignore_int:
        push    %ds
        pushl   %eax
        movl    $0x10,%eax      #让DS指向内核数据段，不要认为此过程没有使用寻址，call write_char
        mov     %ax, %ds        #就是个间接寻址
        movl    $67, %eax       #AL总放'C'
        call    write_char
        popl    %eax
        popl    %ds
        iret

#这个是定时中断处理过程，主要执行任务切换操作
.align 4
timer_interrupt:
        push    %ds
        pushl   %eax
        movl    $0x10,%eax      #让ds指向内核数据段
        mov     %ax,%ds
        movb    $0x20,%al
        outb    %al,$0x20
        cmpl    %eax,current
        je      1f
        movl    %eax,current
        ljmp    $TSS1_SEL,$0    #象征性的偏移量
        jmp     2f
1:
        movl    $0,current
        ljmp    $TSS0_SEL,$0
2:
        popl    %eax            #其实这里根本执行不到的...,所以上述的push会一直使得栈指针下滑，会出问题???
        pop     %ds
        iret
/*我的问题在于我没有深刻理解 jmp tss,ignore_offset 指令所做的事情，以为其直接切换过去了，而不考虑此时
地址空间的所有状态都会被保存在当前tss状态段中以备恢复，即使处于中断过程中！！！
因此我调试的时候第一次中断就能够看到这个过程体现，但以后的中断(我在时钟中断里一条指令下的中断)再执行到这里来
的时候，发现jmp之后居然"直接执行下面的popl,其实此时的地址空间确实已经在另外一个任务了，只不过也恰好
执行pop而已，这个是我根据esp指针发现的，我发现这段过程居然换了三个esp，因此再去搜索资料。我估计网上的太好搜索，便翻了《x86汇编
语言　从实模式到保护模式》这一本书的356页开头部分讲述的便豁然开朗了。我立即使用bochs再次调试，果断看第一次的情况，
果然，第一次是直接彰显了，而后面的每一次都会造成一定的"误导"，ex因此通过这个调试，解决了我的疑惑，同时我也
更加深刻地领会了Intel芯片的复杂性，其实更复杂的软件工程师都略过好多了..... */



#系统调用中断int 0x80,仅仅显示一个字符功能,参数ascll码送往al
.align 4
system_interrupt:
        push    %ds
        pushl   %edx
        pushl   %ecx
        pushl   %ebx
        pushl   %eax
        movl    $0x10,%edx
        mov     %dx, %ds
        call    write_char
        popl    %eax
        popl    %ebx
        popl    %ecx
        popl    %edx
        pop     %ds
        iret

#*******************************************************************
current:
        .long 0             #全局变量，当前任务号码(0或者1)
scr_loc:
        .long 0             #屏幕当前显示位置，按从左上角到右下角

.align 4
lidt_opcode:
        .word   256*8-1
        .long    idt
lgdt_opcode:
        .word   (end_gdt-gdt-1)
        .long   gdt


.align 8
idt:
        .fill   256,8,0     #256个8字节项用0填充
gdt:
        .quad   0x0000000000000000
        .quad   0x00c09a00000007ff
        .quad   0x00c09200000007ff
        .quad   0x00c0920b80000002
        .word   0x68, tss0, 0xe900, 0x0
        .word   0x40, ldt0, 0xe200, 0x0
        .word   0x68, tss1, 0xe900, 0x0
        .word   0x40, ldt1, 0xe200, 0x0
end_gdt:
        .fill   128,4,0       #初始化内核堆栈空间
init_stack:
        .long   init_stack    #自身地址
        .word   0x10          #选择子同内核数据段
#下面是任务0的LDT局部段描述符
ldt0:
        .quad   0x0000000000000000   #本可以用的
        .quad   0x00c0fa00000003ff
        .quad   0x00c0f200000003ff
tss0:
        .long   0                     #back link
        .long   krn_stk0,0x10         #esp0,ss0
        .long   0,0,0,0,0             #esp1,ss1,esp2,ss2,cr3
        .long   0,0,0,0,0             #eip,eflags,eax,ecs,edx
        .long   0,0,0,0,0             #ebx,esp,ebp,esi,edi,其中esp由iret指令返回被CPU自动写入
        .long   0,0,0,0,0,0           #es,cs,ss,ds,fs,gs
        .long   LDT0_SEL,0x8000000    #ldt,trace bitmap
        .fill   128,4,0               #任务0的内核栈空间
krn_stk0:

#任务1
.align 8
ldt1:
        .quad   0x0000000000000000   #本可以用的
        .quad   0x00c0fa00000003ff
        .quad   0x00c0f200000003ff
tss1:
        .long   0                                 #back link
        .long   krn_stk1,0x10                     #esp0,ss0
        .long   0,0,0,0,0                         #esp1,ss1,esp2,ss2,cr3
        .long   task1,0x200,0,0,0                 #eip,eflags,eax,ecs,edx
        .long   0,usr_stk1,0,0,0                  #ebx,esp,ebp,esi,edi
        .long   0x17,0x0f,0x17,0x17,0x17,0x17     #es,cs,ss,ds,fs,gs
        .long   LDT1_SEL,0x8000000    #ldt,trace bitmap
        .fill   128,4,0               #任务1的内核栈空间
krn_stk1:


task0:
        movl    $0x17,%eax
        movw    %ax,%ds
        movb    $65,%al
        int     $0x80
        movl    $0xfff,%ecx
1:      loop    1b                  #延时
        jmp     task0
task1:
        mov     $66,%al
        int     $0x80
        movl    $0xfff,%ecx
1:      loop    1b
        jmp     task1

        .fill   128,4,0         #任务1用户空间
usr_stk1:
