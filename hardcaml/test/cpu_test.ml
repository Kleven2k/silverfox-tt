open! Core
open! Hardcaml
open Silverfox
open Cpu_sim
open Instructions

(* --- Test fixtures --- *)

let load_set_x_b2_halt sim inputs =
  load_instruction sim inputs ~addr:0 (set_reg Isa.Register.X 0xB2);
  load_instruction sim inputs ~addr:1 halt
;;

(* --- Reset / program-memory tests --- *)

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

(* --- prog_we tests --- *)

let%test_unit "prog_we pauses CPU execution" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.ui_in := Bits.zero Isa.Arch.data_width;
  inputs.uio_in := Bits.zero Isa.Arch.data_width;

  reset_dut sim inputs;
  load_set_x_b2_halt sim inputs;

  (* CPU must not execute SET while programming mode is active. *)
  hold_prog_we sim inputs 3;

  [%test_result: int] (get_int outputs.pc) ~expect:0;
  [%test_result: int] (get_int outputs.x) ~expect:0;
  [%test_result: int] 
    (get_int outputs.halt_status) 
    ~expect:Cpu.Halt_status.running;

  (* Release programming mode and execute SET X, 0xB2. *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.x) ~expect:0xB2;
  [%test_result: int] (get_int outputs.pc) ~expect:1
;;

let%test_unit "prog_we freezes DELAY countdown" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.ui_in := Bits.zero Isa.Arch.data_width;
  inputs.uio_in := Bits.zero Isa.Arch.data_width;

  reset_dut sim inputs;

  load_instruction
    sim
    inputs
    ~addr:0
    (delay 5);

  load_instruction
    sim
    inputs
    ~addr:1
    (set_reg Isa.Register.X 0xB2);

  load_instruction
    sim
    inputs
    ~addr:2
    (Isa.Instruction.Sys Isa.Sys.Halt);

  cpu_restart sim inputs;

  (* DELAY 5 starts with remaining=4, then one countdown gives 3. *)
  run_cycles sim inputs 2;

  [%test_result: int] (get_int outputs.pc) ~expect:0;
  [%test_result: int] (get_int outputs.delay_remaining) ~expect:3;

  (* Programming mode must freeze the countdown completely. *)
  hold_prog_we sim inputs 3;

  [%test_result: int] (get_int outputs.pc) ~expect:0;
  [%test_result: int] (get_int outputs.delay_remaining) ~expect:3;

  (* Finish the remaining three countdown cycles. *)
  run_cycles sim inputs 3;

  [%test_result: int] (get_int outputs.pc) ~expect:1;
  [%test_result: int] (get_int outputs.delay_remaining) ~expect:0;
  [%test_result: int] (get_int outputs.x) ~expect:0;

  (* SET executes only now. *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.x) ~expect:0xB2
;;

let%test_unit "prog_we freezes C during C_nz_dec" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.ui_in := Bits.zero Isa.Arch.data_width;
  inputs.uio_in := Bits.zero Isa.Arch.data_width;
  
  reset_dut sim inputs;

  load_instruction
    sim
    inputs 
    ~addr:0
    (set_reg Isa.Register.C 3);

  load_instruction
    sim
    inputs
    ~addr:1
    (jmp_c_nz_dec 1);

  load_instruction
    sim
    inputs
    ~addr:2
    (Isa.Instruction.Sys Isa.Sys.Halt);

  cpu_restart sim inputs;

  (* SET C,3 *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.c) ~expect:3;
  [%test_result: int] (get_int outputs.pc) ~expect:1;

  (* JMP is sitting at PC=1, but programming mode must stop execution. *)
  hold_prog_we sim inputs 3;

  [%test_result: int] (get_int outputs.c) ~expect:3;
  [%test_result: int] (get_int outputs.pc) ~expect:1;

  (* 3 -> 2, jump
     2 -> 1, jump
     1 -> 0, fall through *)
  run_cycles sim inputs 3;

  [%test_result: int] (get_int outputs.c) ~expect:0;
  [%test_result: int] (get_int outputs.pc) ~expect:2
;;

let%test_unit "prog_we does not trap on an illegal instruction" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.ui_in := Bits.zero Isa.Arch.data_width;
  inputs.uio_in := Bits.zero Isa.Arch.data_width;

  reset_dut sim inputs;

  (* OUT open-drain on UO: a reserved encoding, so the decoder marks it
     illegal. *)
  let illegal_word =
    0
    |> Isa.Field.put Isa.Field.opcode (Isa.Opcode.to_bits Isa.Opcode.Out)
    |> Isa.Field.put Isa.Field.bank 1
    |> Isa.Field.put Isa.Field.output_mode 1
  in
  load_word sim inputs ~addr:0 ~data:illegal_word;
  cpu_restart sim inputs;

  (* The CPU sits on the illegal word, but programming mode must stop it
     from fetching, so it must not trap. *)
  hold_prog_we sim inputs 3;

  [%test_result: int] (get_int outputs.pc) ~expect:0;
  [%test_result: int]
    (get_int outputs.halt_status)
    ~expect:Cpu.Halt_status.running;

  (* Released: the first fetch traps. *)
  run_cycles sim inputs 1;

  [%test_result: int] (get_int outputs.pc) ~expect:0;
  [%test_result: int]
    (get_int outputs.halt_status)
    ~expect:Cpu.Halt_status.illegal_instruction
;;
