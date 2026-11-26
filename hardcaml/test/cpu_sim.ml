open! Core 
open! Hardcaml
open Silverfox 

module Sim =
  Cyclesim.With_interface
    (Cpu.I)
    (Cpu.O)

let create_sim () =
  let scope =
    Scope.create ~flatten_design:true ()
  in
  Sim.create (Cpu.create scope)
;;

let set_int signal ~width value =
  signal := Bits.of_unsigned_int ~width value 
;;

let get_int signal =
  Bits.to_unsigned_int !signal 
;;

let cycle_n sim n = 
  for _ = 1 to n do 
    Cyclesim.cycle sim
  done
;;

let reset_dut sim (inputs : _ Cpu.I.t) =
  inputs.reset := Bits.vdd;
  inputs.cpu_reset := Bits.gnd;
  inputs.prog_we := Bits.gnd;

  Cyclesim.cycle sim;

  inputs.reset := Bits.gnd
;;

let cpu_restart sim (inputs : _ Cpu.I.t) =
  inputs.reset := Bits.gnd;
  inputs.cpu_reset := Bits.vdd;
  inputs.prog_we := Bits.gnd;

  Cyclesim.cycle sim;

  inputs.cpu_reset := Bits.gnd
;;

let load_word sim (inputs : _ Cpu.I.t) ~addr ~data =
  inputs.prog_we := Bits.vdd;

  set_int
    inputs.prog_addr
    ~width:Isa.Arch.pc_width
    addr;

  set_int
    inputs.prog_data
    ~width:Isa.Arch.instruction_width
    data;

  Cyclesim.cycle sim;

  inputs.prog_we := Bits.gnd
;;

let load_instruction sim inputs ~addr instruction =
  load_word
    sim
    inputs
    ~addr
    ~data:(Isa.Instruction.encode instruction)
;;

(* Hold programming mode active without changing the program under test.
   Address 63 is repeatedly written with HALT, its reset value.
   
   Use this only on tests where the last program word is intentionally unused. *)
let hold_prog_we sim (inputs : _ Cpu.I.t) n =
  inputs.prog_we := Bits.vdd;

  set_int
    inputs.prog_addr
    ~width:Isa.Arch.pc_width
    (Isa.Arch.program_words - 1);

  set_int 
    inputs.prog_data
    ~width:Isa.Arch.instruction_width
    (Isa.Instruction.encode
      (Isa.Instruction.Sys Isa.Sys.Halt));

  cycle_n sim n;

  inputs.prog_we := Bits.gnd
;; 

(* --- Execution helpers --- *)

let run_cycles sim (inputs : _ Cpu.I.t) n =
  inputs.prog_we := Bits.gnd;
  cycle_n sim n
;;