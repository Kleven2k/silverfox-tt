open! Core 
open! Hardcaml 
open Signal 

module I = struct
  type 'a t =
    { clock : 'a 

    (* Global/chip reset.
       Clears CPU state AND program memory. *)
    ; reset : 'a 

    (* CPU-only restart.
       Clears architectural state but preserves program memory. *)
    ; cpu_reset : 'a 

    (* Already synchronized protocol inputs. *)
    ; ui_in : 'a [@bits Isa.Arch.data_width]
    ; uio_in : 'a [@bits Isa.Arch.data_width]

    (* Program-memory host write port. *)
    ; prog_we : 'a 
    ; prog_addr : 'a [@bits Isa.Arch.pc_width]
    ; prog_data : 'a [@bits Isa.Arch.instruction_width]
    }
  [@@deriving hardcaml]
end

module O = struct 
  type 'a t =
    { pc : 'a [@bits Isa.Arch.pc_width]

    ; x : 'a [@bits Isa.Arch.data_width]
    ; y : 'a [@bits Isa.Arch.data_width]
    ; c : 'a [@bits Isa.Arch.data_width]

    ; pins_out : 'a [@bits Isa.Arch.data_width]
    ; pins_oe : 'a [@bits Isa.Arch.data_width]
    ; uo_out : 'a [@bits Isa.Arch.data_width]

    ; prev_ui : 'a [@bits Isa.Arch.data_width]
    ; prev_uio : 'a [@bits Isa.Arch.data_width]

    ; delay_remaining : 'a [@bits Isa.Field.delay.width]

    ; halt_status : 'a [@bits 2]
    }
  [@@deriving hardcaml]
end

module Halt_status = struct
  let running = 0b00
  let halt_instruction = 0b01
  let illegal_instruction = 0b10
end

(* --- ISA encoding helpers --- *)
(*
 * These derive encoding values from Isa rather than 
 * duplicating bit patterns here in the rtl.
*)

let sys_arg1 sys =
  Isa.Field.get Isa.Field.arg1 (Isa.Sys.encode sys)
;;

(* JMP condition codes, derived from Isa. condition_to_bits needs a whole
   Jmp.t, so these use a placeholder target/pin; only the condition matters. *)
let any_target = Isa.Target.of_int_exn 0
let any_pin = Isa.Pin.of_int_exn 0

(* --- CPU --- *)

