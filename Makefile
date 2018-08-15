all: main_merged.bc

main_merged.bc: main.elf.ll
	llvm-as main.elf.ll -o main_merged.bc
	
main.elf.ll: main.elf main.bc
	inception-cl main.elf main.bc

main.bc: main.ll
	llvm-as main.ll -o main.bc

main.ll: main.c
	clang --target=thumbv7m-elf -mcpu=cortex-m3 -mthumb -mfloat-abi=softfp -emit-llvm -IAnalyzer/include -S -g -DKLEE  -c main.c -o main.ll

main.elf: main.o startup.o
	arm-none-eabi-ld main.o startup.o -T link.ld -o main.elf

main.o: main.c
	arm-none-eabi-gcc -march=armv7-m -mthumb -mcpu=cortex-m3 -Wa,-mimplicit-it=thumb -g -c main.c -o main.o

startup.o: startup.s
	arm-none-eabi-as -mcpu=cortex-m3 -mthumb -mfloat-abi=softfp -c startup.s -o startup.o

clean:
	rm -rf *.o *.elf *.ll *.bc *.elf.ll klee-* *.dis *.dump
