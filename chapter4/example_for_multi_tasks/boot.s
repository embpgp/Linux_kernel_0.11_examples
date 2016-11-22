!
!Filename:boot.s
!
!Description: boot section codes on Intel CPU for multiples tasks
!
!Author:rutk1t0r
!
!Data:2016.11.20
!
!GPL
!
!首先利用BIOS中断把内核代码(head代码)加载到物理内存0x10000处，然后移动到物理内存0处
!最后进入保护模式，并跳转到内存0(head代码)开始继续执行，为什么不直接把代码载入0处呢？这是由于
!从外存上载代码到内存中需要借助BIOS提供的中断，而中断的入口就在前0x100处，如果被覆盖，则
!肯定会出错，等把自己的代码完全加载到内存后就可以建立新的"秩序"了。

BOOTSEG = 0x07c0
SYSSEG = 0x1000
SYSLEN = 17     !内核占用的最大磁盘扇区数目17*512字节
entry start
start:
        jmpi    go,#BOOTSEG  !段间跳转到0x7c0:go，
                             !经过CPU内部计算发出到地址总线上的还是一样的，
                             !只是更新了内部寄存器的值
go:
        mov     ax,cs
        mov     ds,ax
        mov     ss,ax        !将DS和SS均指向0x7c0段，和cs一致，再次证明各种段的区别只由CPU解释
        mov     sp,#0x400    !本质还是二进制信息

!加载内核代码到内存0x10000
load_system:
        mov     dx,#0x0000   !关于int 13H可能某些教科书上没有，可查看维基百科
        mov     cx,#0x0002   !链接:https://en.wikipedia.org/wiki/INT_13H#INT_13h_AH.3D02h:_Read_Sectors_From_Drive
        mov     ax,#SYSSEG
        mov     es,ax
        xor     bx,bx
        mov     ax,#0x200+SYSLEN
        int     0x13
        jnc     ok_load      !出错的时候CF标志置位
die:    jmp     die

!而后把代码移动到内存0开始处，总共移动8K字节(内核长度不超过8K,17*512)
ok_load:
        cli                  !先关闭中断，防止打扰
        mov     ax,#SYSSEG   !移动开始位置DS:SI=0x1000:0;目的位置ES:DI=0:0,利用串操作指令循环
        mov     ds,ax
        xor     ax,ax
        mov     es,ax
        mov     cx,#0x1000   !每次移动一个word,总计4K次，也可以换其他指令,但由于在16位的实模式下限制了16位数据长度
        sub     si,si        !不可能用更慢的8位吧...
        sub     di,di
        rep
        movw

!加载IDT和GDT到各自寄存器，变量的定义在后面
        mov     ax,#BOOTSEG
        mov     ds,ax        !两个变量的偏移是基于0的，因此真正在内存中的寻址得切换ds才能寻到
        lidt    idt_48
        lgdt    gdt_48

!设置控制寄存器CR0,准备进入保护模式了
        mov     ax,#0x0001
        lmsw    ax
        jmpi    0,8          !跳转到EIP=0，CS=0x8处，由于已经处于保护模式，因此8=1000b，
                             !GDT内第1个描述符为内核代码段
!下面是全局描述符表GDT内容。包含三个描述符，第一个不用(约定)，另两个为代码段和数据段

gdt:    .word   0,0,0,0

        .word   0x07ff        !描述符1。8MB - 段限长=2047(2048*4096 = 8MB)
        .word   0x0000        !基址为0x00000
        .word   0x9a00        !代码段，可读可执行
        .word   0x00c0        !段属性颗粒度4KB,80386

        .word   0x7ff
        .word   0x0000
        .word   0x9200        !数据段，可读写
        .word   0x00c0

idt_48: .word   0             !此处的还只是走走形式，后期会进一步填充
        .word   0,0
gdt_48: .word   0x7ff         !长度2048B,容纳256个描述符
        .word   0x7c00+gdt,0  !基地址为0x7c00偏移gdt处

.org 510
        .word   0xaa55        !引导扇区有效标志
