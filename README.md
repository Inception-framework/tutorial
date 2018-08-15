# Tutorial

A very simple tutorial to get started with Inception

# Index

* [Docker](#Docker)
* [Quick start](#Start)
* [Step by step](#Step)
* [Some more interesting samples](#Samples)

## <a name="Docker"></a>Build and install docker image

Follow the instrucions [here](https://github.com/Inception-framework/docker).

## < a name="Start"></a>Quick start

Once inside a shell in docker, we can clone this repo and compile & run a simple example.

Cloning:
```
cd /home/inception
git clone https://github.com/Inception-framework/tutorial.git
```

Compiling a program with 1 Fibonacci function in C and one in assembly (using Inception-translator):
```
cd tutorial
make
```

Running with Inception-compiler:
```
klee main_merged.bc
````

The end of the output should be:
```
fibonacci1(10) = 55
fibonacci_golden(10) = 55
ok
```

## <a name="Step"></a>Step by step

### The program

The main program is main.c, written in C and inline assembly. The main function calls a Fibonacci function written in C and one written in assembly, and then it compares the results with an assertion.
The conditional compilation variable KLEE is used to enclose those parts of the code that should run only in Klee, but not on the target device (e.g., printf and assert that are used for debug). 

### Compilation to binary

We need the elf of the program, that we will then merge with the LLVM coming from clang. Therefore, we want to compile the program with gcc (arm toolchain). We also need a linker script (link.ld) and a startup file (startup.s). They are particularly important for setting some sections: .interrupt_vector (or .isr_vector), .stack, .main_stack, .heap. The last two are necessary only in case of multithreading and dynamic allocation, respectively. They are recognized and used by Inception-analyzer to create a correct memory layout.

```
arm-none-eabi-gcc -march=armv7-m -mthumb -mcpu=cortex-m3 -Wa,-mimplicit-it=thumb -g -c main.c -o main.o
arm-none-eabi-as -mcpu=cortex-m3 -mthumb -mfloat-abi=softfp -c startup.s -o startup.o
arm-none-eabi-ld main.o startup.o -T link.ld -o main.elf
```
### Compilation to LLVM

The C part of the program can be compiled to LLVM-IR using CLang.

```
clang --target=thumbv7m-elf -mcpu=cortex-m3 -mthumb -mfloat-abi=softfp -emit-llvm -IAnalyzer/include -S -g -DKLEE  -c main.c -o main.ll
llvm-as main.ll -o main.bc
```

The .ll file is LLVM in human readable format. Have a look at it, you can clearly see that the inline assembly has not been translated, for example:

```
call void asm sideeffect "push\09{r4, r7, lr}", ""() #5, !dbg !19, !srcloc !20
```

If you try to run the main.bc, klee will return an error:

```
klee main.bc
```

```
KLEE: ERROR: /home/inception/tutorial/main.c line:9, klee_last/assembly.ll line: 79, inline assembly is unsupported
```

### Lift and merge with Inception-translator

We can now feed main.bc and main.elf to Inception-translator (inception-cl), in order to obtain a unified representation.

```
inception-cl main.elf main.bc
```

The output will look like the following. You can clearly see that the tool detects the function containing assembly and starts processing it. Warnings are mainly for debug reasons. The important ones are those related to the missing sections. In this case we do not need to worry as we do not have dynamic allocation, nor multithreading (no need for .heap and .main_stack), and we have .stack and .interrupt_vector (alternative to .isr_vector). You can also observe that the tool generates many helper functions, for example inception_icp handles indirect calls, and *_sp handle the dual stack mode.

```
  [...]
	Detecting all assembly functions ...
	Done -> 1 functions.
   
	Processing function fibonacci_asm...
	WARNING: [printInstructions] printing only from entry to first return
	Done

	Decompilation stage done

	Checking functions dependencies
	Allocating and initializing virtual stack...
	Done

	Importing sections ...
	WARNING: [SectionsWriter] Section '.heap' not found
	WARNING: [SectionsWriter] Section '.main_stack' not found
	WARNING: [SectionsWriter] Section '.isr_vector' not found
	.interrupt_vector ...
	Done

	Adding call to functions helper...
	Writing inception_writeback_sp
	done
	Writing inception_cache_sp
	done
	Writing inception_switch_sp
	done
	Writing inception_interrupt_prologue
	Done
	Writing inception_interrupt_epilogue
	Done
	Writing inception_interrupt_handler
	done
	Writing inception_icp
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	[ABIAdapter] C function encoutered, adding restore of lr into pc after execution
	Done
	Done
```

The output of the program is main.elf.ll. This time, it does not contain non-translated assembly anymore. For example, the line shown before has now become pure LLVM:

```
  %R4_1 = load i32* @R4, !dbg !19
  %R7_1 = load i32* @R7, !dbg !19
  %LR1 = load i32* @LR, !dbg !19
  %SP1 = load i32* @SP, !dbg !19
  %SP2 = sub i32 %SP1, 4, !dbg !19
  %SP3 = inttoptr i32 %SP2 to i32*, !dbg !19
  store i32 %LR1, i32* %SP3, !dbg !19
  %SP4 = sub i32 %SP2, 4, !dbg !19
  %SP5 = inttoptr i32 %SP4 to i32*, !dbg !19
  store i32 %R7_1, i32* %SP5, !dbg !19
  %SP6 = sub i32 %SP4, 4, !dbg !19
  %SP7 = inttoptr i32 %SP6 to i32*, !dbg !19
  store i32 %R4_1, i32* %SP7, !dbg !19
  store i32 %SP6, i32* @SP, !dbg !19
```

Therefore, wìe can now assemble it and run it, as shown in the next section.

```
llvm-as main.elf.ll -o main_merged.bc
```

Another output of the program is the disassembled fucntion fibonacci_asm.dis. The llvm code in main.elf.ll maps the llvm instruction that implement the inline assembly to the lines in this .dis file. A known limitation is the incorrect visualization of functions with multiple returns, that are however supported and working (you can see the corresponding warning in the log).

### Running with Inception-analyzer

```
klee main_merged.bc
```

The output will be the following. 

```
inception@3b0418264485:~/tutorial$ klee main_merged.bc
KLEE: output directory is "/home/inception/tutorial/klee-out-0"
KLEE: Using STP solver backend
KLEE: WARNING: [SymbolsTable] No .data section found
warning: Linking two modules of different target triples: /usr/local/lib/klee/runtime/kleeRuntimeIntrinsic.bc' is 'thumbv7m-none--eabi' whereas 'main_merged.bc' is 'thumbv7m---elf'

KLEE: WARNING: undefined reference to function: BusFault_Handler
KLEE: WARNING: undefined reference to function: DebugMon_Handler
KLEE: WARNING: undefined reference to function: HardFault_Handler
KLEE: WARNING: undefined reference to function: MemManage_Handler
KLEE: WARNING: undefined reference to function: NMI_Handler
KLEE: WARNING: undefined reference to function: PendSV_Handler
KLEE: WARNING: undefined reference to function: Reset_Handler
KLEE: WARNING: undefined reference to function: SVC_Handler
KLEE: WARNING: undefined reference to function: SysTick_Handler
KLEE: WARNING: undefined reference to function: UsageFault_Handler
KLEE: WARNING: undefined reference to function: inception_dump_registers
KLEE: WARNING: undefined reference to function: inception_warning
KLEE: WARNING: undefined reference to function: printf
KLEE: WARNING: unresolved symbol: .str, allocating at a host address
KLEE: WARNING: unresolved symbol: .str1, allocating at a host address
KLEE: WARNING: unresolved symbol: .str2, allocating at a host address
KLEE: WARNING: unresolved symbol: .str3, allocating at a host address
KLEE: WARNING: unresolved symbol: __PRETTY_FUNCTION__.main, allocating at a host address
KLEE: WARNING: unresolved symbol: .str4, allocating at a host address
KLEE: WARNING: unresolved symbol: R0, allocating at a host address
KLEE: WARNING: unresolved symbol: R4, allocating at a host address
KLEE: WARNING: unresolved symbol: R7, allocating at a host address
KLEE: WARNING: unresolved symbol: LR, allocating at a host address
KLEE: WARNING: unresolved symbol: SP, allocating at a host address
KLEE: WARNING: unresolved symbol: R3, allocating at a host address
KLEE: WARNING: unresolved symbol: NF, allocating at a host address
KLEE: WARNING: unresolved symbol: ZF, allocating at a host address
KLEE: WARNING: unresolved symbol: VF, allocating at a host address
KLEE: WARNING: unresolved symbol: CF, allocating at a host address
KLEE: WARNING: unresolved symbol: CPSR, allocating at a host address
KLEE: WARNING: unresolved symbol: PC, allocating at a host address
KLEE: Memory Object .stack at 0x20000000 of size 0x2008 -> internal
KLEE: WARNING: unresolved symbol: CONTROL_1, allocating at a host address
KLEE: WARNING: unresolved symbol: MSP, allocating at a host address
KLEE: WARNING: unresolved symbol: PSP, allocating at a host address
KLEE: Memory Object .interrupt_vector at 0x10000000 of size 0x40 -> internal
KLEE: WARNING: unresolved symbol: QF, allocating at a host address
KLEE: WARNING: unresolved symbol: R12, allocating at a host address
KLEE: WARNING: unresolved symbol: R2, allocating at a host address
KLEE: WARNING: unresolved symbol: R1, allocating at a host address
KLEE: WARNING: unresolved symbol: inception_icp_error_message_filename, allocating at a host address
KLEE: WARNING: unresolved symbol: inception_icp_error_message_message, allocating at a host address
KLEE: WARNING: unresolved symbol: inception_icp_error_line, allocating at a host address
KLEE: WARNING: unresolved symbol: inception_icp_error_message_suffix, allocating at a host address
KLEE: Memory Object ADC at 0x40012400 of size 0x3ff -> redirected
KLEE: Memory Object AES at 0x50060000 of size 0x3ff -> redirected
KLEE: Memory Object COMP at 0x40007c00 of size 0x3 -> redirected
KLEE: Memory Object CRC at 0x40023000 of size 0x3ff -> redirected
KLEE: Memory Object DAC at 0x40007400 of size 0x3ff -> redirected
KLEE: Memory Object DMA1 at 0x40026000 of size 0x3ff -> redirected
KLEE: Memory Object DMA2 at 0x40026400 of size 0x3ff -> redirected
KLEE: Memory Object EXTI at 0x40010400 of size 0x3ff -> redirected
KLEE: Memory Object FLASH at 0x40023c00 of size 0x3ff -> redirected
KLEE: Memory Object FSMC at 0xa0000000 of size 0xfff -> redirected
KLEE: Memory Object GPIOA at 0x40020000 of size 0x3ff -> redirected
KLEE: Memory Object GPIOB at 0x40020400 of size 0x3ff -> redirected
KLEE: Memory Object GPIOC at 0x40020800 of size 0x3ff -> redirected
KLEE: Memory Object GPIOD at 0x40020c00 of size 0x3ff -> redirected
KLEE: Memory Object GPIOE at 0x40021000 of size 0x3ff -> redirected
KLEE: Memory Object GPIOF at 0x40021800 of size 0x3ff -> redirected
KLEE: Memory Object GPIOG at 0x40021c00 of size 0x3ff -> redirected
KLEE: Memory Object GPIOH at 0x40021400 of size 0x3ff -> redirected
KLEE: Memory Object I2C1 at 0x40005400 of size 0x3ff -> redirected
KLEE: Memory Object I2C2 at 0x40005800 of size 0x3ff -> redirected
KLEE: Memory Object IWDG at 0x40003000 of size 0x3ff -> redirected
KLEE: Memory Object LCD at 0x40002400 of size 0x3ff -> redirected
KLEE: Memory Object NVIC at 0xe000e100 of size 0xe04 -> redirected
KLEE: Memory Object OPAMP at 0x40007c5c of size 0x3a3 -> redirected
KLEE: Memory Object PERIPH_BB_ALIAS_1 at 0x42470000 of size 0x4 -> redirected
KLEE: Memory Object PERIPH_BB_ALIAS_2 at 0x42470060 of size 0x4 -> redirected
KLEE: Memory Object PWR at 0x40007000 of size 0x3ff -> redirected
KLEE: Memory Object RCC at 0x40023800 of size 0x3ff -> redirected
KLEE: Memory Object RI at 0x40007c04 of size 0x57 -> redirected
KLEE: Memory Object RTC at 0x40002800 of size 0x3ff -> redirected
KLEE: Memory Object SCU at 0xe000ed00 of size 0xe4 -> redirected
KLEE: Memory Object SDIO at 0x40012c00 of size 0x3ff -> redirected
KLEE: Memory Object SPI1 at 0x40013000 of size 0x3ff -> redirected
KLEE: Memory Object SPI2 at 0x40003800 of size 0x3ff -> redirected
KLEE: Memory Object SPI3 at 0x40003c00 of size 0x3ff -> redirected
KLEE: Memory Object SYSCFG at 0x40010000 of size 0x3ff -> redirected
KLEE: Memory Object Systick at 0xe000e010 of size 0x10 -> redirected
KLEE: Memory Object TIM10 at 0x40010c00 of size 0x3ff -> redirected
KLEE: Memory Object TIM11 at 0x40011000 of size 0x3ff -> redirected
KLEE: Memory Object TIM2 at 0x40000000 of size 0x3ff -> redirected
KLEE: Memory Object TIM3 at 0x40000400 of size 0x3ff -> redirected
KLEE: Memory Object TIM4 at 0x40000800 of size 0x3ff -> redirected
KLEE: Memory Object TIM5 at 0x40000c00 of size 0x3ff -> redirected
KLEE: Memory Object TIM6 at 0x40001000 of size 0x3ff -> redirected
KLEE: Memory Object TIM7 at 0x40001400 of size 0x3ff -> redirected
KLEE: Memory Object TIM9 at 0x40010800 of size 0x3ff -> redirected
KLEE: Memory Object USART1 at 0x40013800 of size 0x3ff -> redirected
KLEE: Memory Object USART2 at 0x40004400 of size 0x3ff -> redirected
KLEE: Memory Object USART3 at 0x40004800 of size 0x3ff -> redirected
KLEE: Memory Object USART4 at 0x40004c00 of size 0x3ff -> redirected
KLEE: Memory Object USART5 at 0x40005000 of size 0x3ff -> redirected
KLEE: Memory Object USB device FS at 0x40005c00 of size 0x3ff -> redirected
KLEE: Memory Object USB device FS SRAM 512 bytes at 0x40006000 of size 0x3ff -> redirected
KLEE: Memory Object WWDG at 0x40002c00 of size 0x3ff -> redirected
KLEE: WARNING: unresolved symbol: .str5, allocating at a host address
KLEE: WARNING: unresolved symbol: .str16, allocating at a host address
KLEE: WARNING: unresolved symbol: .str27, allocating at a host address
KLEE: WARNING: unresolved symbol: .str38, allocating at a host address
KLEE: WARNING: unresolved symbol: .str14, allocating at a host address
KLEE: WARNING: unresolved symbol: .str25, allocating at a host address
KLEE: WARNING: unresolved symbol: .str6, allocating at a host address
KLEE: WARNING: unresolved symbol: .str17, allocating at a host address
KLEE: WARNING: unresolved symbol: .str28, allocating at a host address
KLEE: [Monitor] adding R0 0x36dfad0
KLEE: [Monitor] adding R4 0x36c37f0
KLEE: [Monitor] adding R7 0x36c3970
KLEE: [Monitor] adding LR 0x369a340
KLEE: [Monitor] adding SP 0x369a420
KLEE: [Monitor] adding R3 0x369a4e0
KLEE: [Monitor] adding NF 0x36b9750
KLEE: [Monitor] adding ZF 0x36b98f0
KLEE: [Monitor] adding VF 0x36b9b20
KLEE: [Monitor] adding CF 0x36b9cc0
KLEE: [Monitor] adding PC 0x36ba060
KLEE: [Monitor] adding .stack 0x20000000
KLEE: [Monitor] adding R12 0x369a530
KLEE: [Monitor] adding R2 0x370cdf0
KLEE: [Monitor] adding R1 0x36c4a60
KLEE: [RealInterrupt] Forwarding option OFF
KLEE: [RealInterrupt] Dynamic interrupt table option ON
KLEE: WARNING: [SymbolsTable] No .data section found
KLEE: WARNING ONCE: calling external: printf(57448752, 10, 55) at /home/inception/tutorial/main.c:50
fibonacci1(10) = 55
fibonacci_golden(10) = 55
ok


KLEE: done: total instructions = 25534
KLEE: done: completed paths = 1
KLEE: done: generated tests = 1

```

You can observe a very detaied log of the memory allocations.
The layout is the same as on the real device, a part from some strings and the processor registers, which are allocated at some separate host address. Besides the variables, you can can see the allocation of the stack section thanks to .stack, and that of the interrupt vector thanks to .interrupt_vector. You can see the memory mapped registers mapped at predefined registers and redirected to the real target. You can also see that klee calls the host printf, and that its output is correct as expected.
Finllay, you can see some stats.

Inception-analyzer runs only if is configured with the config.json file.
This file provides a path to the elf binary, the configuration of redirection, and the mapping of all the mapped registers.
In this example redirection is disabled. We also provide a static interrupt vector mapping, but we do not use it (by default we use the dynamic one in the .interrupt_vector section).

## <a name="Samples"></a>Some more interesting samples

Now that we have an idea about how Inception can be used, we can show some more complex examples taken from [here](https://github.com/Inception-framework/usenix-samples).

### Synthetic tests

We have written a large number of test cases to validate the correct functionality of Inception. Many of them where written and improved over time to catch as many bugs as possible. Some are inspired or taken from real-world cases (e.g., to stress the context switch mechanism used by FreeRTOS). You can find them in ```samples/synthetic_tests```. We will here show a few interesting ones.

#### Interactions

The tests ```interactions``` and  ```interactions2``` aim at testing support for function calls and returns (type and number of parameters, direct/indirect, C to binary and binary to C, etc.). Have a look at the code in ```samples/synthetic_tests/Examples/interactions/main.c``` and ```samples/synthetic_tests/Examples/interactions2/main.c```
Then compile and run them with:
```
./build.sh interactions lpc18xx
```
```
./build.sh interactions2 lpc18xx
```
The build script calls a makefile, sets the configuration script for the board specified as second parameter, and it runs the code in klee.
You can follow the log of Inception-translator and of the memory allocation in Inception-analyzer to follow the steps. Also have a look at the resulting mixed-IR code in ```Examples/interactions/klee-last/assembly.ll``` and ```Examples/interactions2/klee-last/assembly.ll```

#### Multithread

We wrote a few tests for multithreading. Though the code is much simpler than that of an Operating System, it stresses all the main components of Inception-translator and Inception-verifier that handle multithreading. We used them to test our solutions our development. Once stable, Inception was able to run the real multithreading code of FreeRTOS, shown in other samples of this repository.

Remember to ***comment the ---disable-interrupt option in the Makefile***, then type:
```
./build.sh multithread lpc18xx
```

### Complex functions

We have tested a complex arithmetic function of MbedTLS:

```
./build.sh mpi_mul_hlp lpc18xx
```

### Some Klee tests

Here is an example of error detection both in C and assembly.

```
./build.sh 2008-03-04-free-of-global lpc18xx 
```

```
./build.sh 2008-03-04-free-of-global-asm lpc18xx 
```