let create scope (i : _ I.t) =
  (* --- Register specifications --- *)

  (* CPU state is cleared by either:
     - global reset
     - CPU-only restart
     
     Program memory gets only [i.reset], further below. *)
  let cpu_clear = i.reset |: i.cpu_reset in

  let cpu_spec = 
    Reg_spec.create 
      ~clock:i.clock 
      ~clear:cpu_clear
      () 
  in

  (* --- Next-state wires --- *)

  let pc_next = wire Isa.Arch.pc_width in

  let x_next = wire Isa.Arch.data_width in
  let y_next = wire Isa.Arch.data_width in
  let c_next = wire Isa.Arch.data_width in

  let pins_out_next = wire Isa.Arch.data_width in
  let pins_oe_next = wire Isa.Arch.data_width in
  let uo_out_next = wire Isa.Arch.data_width in

  let delay_remaining_next = wire Isa.Field.delay.width in
  let halt_status_next = wire 2 in

  (* --- Architectural state registers --- *)

  let pc = reg cpu_spec ~clear_to:(zero Isa.Arch.pc_width) pc_next in
  
  let x = reg cpu_spec ~clear_to:(zero Isa.Arch.data_width) x_next in
  let y = reg cpu_spec ~clear_to:(zero Isa.Arch.data_width) y_next in
  let c = reg cpu_spec ~clear_to:(zero Isa.Arch.data_width) c_next in

  let pins_out = reg cpu_spec ~clear_to:(zero Isa.Arch.data_width) pins_out_next in
  let pins_oe = reg cpu_spec ~clear_to:(zero Isa.Arch.data_width) pins_oe_next in
  let uo_out = reg cpu_spec ~clear_to:(zero Isa.Arch.data_width) uo_out_next in

  (* Previous input samples update every CPU clock.
  
     During normal execution, programming and HALT they continue tracking
     the external synchronized inputs.
     
     cpu_reset/global reset clears them to zero, matching Model.State.reset. *)
  let prev_ui = reg cpu_spec ~clear_to:(zero Isa.Arch.data_width) i.ui_in in
  let prev_uio = reg cpu_spec ~clear_to:(zero Isa.Arch.data_width) i.uio_in in

  let delay_remaining = reg cpu_spec ~clear_to:(zero Isa.Field.delay.width) delay_remaining_next in
  let halt_status = reg cpu_spec ~clear_to:(zero 2) halt_status_next in

  (* --- Program memory --- *)

  let program_memory =
    Program_memory.create 
      scope 
      { Program_memory.I.clock = i.clock

      (* IMPORTANT:
         cpu_reset is deliberately NOT connected here.
         
         Only global reset clears program memory. *)
      ; reset = i.reset 

      ; read_addr = pc

      ; write_enable = i.prog_we
      ; write_addr = i.prog_addr
      ; write_data = i.prog_data
      }
  in

  (* --- Decoder --- *)

  let decoded = 
    Decoder.create
      scope
      { Decoder.I.instruction = program_memory.instruction }
  in
  
  (* --- Opcode decode --- *)

  let is_set = decoded.opcode ==:. Isa.Opcode.to_bits Isa.Opcode.Set in
  let is_jmp = decoded.opcode ==:. Isa.Opcode.to_bits Isa.Opcode.Jmp in
  let is_sys = decoded.opcode ==:. Isa.Opcode.to_bits Isa.Opcode.Sys in
  let is_delay = decoded.opcode ==:. Isa.Opcode.to_bits Isa.Opcode.Delay in
  let is_wait = decoded.opcode ==:. Isa.Opcode.to_bits Isa.Opcode.Wait in
  let is_in = decoded.opcode ==:. Isa.Opcode.to_bits Isa.Opcode.In in
  let is_out = decoded.opcode ==:. Isa.Opcode.to_bits Isa.Opcode.Out in
  let is_mov = decoded.opcode ==:. Isa.Opcode.to_bits Isa.Opcode.Mov in

  (* --- SYS decode --- *)

  let sys_halt = is_sys &: (decoded.arg1 ==:. sys_arg1 Isa.Sys.Halt) in

  (* SYS NOP needs no special next_state logic.
     It simply follows the normal PC+1 path. *)

  (* --- JMP decode --- *)

  let jmp_condition_is jmp =
    is_jmp &: (decoded.arg1 ==:. Isa.Jmp.condition_to_bits jmp)
  in

  let jmp_always = jmp_condition_is (Always { target = any_target }) in
  let jmp_if_x_zero = jmp_condition_is (If_zero { register = X; target = any_target }) in
  let jmp_if_y_zero = jmp_condition_is (If_zero { register = Y; target = any_target }) in
  let jmp_if_c_zero = jmp_condition_is (If_zero { register = C; target = any_target }) in
  let jmp_c_nz_dec = jmp_condition_is (C_nz_dec { target = any_target }) in
  let jmp_if_pin_low =
    jmp_condition_is (If_pin { level = Low; bank = Uio; pin = any_pin; target = any_target })
  in
  let jmp_if_pin_high =
    jmp_condition_is (If_pin { level = High; bank = Uio; pin = any_pin; target = any_target })
  in

  (* --- SET destination decode --- *)

  (*
   * SET arg1 encoding:
   *
   *   000 X
   *   001 Y
   *   010 C
   *   011 PINS_OUT
   *   100 PINS_OE
   *   101 UO_OUT
   *
   * 110 and 111 are already rejected by decoder.illegal.
  *)

  let set_x = is_set &: (decoded.arg1 ==:. Isa.Register.to_bits Isa.Register.X) in
  let set_y = is_set &: (decoded.arg1 ==:. Isa.Register.to_bits Isa.Register.Y) in
  let set_c = is_set &: (decoded.arg1 ==:. Isa.Register.to_bits Isa.Register.C) in

  let set_pins_out = is_set &: (decoded.arg1 ==:. Isa.Set.gpio_to_bits Isa.Gpio_register.Pins_out) in
  let set_pins_oe = is_set &: (decoded.arg1 ==:. Isa.Set.gpio_to_bits Isa.Gpio_register.Pins_oe) in
  let set_uo_out = is_set &: (decoded.arg1 ==:. Isa.Set.gpio_to_bits Isa.Gpio_register.Uo_out) in

  (* --- SET GPIO operation --- *)

  (*
   * decoded.set_operation:
   *
   *   00 WRITE
   *   01 SET_BITS
   *   10 CLEAR_BITS
   *   11 TOGGLE_BITS
  *)

  let gpio_set_result old_value =
    mux 
      decoded.set_operation
      [ (* WRITE *)
        decoded.set_value

        (* SET_BITS *)
      ; old_value |:(decoded.set_value)

        (* CLEAR_BITS *)
      ; old_value &: ~:(decoded.set_value)

        (* TOGGLE_BITS *) 
      ; old_value ^: decoded.set_value
      ]
  in

  let pins_out_after_set = gpio_set_result pins_out in
  let pins_oe_after_set = gpio_set_result pins_oe in
  let uo_out_after_set = gpio_set_result uo_out in 

  (* --- Global execution control --- *)

  let is_running = halt_status ==:. Halt_status.running in

  (* Program writes pause execution.
  
     This lets the host:
       reset
       load program
       drop prog_we
       run from PC 0
  *)

  (* A DELAY in progress: count down instead of fetching. *)
  let delaying = delay_remaining <>:. 0 in

  let can_fetch = ~:(i.prog_we) &: is_running &: ~:delaying in

  (* One countdown step. prog_we pauses the countdown too. *)
  let delay_tick = ~:(i.prog_we) &: is_running &: delaying in

  (* A legal fetched instruction may execute. *)
  let execute = can_fetch &: ~:(decoded.illegal) in

  (* Illegal fetched instruction traps without advancing PC. *)
  let trap = can_fetch &: decoded.illegal in

  (* Legal SYS.HALT executes, then enters halted state. *)
  let halting = execute &: sys_halt in

  (* DELAY 1 (field = 0) finishes in its own cycle; longer delays hold the
     PC and count down from n - 1. *)
  let delay_start = execute &: is_delay &: (decoded.delay <>:. 0) in
  let delay_done = delay_tick &: (delay_remaining ==:. 1) in

  (* --- PC next-state logic --- *)

  let pc_plus_one = pc +:. 1 in

  (* For now:

       legal ordinary instruction -> PC + 1
       SYS NOP                    -> PC + 1
       JMP taken                  -> jmp_target
       JMP not taken              -> PC + 1
       DELAY 1                    -> PC + 1
       DELAY n > 1 starts         -> hold
       DELAY counting down        -> hold; PC + 1 on the last cycle
       illegal                    -> hold
       already halted             -> hold
       prog_we                    -> hold
       
    Legal but not-yet-implemented instructions temporarily behave as NOPs.
  *)

  (* --- JMP C_nz_dec --- *)

  (* C = 0: fall through, C unchanged (no underflow). 
     C <> 0: C <- C - 1, and jump if the new value is non-zero. *)
  let c_nonzero = c <>:. 0 in
  let c_minus_one = c -:. 1 in

  let c_nz_dec_taken = jmp_c_nz_dec &: c_nonzero &: (c_minus_one <>:. 0) in
  let c_decrement = execute &: jmp_c_nz_dec &: c_nonzero in

  (* --- JMP If_pin --- *)

  (* Selects one input bit, like the model's input_bit: bank chooses ui_in
     or uio_in, pin 0 is the LSB. *)
  let select_bit ~ui ~uio ~bank ~pin =
    let bank_value = mux2 (bank ==:. Isa.Input_bank.to_bits Ui) ui uio in
    mux pin (bits_lsb bank_value)
  in
  
  (* Current inputs (JMP If_pin, WAIT, IN) and previous samples (WAIT edges). *)
  let input_bit = select_bit ~ui:i.ui_in ~uio:i.uio_in in
  let previous_input_bit = select_bit ~ui:prev_ui ~uio:prev_uio in
  let jmp_pin_value = input_bit ~bank:decoded.jmp_bank ~pin:decoded.jmp_pin in
  
  (* The current input pin selected by arg1 + bank.
     Shared by WAIT and IN. *)
  let selected_pin = input_bit ~bank:decoded.bank ~pin:decoded.arg1 in

  (* --- WAIT --- *)

  let wait_previous = previous_input_bit ~bank:decoded.bank ~pin:decoded.arg1 in

  (* Same order as Isa.Wait condition bits: Low 00, High 01, Rising 10, Falling 11. *)
  let wait_holds =
    mux decoded.wait_condition
      [ ~:selected_pin
      ; selected_pin
      ; ~:wait_previous &: selected_pin
      ; wait_previous &: ~:selected_pin
      ]
  in
  let wait_stall = is_wait &: ~:wait_holds in

  (* --- IN --- *)

  (* Shared by IN and OUT: which register (X or Y) and which bit order. *)
  let shift_reg_is_y =
    decoded.shift_register ==:. Isa.Shift_register.to_bits Isa.Shift_register.Y
  in
  let shift_msb_first = decoded.shift_order ==:. Isa.Shift_order.to_bits Isa.Shift_order.Msb_first in

  let in_x = is_in &: ~:shift_reg_is_y in
  let in_y = is_in &: shift_reg_is_y in
  let shift_in old =
    mux2 shift_msb_first
      (* MSB-first:
         old <- { old[6:0], sampled_bit } *)
      (drop_top old ~width:1 @: selected_pin)
      (* LSB-first:
         old <- { sampled_bit, old[7:1] }*)
      (selected_pin @: drop_bottom old ~width:1)
  in

  (* --- OUT --- *)

  (* For OUT, bank 1 = UO, bank 0 = UIO (not the Input_bank encoding). *)
  let out_uo = is_out &: decoded.bank in
  let out_uio = is_out &: ~:(decoded.bank) in
  let open_drain = decoded.output_mode in
  let out_x = is_out &: ~:shift_reg_is_y in
  let out_y = is_out &: shift_reg_is_y in
  let out_source = mux2 shift_reg_is_y y x in
  let outgoing_bit = mux2 shift_msb_first (msb out_source) (lsb out_source) in

  (* Replaces bit [pin] of [value] with [bit]; the other bits are kept. *)
  let write_bit value ~pin bit =
    List.mapi (bits_lsb value) ~f:(fun index old_bit ->
      mux2 (pin ==:. index) bit old_bit)
    |> concat_lsb
  in

  let out_write_uo = out_uo in

  (* Push-pull always writes PINS_OUT.
     Open-drain only writes PINS_OUT when transmitting 0. *)
  let out_write_pins_out = out_uio &: (~:open_drain |: ~:outgoing_bit) in

  (* Open-drain controls OE:
     outgoing 0 -> OE=1, drive low
     outgoing 1 -> OE=0, release *)
  let out_write_pins_oe = out_uio &: open_drain in

  let uo_out_after_out =
    write_bit uo_out ~pin:decoded.arg1 outgoing_bit
  in
  let pins_out_after_out =
    write_bit pins_out ~pin:decoded.arg1 outgoing_bit
  in
  let pins_oe_after_out =
    write_bit pins_oe ~pin:decoded.arg1 (~:outgoing_bit)
  in

  let shift_out value =
    mux2 shift_msb_first
    (* MSB-first:
       { value [6:0], 0 } *)
    (drop_top value ~width:1 @: gnd)
    (* LSB-first:
       { 0, value[7:1] } *)
    (gnd @: drop_bottom value ~width:1)
  in

  (* --- MOV --- *)

  (* Same order as Isa.Mov.Source encoding:
     000 X
     001 Y
     010 C
     011 UI_IN
     100 UIO_IN
     101 PINS_OUT
     110 PINS_OE
     111 UO_OUT
     
     Inputs are the CURRENT samples, not prev_ui / prev_uio. *)
  let mov_value =
    mux 
      decoded.mov_source
      [ x
      ; y
      ; c
      ; i.ui_in 
      ; i.uio_in
      ; pins_out
      ; pins_oe
      ; uo_out
      ]
  in

  (* MOV destination encoding is deliberately different from SET GPIO
     destination encoding. *)
  let mov_to destination =
    is_mov &: (decoded.arg1 ==:. Isa.Mov.Destination.to_bits destination)
  in
  let mov_x = mov_to Isa.Mov.Destination.X in
  let mov_y = mov_to Isa.Mov.Destination.Y in
  let mov_c = mov_to Isa.Mov.Destination.C in
  let mov_pins_out = mov_to Isa.Mov.Destination.Pins_out in
  let mov_pins_oe = mov_to Isa.Mov.Destination.Pins_oe in
  let mov_uo_out = mov_to Isa.Mov.Destination.Uo_out in

  (* --- JMP: is the branch taken? --- *)

  (* Each term already includes is_jmp (via jmp_condition_is).
     Further conditions get OR-ed in here. *)
  let jump_taken = 
    jmp_always
    |: (jmp_if_x_zero &: (x ==:. 0))
    |: (jmp_if_y_zero &: (y ==:. 0))
    |: (jmp_if_c_zero &: (c ==:. 0))
    |: c_nz_dec_taken  
    |: (jmp_if_pin_low &: ~:jmp_pin_value)
    |: (jmp_if_pin_high &: jmp_pin_value)
  in

  let pc_after_execute =
    mux2 jump_taken decoded.jmp_target
      (mux2 (delay_start |: wait_stall) pc
        pc_plus_one)
  in
  let pc_next_value =
    mux2 (execute &: ~:(sys_halt)) pc_after_execute
      (mux2 delay_done pc_plus_one
        pc)
  in

  (* --- X / Y / C next-state logic --- *)

  let x_next_value = 
    mux2 (execute &: set_x)
      decoded.set_value
      (mux2 (execute &: mov_x) mov_value
        (mux2 (execute &: in_x) (shift_in x) 
          (mux2 (execute &: out_x) (shift_out x) x)))
  in
  let y_next_value = 
    mux2 (execute &: set_y) 
      decoded.set_value 
      (mux2 (execute &: mov_y) mov_value
        (mux2 (execute &: in_y) (shift_in y) 
          (mux2 (execute &: out_y) (shift_out y) y))) 
  in
  let c_next_value = 
    mux2 (execute &: set_c) decoded.set_value 
      (mux2 (execute &: mov_c) mov_value
        (mux2 c_decrement c_minus_one 
          c)) 
  in

  (* --- GPIO next-state logic --- *)

  let pins_out_next_value = 
    mux2 (execute &: set_pins_out) pins_out_after_set 
      (mux2 (execute &: mov_pins_out) mov_value
        (mux2 
          (execute &: out_write_pins_out) 
          pins_out_after_out 
          pins_out))
  in
  let pins_oe_next_value = 
    mux2 (execute &: set_pins_oe) pins_oe_after_set 
      (mux2 (execute &: mov_pins_oe) mov_value
        (mux2 
          (execute &: out_write_pins_oe)
          pins_oe_after_out
          pins_oe))
  in
  let uo_out_next_value = 
    mux2 (execute &: set_uo_out) uo_out_after_set
      (mux2 (execute &: mov_uo_out) mov_value
        (mux2
          (execute &: out_write_uo)
          uo_out_after_out
          uo_out))
  in

  (*--- DELAY state --- *)

  let delay_remaining_next_value =
    mux2 delay_tick (delay_remaining -:. 1)
      (mux2 delay_start decoded.delay
        delay_remaining)
  in

  (* --- Halt-status next-state logic --- *)

  let illegal_status = of_int_trunc ~width:2 Halt_status.illegal_instruction in
  let halt_status_value = of_int_trunc ~width:2 Halt_status.halt_instruction in

  (* Priority:

       illegal trap
          >
       SYS HALT
          >
       hold current status

     Holding naturally handles:
       - normal RUNNING operation
       - prog_we pause
       - already HALTed CPU
  *)
  let halt_status_next_value =
    mux2 
      trap
      illegal_status
      (mux2
        halting
        halt_status_value
        halt_status)
  in

  (* --- Connect next-state logic to register inputs --- *)

  pc_next <-- pc_next_value;
  
  x_next <-- x_next_value;
  y_next <-- y_next_value;
  c_next <-- c_next_value;

  pins_out_next <-- pins_out_next_value;
  pins_oe_next <-- pins_oe_next_value;
  uo_out_next <-- uo_out_next_value;

  delay_remaining_next <-- delay_remaining_next_value;
  halt_status_next <-- halt_status_next_value;

  (* --- Outputs --- *)

  { O.pc = pc
  ; x
  ; y
  ; c

  ; pins_out
  ; pins_oe
  ; uo_out
  
  ; prev_ui
  ; prev_uio

  ; delay_remaining
  ; halt_status
  }
;;
