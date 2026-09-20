open! Core
open! Silverfox

(* Computes how many clock cycles correspond to one UART bit period,
   given the design's clock frequency and the target baud rate. E.g.
   25_000_000 Hz / 115_200 baud = 217 cycles per bit. *)
let cycles_per_bit ~clock_hz ~baud_rate = clock_hz / baud_rate

(* Builds an 8-N-1 UART TX program: idle high, 1 start bit (low), 8 data
   bits (LSB-first), 1 stop bit (high) -- 10 bit-periods total.
   [byte] is the fixed value to transmit, baked into this program at
   generation time. [clock_hz]/[baud_rate] set the bit timing. *)
let tx_program ~clock_hz ~baud_rate ~byte =
  (* [n] is the value loaded into the X register for each bit's delay
     loop. X is 8 bits wide (max 255), so cycles_per_bit must fit; the
     "-1" accounts for the SET instruction itself taking one cycle. *)
  let n = cycles_per_bit ~clock_hz ~baud_rate - 1 in
  if n > 255
  then failwith "cycles_per_bit exceeds 8-bit X register range; lower clock_hz or raise baud_rate";
  (* One bit's worth of instructions: drive the TX pin to [tx_value],
     then busy-wait for one bit period via SET X = n followed by a 
     JMP X_NOT_ZERO that loops back to itself ([loop_addr]) until X
     decrements to 0, at which point execution falls through to the
     next bit block. *)
  let bit_block ~tx_value ~loop_addr =
    [ Isa.encode ~opcode:Isa.Opcode.set ~arg1:Isa.Reg_id.pin_tx ~arg2:tx_value
    ; Isa.encode ~opcode:Isa.Opcode.set ~arg1:Isa.Reg_id.reg_x ~arg2:n
    ; Isa.encode ~opcode:Isa.Opcode.jmp ~arg1:Isa.Cond.x_not_zero ~arg2:loop_addr
    ]
  in
  (* [byte]'s 8 bits, extracted LSB-first (bit 0 sent first, per UART
     convention). *)
  let data_bits = List.init 8 ~f:(fun i -> (byte lsr i) land 1) in
  (* Full bit sequence to transmit: start bit (0), the 8 data bits,
     then stop bit (1). *)
  let bits = 0 :: data_bits @ [ 1 ] in
  (* Each bit_block is 3 instructions, so bit [i]'s SET TX starts at
     address [i * 3]; its JMP needs to target the instruction right
     after its won SET X (address [base + 1]), since that's where the
     busy-wait loop should return to on each iteration. *)
  List.concat_mapi bits ~f:(fun i tx_value ->
    let base = i * 3 in
    bit_block ~tx_value ~loop_addr:(base + 2))
;;