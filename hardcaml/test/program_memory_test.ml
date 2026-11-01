open! Core
open! Hardcaml
open Silverfox

module Sim =
  Cyclesim.With_interface
    (Program_memory.I)
    (Program_memory.O)

let create_sim () =
  let scope = Scope.create ~flatten_design:true () in
  Sim.create (Program_memory.create scope)
;;

let set_int signal ~width value =
  signal := Bits.of_unsigned_int ~width value 
;;

let get_int signal =
  Bits.to_unsigned_int !signal
;;

let reset_dut sim (inputs : _ Program_memory.I.t) = 
  inputs.reset := Bits.vdd;
  Cyclesim.cycle sim;
  inputs.reset := Bits.gnd
;;

let write_word sim (inputs : _ Program_memory.I.t) ~addr ~data =
  inputs.write_enable := Bits.vdd;
  set_int inputs.write_addr ~width:6 addr;
  set_int inputs.write_data ~width:16 data;

  Cyclesim.cycle sim;
  inputs.write_enable := Bits.gnd
;;

let read_word sim (inputs : _ Program_memory.I.t) (outputs : _ Program_memory.O.t) addr =
  set_int inputs.read_addr ~width:6 addr;

  (*
   * write_enable is low, so this clock cannot modify memory.
   * Cycling here also causes the simulator to evaluate the
   * combinational read path.
  *)
  Cyclesim.cycle sim;
  get_int outputs.instruction
;;

let%test_unit "program memory resets every word to HALT" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.write_enable := Bits.gnd;

  reset_dut sim inputs;

  for addr = 0 to Isa.Arch.program_words - 1 do 
    let instruction = read_word sim inputs outputs addr in
    [%test_result: Int.Hex.t] instruction ~expect:0xE000
  done 
;;

let%test_unit "program memory writes and reads one word" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  reset_dut sim inputs;

  write_word sim inputs ~addr:5 ~data:0x1234;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 5) ~expect:0x1234
;;

let%test_unit "writing one address does not change other words" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  reset_dut sim inputs;

  write_word sim inputs ~addr:5 ~data:0x1234;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 4) ~expect:0xE000;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 5) ~expect:0x1234;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 6) ~expect:0xE000
;;

let%test_unit "program memory supports full 64-word address range" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  reset_dut sim inputs;

  write_word sim inputs ~addr:0 ~data:0x1111;
  write_word sim inputs ~addr:17 ~data:0x2222;
  write_word sim inputs ~addr:63 ~data:0x3333;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 0) ~expect:0x1111;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 17) ~expect:0x2222;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 63) ~expect:0x3333
;;

let%test_unit "write_enable low prevents writes" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  reset_dut sim inputs;

  inputs.write_enable := Bits.gnd;
  set_int inputs.write_addr ~width:6 7;
  set_int inputs.write_data ~width:16 0xDEAD;

  Cyclesim.cycle sim;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 7) ~expect:0xE000
;;

let%test_unit "program memory can overwrite a word" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  reset_dut sim inputs;

  write_word sim inputs ~addr:10 ~data:0x1111;
  write_word sim inputs ~addr:10 ~data:0x2222;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 10) ~expect:0x2222
;;

let%test_unit "reset restores programmed words to HALT" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  reset_dut sim inputs;

  write_word sim inputs ~addr:3 ~data:0x1234;
  write_word sim inputs ~addr:9 ~data:0xABCD;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 3) ~expect:0x1234;
  [%test_result: Int.Hex.t] (read_word sim inputs outputs 9) ~expect:0xABCD;
  
  reset_dut sim inputs;

  for addr = 0 to Isa.Arch.program_words - 1 do 
    [%test_result: Int.Hex.t] (read_word sim inputs outputs addr) ~expect:0xE000
  done
;;