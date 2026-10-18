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

 
 (* --- Architectural state --- *)
 
 module State = struct 
  type t =
    { pc : int
    ; x : int; y : int; c : int 
    ; pins_out : int
    ; pins_oe : int
    ; uo_out : int
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