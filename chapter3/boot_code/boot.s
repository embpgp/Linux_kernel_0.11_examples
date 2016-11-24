!
!Filename:boot.s
!
!Description: boot section codes on Intel CPU
!
!Author:rutk1t0r
!
!Data:2016.11.8
!
!GPL
!
!method:
![/root]# as86 -0 -a -o boot.o boot.s    #编译
![/root]# ld86 -0 -s -o boot boot.o      #链接
![/root]# dd bs=32 if=boot of=/dev/fd0 skip=1   #写入软盘或者image文件,跳过文件头
!==================================================================
!
!
! boot.s -- bootsect.s 的框架程序.用代码0x07替换字符串msg1中一个字符,然后在屏幕上1行显示
!
.globl begtext, begdata, begbss, endtext, enddata, endbss !全局标识符,供ld86链接使用
.text  !代码段
begtext:
.data
begdata:
.bss
begbss:
.text
BOOTSEG = 0x07c0   !类似于C语言宏定义,EQU,Intel内存代码执行首地址
entry start        !告知链接程序,程序从start标号开始执行
start:
jmpi	go, BOOTSEG !段间跳转,两个地址,低地址16位送IP寄存器,高地址16位送cs段寄存器
go:
		mov	ax, cs  !将cs段寄存器值同步至ds,es,此代码未用到ss
		mov es, ax
		mov ds, ax
		mov [msg1+17], ah   !示例修改串,然后会调用BIOS中断,参考链接https://zh.wikipedia.org/wiki/INT_10
		mov	cx, #20  		!立即数需要前缀#,根据BIOS提供的接口约定,cx为字符总个数
		mov	dx, #0x1004  	!约定,位置,此时为17行5列
		mov bx, #0x000c    	!约定,字符属性(红色)
		mov bp, #msg1		!约定,字符缓冲区首地址
		mov ax, #0x1301		!ah=0x13表示写字符串功能号
		int 0x10			!调用BIOS中断
loop1:  jmp 	loop1  		!死循环待机
msg1:	.ascii	"Loading system..." !字符20个,包括回车换行
		.byte 	13,10
.org	510					!表示以后的语句从偏移地址510开始放
		.word 	0xAA50		!有效引导扇区标志,约定
.text
endtext:
.data
enddata:
.bss
endbss:
