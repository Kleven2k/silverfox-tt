open! Core 
open! Hardcaml
open Silverfox

(* --- Convert the observable RTL state into the architectural model state. --- *)

let state_of_rtl ~(program : Model.Program.t) (outputs : _ Cpu.O.t) =
  let pc = Cpu_sim.get_int outputs.pc in
  let halt_status = Cpu_sim.get_int outputs.halt_status in

  let halt_reason =
    if halt_status = Cpu.Halt_status.running 
      then None
    else if halt_status = Cpu.Halt_status.halt_instruction
      then Some Model.Halt_reason.Halt_instruction
    else if halt_status = Cpu.Halt_status.illegal_instruction
    then 
      Some
        (Model.Halt_reason.Illegal_instruction
          program.(pc))
    else
      raise_s
        [%message
          "RTL produced reserved halt status"
            (halt_status : int)]
  in

  { Model.State.pc 
  ; x = Cpu_sim.get_int outputs.x
  ; y = Cpu_sim.get_int outputs.y 
  ; c = Cpu_sim.get_int outputs.c

  ; pins_out = Cpu_sim.get_int outputs.pins_out
  ; pins_oe = Cpu_sim.get_int outputs.pins_oe
  ; uo_out = Cpu_sim.get_int outputs.uo_out

  ; prev_ui = Cpu_sim.get_int outputs.prev_ui
  ; prev_uio = Cpu_sim.get_int outputs.prev_uio

  ; delay_remaining = Cpu_sim.get_int outputs.delay_remaining

  ; halt_reason 
  }
;;

(* --- Drive one architectural input sample into the RTL. --- *)

let drive_inputs (rtl_inputs : _ Cpu.I.t) (inputs : Model.Inputs.t) =
  Cpu_sim.set_int rtl_inputs.ui_in ~width:Isa.Arch.data_width inputs.ui_in;
  Cpu_sim.set_int rtl_inputs.uio_in ~width:Isa.Arch.data_width inputs.uio_in
;;

(* --- Compare one RTL state against the model. --- *)

let check_state_exn ~cycle ~(program : Model.Program.t) ~(before : Model.State.t) ~(expected : Model.State.t) ~(actual : Model.State.t) =
  if not (Model.State.equal expected actual)
  then (
    (* Report the instruction that CAUSED the transition.
    
       [expected.pc] may already point at the following instruction, so use
       the pre-cycle PC instead. *)
  let pc_before = before.pc in
  let word = program.(pc_before) in
  let decoded = Isa.Instruction.decode word in
  
  raise_s
    [%message
      "RTL/model lockstep mismatch"
        (cycle : int)
        (pc_before : int)
        (word : Int.Hex.t)
        (decoded : Isa.Instruction.t Or_error.t)
        (expected : Model.State.t)
        (actual : Model.State.t)])
;;

(* --- Load every word, including HALT-filled unused words. --- *)

let load_program_exn sim rtl_inputs (program : Model.Program.t) =
  if Array.length program <> Isa.Arch.program_words
  then
    raise_s
      [%message
        "Program has wrong number of words"
          (Array.length program : int)
          (Isa.Arch.program_words : int)];

  Array.iteri program ~f:(fun addr word ->
    Cpu_sim.load_word
      sim
      rtl_inputs
      ~addr
      ~data:word)
;;

(* --- Run model + RTL cycle-for-cycle. --- *)

let run_exn ?(inputs = fun _cycle -> Model.Inputs.zero) ~cycles (program : Model.Program.t) =
  if cycles < 0
  then 
  invalid_arg
    "Lockstep.run_exn: cycles must be non-negative";

  (* Evaluate the input function once.
  
     Both machines then consume exactly the same samples. *)
  let input_trace = Array.init cycles ~f:inputs in
  let model_inputs cycle = input_trace.(cycle) in
  let expected_states = 
    Model.run
      Model.State.reset
      ~program
      ~cycles
      ~inputs:model_inputs
  in

  if List.length expected_states <> cycles + 1
  then
    raise_s
      [%message
        "Model.run returned wrong number of states"
          (List.length expected_states : int)
          (cycles : int)];
  
  (* --- Set up RTL --- *)

  let sim = Cpu_sim.create_sim () in
  let rtl_inputs = Cyclesim.inputs sim in 
  let rtl_outputs = Cyclesim.outputs sim in 

  rtl_inputs.ui_in := Bits.zero Isa.Arch.data_width;
  rtl_inputs.uio_in := Bits.zero Isa.Arch.data_width;

  rtl_inputs.reset := Bits.gnd;
  rtl_inputs.cpu_reset := Bits.gnd;
  rtl_inputs.prog_we := Bits.gnd;

  (* Global reset clears both CPU and PMEM. *)
  Cpu_sim.reset_dut sim rtl_inputs;

  (* Load complete 64-word image. *)
  load_program_exn sim rtl_inputs program;

  (* Restore architectural CPU state without erasing PMEM. *)
  Cpu_sim.cpu_restart sim rtl_inputs;

  (* --- State 0: immediately after CPU restart --- *)

  let expected_initial = List.hd_exn expected_states in 
  let actual_initial = state_of_rtl ~program rtl_outputs in

  check_state_exn ~cycle:0 ~program ~before:expected_initial ~expected:expected_initial ~actual:actual_initial;

  (* --- Execution --- *)

  for cycle = 0 to cycles - 1 do 
    let before = List.nth_exn expected_states cycle in
    let expected = List.nth_exn expected_states (cycle + 1) in

    drive_inputs rtl_inputs input_trace.(cycle);

    Cyclesim.cycle sim;

    let actual = state_of_rtl ~program rtl_outputs in

    check_state_exn ~cycle:(cycle + 1) ~program ~before ~expected ~actual
  done 
;;
