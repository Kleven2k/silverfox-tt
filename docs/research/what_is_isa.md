# Instruction Set Architecture
While using a computer there is a lot going on in the processor (CPU). 
A important part that makes verything work are the ISA (Instruction Set Architecture).

## Instruction Set Architecture (ISA)
ISA tells what operations the CPU can perform, such as
adding numbers, loading data, or jumping to another
instruction.
ISA will define how software communicates with hardware through specific
instruction rules and formats. ISA includes:
- Instruction types (ADD, LOAD, JUMP), registers, data types, and
memory access
- Interrupt handling and system-level communication

## Objective of ISA

To better understand what the aim of an ISA is, we will use MIPS ISA as an example. 
MIPS is an popular example in computer science courses because it's simple and clean.

### Types of Instructions

The instructions of MIPS is divided into three main types:

- Arithmetic/Logic Instructions perform basic operations such 
as ADD, SUB, AND, and OR on data stored in registers.
- Data Transfer Instructions are used to move data between memory
and registers; for example, LW (load word) and SW (store word).
- Branch and Jump Instructions control the execution flow of the 
program, making decisions and handling loops or function calls;
examples include BEQ (branch if equal) and J (jump).

### Instruction Length

MIPS is a 32-bt ISA, this means that every instruction must be exactly
32 bits (4 bytes) long. Fixing the length simplifies the design and makes
it more efficient for both hardware and compiler developers.

### Instruction Formats

With all MIPS instructions being 32 bits long, the ISA defines how those
32 bits are organaized for different instruction types. MIPS uses three
instruction formats:

| Format | Used for |
|--------|----------|
| R-type | Arithmetic and logic operations (eg; ADD, SUB) |
|I-type | Data transfer and conditional branches (eg; LW, BEQ) |
|J-type | Unconditional jumps (eg; J) |

## Microarchitecture vs ISA

Microarchitecture includes components like the ALU for calculations, 
pipelines for faster processing, cache for quick memory access, the
control unit, and execution units.

- Processors with the same ISA, can have very different microarchitectures.
- ISA defines what a CPU can do, while microarchitecture is how the 
CPU is designed internally to carry out those instructions.

## Importance of ISA

1. Foundation of Processor Design
ISA forms the core design element of any processor. Whether it's RISC
(Reduced Instruction Set Computing) or CISC (Complex Instruction Set 
Computing), the choice is ISA impacts all other design decisions.

2. Instruction Execution Understanding

ISA defines what computer architecture often focuses on, like instruction
execution, pipelining, control unit design, and instruction formats.

3. Enables Assembly Language Programming

Understanding ISA is critical for **assembly-level programming**. It helps
in:
- Writing instruction sequences
- Understanding how data is loaded/stored
- Analyzing program execution time

4. Impact on Performance Metrics

A well-designed ISA can lead to efficient hardware implementation
and optimized sofware execution. ISA affects:
- CPI (Cycles Per Instruction)
- Instruction count
- Execution time

5. Compatibility and Portability

ISA determines software compatibility. If two processors implement the same ISA, they can run the same programs — even if their internal microarchitectures are different.

## Types of ISA
There are multiple types of ISA, each designed with different goals in mind, such as simplifying instruction sets for faster execution, supporting complex operations with fewer instructions, or enabling parallel processing to improve performance.

| Type | Description |
|------|-------------|
| RISC | Few, simple instructions for speed |
| CISC | Many complex instructions |
| VLIW | Runs multiple operations on one instruction |
| EPIC | Tries to run things in parallel |
| Stack-based | Uses a stack instead of registers |

## References

[link]()



- [Instruction Set Architecture and Microarchitecture, Geeksforgeeks](https://www.geeksforgeeks.org/computer-organization-architecture/microarchitecture-and-instruction-set-architecture/)