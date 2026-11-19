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

  (* --- SYS decode --- *)

  let sys_halt = is_sys &: (decoded.arg1 ==:. sys_arg1 Isa.Sys.Halt) in

  (* SYS NOP needs no special next_state logic.
     It simply follows the normal PC+1 path. *)

  (* --- JMP decode --- *)

  let jmp_condition_is jmp =
    is_jmp &: (decoded.arg1 ==:. Isa.Jmp.condition_to_bits jmp)
  in

  let jmp_always = jmp_condition_is (Always { target = any_target }) in
  let _jmp_if_x_zero = jmp_condition_is (If_zero { register = X; target = any_target }) in
  let _jmp_if_y_zero = jmp_condition_is (If_zero { register = Y; target = any_target }) in
  let _jmp_if_c_zero = jmp_condition_is (If_zero { register = C; target = any_target }) in
  let _jmp_c_nz_dec = jmp_condition_is (C_nz_dec { target = any_target }) in
  let _jmp_if_pin_low =
    jmp_condition_is (If_pin { level = Low; bank = Uio; pin = any_pin; target = any_target })
  in
  let _jmp_if_pin_high =
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
  let can_fetch = ~:(i.prog_we) &: is_running in

  (* A legal fetched instruction may execute. *)
  let execute = can_fetch &: ~:(decoded.illegal) in

  (* Illegal fetched instruction traps without advancing PC. *)
  let trap = can_fetch &: decoded.illegal in

  (* Legal SYS.HALT executes, then enters halted state. *)
  let halting = execute &: sys_halt in

  (* --- PC next-state logic --- *)

  let pc_plus_one = pc +:. 1 in

  (* For now:
  
       legal ordinary instruction -> PC + 1
       SYS NOP                    -> PC + 1
       JMP taken                  -> jmp_target
       JMP not taken              -> PC + 1
       illegal                    -> hold
       already halted             -> hold
       prog_we                    -> hold
       
    Legal but not-yet-implemented instructions temporarily behave as NOPs.
  *)

  (* --- JMP: is the branch taken? --- *)

  (* Each term already includes is_jmp (via jmp_condition_is).
     Further conditions get OR-ed in here. *)
  let jump_taken = jmp_always in

  let pc_after_execute = mux2 jump_taken decoded.jmp_target pc_plus_one in
  let pc_next_value = mux2 (execute &: ~:(sys_halt)) pc_after_execute pc in

  (* --- X / Y / C next-state logic --- *)

  let x_next_value = mux2 (execute &: set_x) decoded.set_value x in
  let y_next_value = mux2 (execute &: set_y) decoded.set_value y in
  let c_next_value = mux2 (execute &: set_c) decoded.set_value c in

  (* --- GPIO next-state logic --- *)

  let pins_out_next_value = mux2 (execute &: set_pins_out) pins_out_after_set pins_out in
  let pins_oe_next_value = mux2 (execute &: set_pins_oe) pins_oe_after_set pins_oe in
  let uo_out_next_value = mux2 (execute &: set_uo_out) uo_out_after_set uo_out in

  (*--- DELAY state --- *)

  (* DELAY is not implemented yet, so hold this register. *)
  let delay_remaining_next_value = delay_remaining in

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