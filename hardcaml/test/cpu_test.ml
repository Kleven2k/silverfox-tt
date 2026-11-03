open! Core
open! Hardcaml
open Silverfox
open Cpu_sim

let load_set_x_b2_halt sim inputs =
  load_instruction
    sim
    inputs
    ~addr:0
    (Isa.Instruction.Set
       (Isa.Set.Reg
          { register = Isa.Register.X
          ; value = Isa.Byte.of_int_exn 0xB2
          }));

  load_instruction
    sim
    inputs
    ~addr:1
    (Isa.Instruction.Sys Isa.Sys.Halt)
;;

let%test_unit "cpu_reset preserves program memory" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.ui_in := Bits.zero Isa.Arch.data_width;
  inputs.uio_in := Bits.zero Isa.Arch.data_width;

  reset_dut sim inputs;
  load_set_x_b2_halt sim inputs;

  (* SET X, 0xB2 *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.x) ~expect:0xB2;

  [%test_result: int] (get_int outputs.pc) ~expect:1;

  (* HALT *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.halt_status) ~expect:Cpu.Halt_status.halt_instruction;
  [%test_result: int] (get_int outputs.pc) ~expect:1;

  (* Restart CPU only. *)
  cpu_restart sim inputs;

  [%test_result: int] (get_int outputs.x) ~expect:0;

  [%test_result: int] (get_int outputs.pc) ~expect:0;

  [%test_result: int] (get_int outputs.halt_status) ~expect:Cpu.Halt_status.running;

  (* Program must still exist. *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.x) ~expect:0xB2;

  [%test_result: int] (get_int outputs.pc) ~expect:1;

  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.halt_status) ~expect:Cpu.Halt_status.halt_instruction
;;

let%test_unit "global reset clears program memory to HALT" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.ui_in := Bits.zero Isa.Arch.data_width;
  inputs.uio_in := Bits.zero Isa.Arch.data_width;

  reset_dut sim inputs;
  load_set_x_b2_halt sim inputs;

  (* Prove loaded program works first. *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.x) ~expect:0xB2;

  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.halt_status) ~expect:Cpu.Halt_status.halt_instruction;

  (* Global reset clears CPU + memory. *)
  reset_dut sim inputs;

  [%test_result: int] (get_int outputs.x) ~expect:0;

  [%test_result: int] (get_int outputs.pc) ~expect:0;

  [%test_result: int] (get_int outputs.halt_status) ~expect:Cpu.Halt_status.running;

  (* Address 0 must now contain reset HALT, not SET X, 0xB2. *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.x) ~expect:0;

  [%test_result: int] (get_int outputs.pc) ~expect:0;

  [%test_result: int] (get_int outputs.halt_status) ~expect:Cpu.Halt_status.halt_instruction
;;

let%test_unit "prog_we pauses CPU execution" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.ui_in := Bits.zero Isa.Arch.data_width;
  inputs.uio_in := Bits.zero Isa.Arch.data_width;

  reset_dut sim inputs;
  load_set_x_b2_halt sim inputs;

  (* Keep programming enabled, writing somewhere harmless. *)
  inputs.prog_we := Bits.vdd;

  set_int
    inputs.prog_addr
    ~width:Isa.Arch.pc_width
    10;

  set_int
    inputs.prog_data
    ~width:Isa.Arch.instruction_width
    0xE000;

  cycle_n sim 3;

  [%test_result: int] (get_int outputs.pc) ~expect:0;

  [%test_result: int] (get_int outputs.x) ~expect:0;

  [%test_result: int] (get_int outputs.halt_status) ~expect:Cpu.Halt_status.running;

  (* Release programming mode. *)
  inputs.prog_we := Bits.gnd;

  Cyclesim.cycle sim;

  [%test_result: int] (get_int outputs.x) ~expect:0xB2;

  [%test_result: int] (get_int outputs.pc) ~expect:1
;;