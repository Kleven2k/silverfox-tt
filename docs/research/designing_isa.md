# Designing ISA

Here we will try and design our Instruction Set Architecture (ISA).

We will start by using the PIO RP2040 instruction set, understand it,
and try to see if there is something we could do different.

The PIO Instruction Set:

| Mnemonic | Short Description |
|----------|-------------------|
| JMP      | Set program counter to specified address if specified condition is true. Otherwise, no operation. |
| WAIT | Stall until some condition is met. |
| IN | Shift specified number of bits from specified source into the Input Shift Register.|
| OUT | Shift specified amount of bits out of the Output Shift Register and write those bits to specified destination.
| PUSH | Push the contents of the Input Shift Register into the RX FIFO as a single 32-bit word. Clear Input Shift Register to all-zeroes.|
| PULL | Load a 32-bit word from the TX FIFO into the Output Shift Register. |
| MOV | Copy data from the specified source to the specified destination.| 
| IRQ | Set or clear the IRQ flag selected by the specified index argument.|
| SET | Write specified immediate value to specified destination. |

