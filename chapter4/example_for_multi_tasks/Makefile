

Image: boot system
	dd bs=32 if=boot of=Image skip=1
	dd bs=1 if=system of=Image skip=4096 seek=512   #必须指出这里的错误，skip偏移量是0x1000，不是1024

boot: boot.o
	ld86 -0 -s -o $@ $<
boot.o: boot.s
	as86 -0 -a -o $@ $<

system: head.o
	ld -m elf_i386 -Ttext 0 -e startup_32 -s -x -M $< -o $@ > System.map
head.o: head.s
	as -32 -o $@ $<

disk:
	dd bs=8192 if=Image of=/dev/fd0
	sync;sync;sync

clean:
	-rm -rf *.o boot system System.map Image
