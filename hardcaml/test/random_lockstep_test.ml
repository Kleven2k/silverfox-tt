open! Core 
open Silverfox
(* --- Pools of legal instruction variants --- *)

let sets = Array.of_list Isa.Set.all
let waits = Array.of_list Isa.Wait.all
let ins = Array.of_list Isa.In.all
let outs = Array.of_list Isa.Out.all
let jmps = Array.of_list Isa.Jmp.all
let movs = Array.of_list Isa.Mov.all

let pick rng array =
  array.(Random.State.int rng (Array.length array))
;;

(* --- Random legal instruction --- *)

let random_instruction rng : Isa.Instruction.t =
  match Random.State.int rng 8 with 
  | 0 ->
    Isa.Instruction.Set (pick rng sets)
  | 1 ->
    Isa.Instruction.Wait (pick rng waits)
  | 2 ->
    Isa.Instruction.In (pick rng ins)
  | 3 ->
    Isa.Instruction.Out (pick rng outs)
  | 4 ->
    Isa.Instruction.Jmp (pick rng jmps)
  | 5 -> 
    Isa.Instruction.Mov (pick rng movs)
  | 6 ->
    (* Keep random delays short so one instruction does not consume
       essentially the entire lockstep run. *)
    let cycles =
      1 + Random.State.int rng 16
    in
    Isa.Instruction.Delay 
      { cycles = Isa.Delay_cycles.of_int_exn cycles }
  | _ ->
    (* SYS is selected 1/8 of the time, but only 1/10 SYS instructions HALT.
       Thus HALT itself is roughly 1/80 of generated legal instructions. *)
    if Random.State.int rng 10 = 0
    then Isa.Instruction.Sys Isa.Sys.Halt
    else Isa.Instruction.Sys Isa.Sys.Nop
;; 

(* --- Random machine word --- *)

let random_word rng =
  if Random.State.int rng 100 < 95
  then 
    Isa.Instruction.encode 
      (random_instruction rng)
  else
    (* Deliberately allow arbitrary words so illegal decode/trap paths are
       exercised in otherwise normal programs. *)
    Random.State.int rng 0x1_0000
;;

(* --- Random program --- *)

let random_program rng =
  let words =
    Array.init Isa.Arch.program_words ~f:(fun _ ->
      random_word rng)
  in

  Model.Program.of_words_exn
    (Array.to_list words)
;;

(* --- Random inputs --- *)

let random_inputs rng : Model.Inputs.t =
  { ui_in = Random.State.int rng 0x100
  ; uio_in = Random.State.int rng 0x100 
  }
;;

let random_input_trace rng ~cycles ~change_every_cycle =
  if change_every_cycle
  then Array.init cycles ~f:(fun _ -> random_inputs rng)
  else (
    (* Hold each random input for a while.
       On average the value changes once every eight cycles. *)
    let current = ref (random_inputs rng) in

    Array.init cycles ~f:(fun _cycle ->
      if Random.State.int rng 8 = 0
      then current := random_inputs rng;
      !current))
;;

(* --- Random lockstep --- *)

let%test_unit "lockstep: random programs" =
  let cycles = 300 in

  for seed = 0 to 199 do 
    let rng = Random.State.make [| seed |] in

    (* Generate the entire program first. *)
    let program = random_program rng in

    (* Alternate input behavior:
        even seed -> entirely new values each cycle
        odd seed -> values change roughly every eight cycles
      
      The complete trace is generated before Lockstep.run_exn so the
      callback itself has no randomness or hidden state. *)
    let input_trace = random_input_trace rng ~cycles ~change_every_cycle:(seed mod 2 = 0) in
    let inputs cycle = input_trace.(cycle) in

    match 
      Or_error.try_with (fun () ->
        Lockstep.run_exn ~inputs ~cycles program)
    with 
    | Ok () ->
      ()
    | Error error ->
      raise_s 
        [%message
          "random lockstep program failed"
            (seed : int)
            (error : Error.t)]
  done
;;