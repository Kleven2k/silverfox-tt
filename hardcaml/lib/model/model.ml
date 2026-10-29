open! Core 
open Isa 

(*
 * Silverfox architectural reference model.
 * 
 * Written in plain OCaml. Deliberately no Hardcaml.
 *
 * The model operates one core clock cycle at a time:
 *
 *   step :
*)

(* --- Halt reason --- *)

module Halt_reason = struct 
  type t =
    | Halt_instruction 
    | Illegal_instruction of int 
  [@@deriving sexp_of, compare, equal]
end 

(* --- Inputs --- *)

module Inputs = struct
  type t =
    { ui_in : int
    ; uio_in : int
    }
  [@@deriving sexp_of, compare, equal]

  let zero =
    { ui_in = 0
    ; uio_in = 0
    }
  ;;
end

(* --- Architectural state --- *)

module State = struct 
  type t =
    { pc : int
    ; x : int
    ; y : int
    ; c : int 
    ; pins_out : int
    ; pins_oe : int
    ; uo_out : int
    ; prev_ui : int
    ; prev_uio : int
    ; halt_reason : Halt_reason.t option 
    }
  [@@deriving sexp_of, compare, equal]

  let reset =
    { pc = 0
    ; x = 0
    ; y = 0
    ; c = 0
    ; pins_out = 0
    ; pins_oe = 0
    ; uo_out = 0
    ; prev_ui = 0
    ; prev_uio = 0
    ; halt_reason = None 
    }
  ;;

  let halted t =
    Option.is_some t.halt_reason
  ;;
end 

(* --- Basic helpers --- *)

let mask8 value =
  value land 0xff
;;

let next_pc pc =
  (pc + 1) mod Arch.program_words
;;

let advance_pc (state : State.t) =
  { state with pc = next_pc state.pc }
;;

let pin_mask pin =
  1 lsl Pin.to_int pin 
;;

let write_bit value pin new_bit =
  let mask = pin_mask pin in 

  if new_bit = 0
  then mask8 (value land lnot mask)
  else mask8 (value lor mask)
;;

let bit value pin =
  (value lsr Pin.to_int pin) land 1
;;

(* --- General register helpers --- *)

let read_register (state : State.t) = function 
  | Register .X -> state.x 
  | Y -> state.y 
  | C -> state.c 
;;

(* Convention: functions that update the state take it as their LAST
   argument, so updates chain with [|>], e.g.
   [state |> write_register X 5 |> advance_pc]. *)
let write_register register value (state : State.t) =
  let value = mask8 value in 

  match register with
  | Register.X ->
    { state with x = value }

  | Y ->
    { state with y = value }

  | C ->
    { state with c = value }
;;

(* --- Shift-register helpers --- *)
let read_shift_register register (state : State.t) = 
  match register with 
  | Shift_register.X -> state.x
  | Y -> state.y
;;

let write_shift_register register value (state : State.t) =
  let value = mask8 value in 

  match register with 
  | Shift_register.X ->
    { state with x = value }
  | Y ->
    { state with y = value }
;;

(* --- Input helpers --- *)

let input_bank (inputs : Inputs.t) = function
  | Input_bank.Ui -> inputs.ui_in
  | Uio -> inputs.uio_in
;;

let previous_input_bank (state : State.t) = function
  | Input_bank.Ui -> state.prev_ui
  | Uio -> state.prev_uio
;;

let input_bit inputs bank pin =
  bit (input_bank inputs bank) pin
;;

let previous_input_bit state bank pin =
  bit (previous_input_bank state bank) pin
;;

(* --- Previous-input tracking --- *)

let update_previous_inputs (inputs : Inputs.t) (state : State.t) =
  { state with 
  prev_ui = inputs.ui_in land 0xff
  ; prev_uio = inputs.uio_in land 0xff
  }
;;

(* --- GPIO operation helper --- *)

let apply_gpio_operation ~old_value ~operation ~mask =
  let result =
    match operation with
    | Gpio_operation.Write ->
      mask

    | Set_bits ->
      old_value lor mask 

    | Clear_bits ->
      old_value land lnot mask 

    | Toggle_bits ->
      old_value lxor mask 
  in 

  mask8 result 
;;

let read_gpio register (state : State.t) =
  match register with 
  | Gpio_register.Pins_out -> state.pins_out
  | Pins_oe -> state.pins_oe
  | Uo_out -> state.uo_out
;;

let write_gpio register value (state : State.t) =
  match register with 
  | Gpio_register.Pins_out -> { state with pins_out = value }
  | Pins_oe -> { state with pins_oe = value }
  | Uo_out -> { state with uo_out = value }
;;

(* --- SET --- *)

