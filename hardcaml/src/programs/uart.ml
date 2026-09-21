open! Core
open! Silverfox

(* Computes how many clock cycles correspond to one UART bit period,
   given the design's clock frequency and the target baud rate. E.g.
   25_000_000 Hz / 115_200 baud = 217 cycles per bit. *)
let cycles_per_bit ~clock_hz ~baud_rate = clock_hz / baud_rate

(* A "SET reg = n; JMP reg_not_zero -> self" busy-wait loop takes exactly
   n + 2 cycles total: 1 cycle for the SET, then n + 1 cycles for the JMP
   to hold while it counts reg down to 0 (confirmed via pc_trace in
   testing). [delay_loop_n ~target ~preceding_instrs] computes the value
   to load into the counter register so the total block -- including any
   instructions that run immediately before the SET/JMP pair -- takes
   exactly [target] cycles. *)
let delay_loop_n ~target ~preceding_instrs =
  let n = target - 2 - preceding_instrs in
  if n < 0
  then
    failwithf
      "delay_loop_n: target (%d) too small for %d preceding instruction(s) \
       plus the minimum 2-cycle SET/JMP overhead"
      target
      preceding_instrs
      ();
  n
;;

(* Builds an 8-N-1 UART TX program: idle high, 1 start bit (low), 8 data
   bits (LSB-first), 1 stop bit (high) -- 10 bit-periods total.
   [byte] is the fixed value to transmit, baked into this program at
   generation time. [clock_hz]/[baud_rate] set the bit timing. *)
let tx_program ~clock_hz ~baud_rate ~byte =
  let cpb = cycles_per_bit ~clock_hz ~baud_rate in
  (* Each bit block is SET TX (1 instruction) followed by the delay loop,
     so the loop must account for that 1 preceding instruction to make
     the whole block last exactly [cpb] cycles. *)
  let n = delay_loop_n ~target:cpb ~preceding_instrs:1 in
  if n > 255
  then failwith "cycles_per_bit exceeds 8-bit X register range; lower clock_hz or raise baud_rate";
  let bit_block ~tx_value ~loop_addr =
    [ Isa.encode ~opcode:Isa.Opcode.set ~arg1:Isa.Reg_id.pin_tx ~arg2:tx_value
    ; Isa.encode ~opcode:Isa.Opcode.set ~arg1:Isa.Reg_id.reg_x ~arg2:n
    ; Isa.encode ~opcode:Isa.Opcode.jmp ~arg1:Isa.Cond.x_not_zero ~arg2:loop_addr
    ]
  in
  let data_bits = List.init 8 ~f:(fun i -> (byte lsr i) land 1) in
  let bits = 0 :: data_bits @ [ 1 ] in
  List.concat_mapi bits ~f:(fun i tx_value ->
    let base = i * 3 in
    bit_block ~tx_value ~loop_addr:(base + 2))
;;

(* Builds an 8-N-1 UART RX program: detects the start-bit edge, waits to
   the midpoint of each bit (for noise-resistant sampling, away from bit
   edges), and reads 8 data bits via IN, which accumulates the received
   byte into X (LSB-first reconstruction, per IN's documented semantics).

   Y is used for all delay-loop timing (separately from X, which IN uses
   to accumulate the byte).

   This program's instruction layout is fixed at exactly 32 instructions
   (the full instruction memory, with no spare room), so there's no space
   left in this version for an explicit stop-bit framing check; the
   receiver simply waits out the stop bit's duration and loops back to
   wait for the next start bit. *)
let rx_program ~clock_hz ~baud_rate =
  let cpb = cycles_per_bit ~clock_hz ~baud_rate in
  let n_full = delay_loop_n ~target:cpb ~preceding_instrs:0 in
  let n_full_after_in = delay_loop_n ~target:cpb ~preceding_instrs:1 in
  let n_half = delay_loop_n ~target:(cpb / 2) ~preceding_instrs:0 in
  if n_full > 255 || n_full_after_in > 255 || n_half > 255
  then failwith "rx_program: a delay count exceeds Y's 8-bit range";
  let delay_block ~base ~delay_n =
    [ Isa.encode ~opcode:Isa.Opcode.set ~arg1:Isa.Reg_id.reg_y ~arg2:delay_n
    ; Isa.encode ~opcode:Isa.Opcode.jmp ~arg1:Isa.Cond.y_not_zero ~arg2:(base + 1)
    ]
  in
  (* Address 0: block until the line drops low (start of a start bit). *)
  let wait_start_bit =
    [ Isa.encode ~opcode:Isa.Opcode.wait_ ~arg1:Isa.Reg_id.pin_rx ~arg2:0 ]
  in
  (* Addresses 1-2: delay ~half a bit period, landing near the middle of
     the start bit. Addresses 3-4: delay one more full bit period,
     landing near the middle of data bit 0. *)
  let half_bit_delay = delay_block ~base:1 ~delay_n:n_half in
  let settle_to_bit0 = delay_block ~base:3 ~delay_n:n_full in
  (* Addresses 5-28: 8 data bits, each IN (1 instruction) followed by a
     full-bit delay_block (2 instructions) = 3 instructions per bit. The
     delay uses [n_full_after_in] since IN is the 1 preceding instruction
     for this block. *)
  let data_bits =
    List.concat_map (List.range 0 8) ~f:(fun i ->
      let in_addr = 5 + (i * 3) in
      [ Isa.encode ~opcode:Isa.Opcode.in_ ~arg1:Isa.Reg_id.pin_rx ~arg2:0 ]
      @ delay_block ~base:(in_addr + 1) ~delay_n:n_full_after_in)
  in
  (* Addresses 29-30: wait out the stop bit's duration (no framing check
     in this version). *)
  let stop_bit_delay = delay_block ~base:29 ~delay_n:n_full in
  (* Address 31: loop back to address 0 for the next byte. *)
  let loop_back = [ Isa.encode ~opcode:Isa.Opcode.jmp ~arg1:Isa.Cond.always ~arg2:0 ] in
  wait_start_bit @ half_bit_delay @ settle_to_bit0 @ data_bits @ stop_bit_delay @ loop_back
;;
