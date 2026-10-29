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
    }
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

let bit value pin =
  (value lsr Pin.to_int pin) land 1
;;

(* --- General register helpers --- *)

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