let execute_set instruction (state : State.t) =
  match instruction with
  | Set.Reg { register; value } ->
    state
    |> write_register register (Byte.to_int value)
    |> advance_pc

  | Set.Gpio { register; operation; mask } ->
    let new_value =
      apply_gpio_operation
        ~old_value:(read_gpio register state)
        ~operation
        ~mask:(Byte.to_int mask)
    in
    state 
    |> write_gpio register new_value 
    |> advance_pc
;;

(* --- WAIT --- *)

let wait_condition_holds (state : State.t) (inputs : Inputs.t) ({ pin; bank; condition } : Wait.t) =
  let current =
  input_bit inputs bank pin
  in 
  
  let previous =
    previous_input_bit state bank pin
  in 

  match condition with 
  | Wait.Condition.Low -> current = 0
  | High -> current = 1
  | Rising -> previous = 0 && current = 1
  | Falling -> previous = 1 && current = 0
;;

let execute_wait (wait : Wait.t) (inputs : Inputs.t) (state : State.t) =
  if wait_condition_holds state inputs wait
  then advance_pc state 
  else state
;;

(* --- IN --- *)

let execute_in ({ pin; bank; destination; order } : In.t) (inputs : Inputs.t) (state : State.t) =
  let sampled_bit = input_bit inputs bank pin in
  let old_value = read_shift_register destination state in
  let new_value =
    match order with 
    | Shift_order.Lsb_first ->
      (sampled_bit lsl 7) lor (old_value lsr 1)
    | Msb_first ->
      (old_value lsl 1) lor sampled_bit
  in

  state 
  |> write_shift_register destination new_value
  |> advance_pc
;;

(* --- OUT --- *)

let output_bit value = function
  | Shift_order.Lsb_first ->
    value land 1
  | Msb_first ->
    (value lsr 7) land 1 
;;

let shift_after_output value = function 
  | Shift_order.Lsb_first ->
    value lsr 1
  | Msb_first -> 
    mask8 (value lsl 1)
;;

let execute_out ({ target; source; order } : Out.t) (state : State.t) =
  let old_value = read_shift_register source state in
  let outgoing_bit = output_bit old_value order in
  let shifted_value = shift_after_output old_value order in

  let state = 
    match target with 
    | Out.Uo { pin } ->
      let uo_out =
        write_bit
          state.uo_out
          pin 
          outgoing_bit
      in
      { state with uo_out }
    
    | Uio { pin; mode = Out.Mode.Push_pull } -> 
      (*
       * Push-pull OUT writes only PINS_OUT.
       *
       * It deliberately leaves PINS_OE untouched.
      *)
      let pins_out =
        write_bit
          state.pins_out 
          pin 
          outgoing_bit
      in
      { state with pins_out }
    
    | Uio { pin; mode = Out.Mode.Open_drain } -> 
      if outgoing_bit = 0
      then (
        (*
        * Open-drain zero:
        *
        *  drive 0
        *)
        let pins_out =
          write_bit
            state.pins_out
            pin 
            0
        in

        let pins_oe = 
          write_bit 
            state.pins_oe
            pin 
            1 
        in

        { state with pins_out 
        ; pins_oe 
        })
      else (
        (*
         * Open-drain one:
         * 
         *  release the line
         *
         * PINS_OUT itself does not matter whole OE=0.
        *)
        let pins_oe =
          write_bit 
            state.pins_oe
            pin 
            0
        in
      
        { state with pins_oe })
  in

  state 
  |> write_shift_register source shifted_value 
  |> advance_pc
;;

(* --- JMP --- *)

let execute_jmp (jump : Jmp.t) (inputs : Inputs.t) (state : State.t) =
  match jump with 
  | Jmp.Always { target } ->
    { state with pc = Target.to_int target }
  | If_zero { register; target } ->
    if read_register state register = 0 
    then 
      { state with pc = Target.to_int target }
    else
      advance_pc state 
  | C_nz_dec { target } ->
    if state.c = 0
    then
      (* No underflow. C stays 0. *)
      advance_pc state 
    else (
      let c = state.c - 1 in 

      if c <> 0
      then
        { state with c; pc = Target.to_int target }
      else
        { (advance_pc state) with c }
    ) 
  | If_pin { level; bank; pin; target } ->
    let actual = 
      input_bit inputs bank pin 
    in

    let expected =
      match level with 
      | Level.Low -> 0
      | High -> 1
    in

    if actual = expected
    then
      { state with pc = Target.to_int target }
    else
      advance_pc state 
;;

(* --- SYS --- *)

let execute_sys (sys : Sys.t) (state : State.t) =
  match sys with
  | Sys.Nop ->
    advance_pc state 
  | Halt ->
    (*
     * PC intentionally remains on the HALT instruction.
    *)
    { state with 
      halt_reason = Some Halt_reason.Halt_instruction
    }
;;