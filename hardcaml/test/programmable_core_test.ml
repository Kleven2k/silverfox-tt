open! Core
open! Hardcaml
open! Hardcaml_test_harness

module Cpu = Silverfox.Programmable_core
module Isa = Silverfox.Isa
module Harness = Cyclesim_harness.Make (Cpu.I) (Cpu.O)
let ( <--. ) = Bits.( <--. )
let value signal = Bits.to_unsigned_int !signal
let expect signal expected = [%test_eq: int] (value signal) expected
let instruction opcode arg1 arg2 = Isa.encode ~opcode ~arg1 ~arg2
let halt_instruction = instruction Isa.Opcode.halt 0 0

let with_core f =
  Harness.run_advanced
    ~waves_config:Waves_config.no_waves
    ~create:(fun (_scope : Scope.t) i -> Cpu.create i)
    (fun sim ->
      let i = Cyclesim.inputs sim in
      i.rst_n <--. 0;
      i.ena <--. 1;
      i.ui_in <--. 1;
      i.halt <--. 0;
      i.restart <--. 0;
      i.write_enable <--. 0;
      i.address <--. 0;
      i.write_data <--. 0;
      Cyclesim.cycle sim;
      i.rst_n <--. 1;
      Cyclesim.cycle sim;
      f sim i (Cyclesim.outputs sim))
;;

let write sim (i : _ Cpu.I.t) address data =
  i.address <--. address;
  i.write_data <--. data;
  i.write_enable <--. 1;
  Cyclesim.cycle sim;
  i.write_enable <--. 0
;;

let load sim i program =
  List.iteri program ~f:(fun address data -> write sim i address data)
;;

let read sim (i : _ Cpu.I.t) (o : _ Cpu.O.t) address expected =
  i.address <--. address;
  Cyclesim.cycle sim;
  expect o.read_valid 1;
  expect o.read_data expected
;;

let restart sim (i : _ Cpu.I.t) =
  i.restart <--. 1;
  Cyclesim.cycle sim;
  i.restart <--. 0
;;

let%test_unit "load two programs into one core and restart without erasing memory" =
  with_core (fun sim i o ->
    expect o.running 0;
    expect o.halted_by_instruction 0;
    expect o.tx 1;
    for address = 0 to 31 do
      read sim i o address halt_instruction
    done;
    let first =
      [ instruction Isa.Opcode.set Isa.Reg_id.reg_x 42
      ; instruction Isa.Opcode.set Isa.Reg_id.reg_y 7
      ; instruction Isa.Opcode.set Isa.Reg_id.pin_tx 0
      ; halt_instruction
      ]
    in
    load sim i first;
    expect o.tx 1;
    expect o.pc 0;
    List.iteri first ~f:(fun address data -> read sim i o address data);
    restart sim i;
    expect o.running 1;
    expect o.pc 0;
    expect o.x_reg 0;
    Cyclesim.cycle ~n:4 sim;
    expect o.running 0;
    expect o.halted_by_instruction 1;
    expect o.pc 3;
    expect o.x_reg 42;
    expect o.y_reg 7;
    expect o.tx 0;
    Cyclesim.cycle ~n:3 sim;
    expect o.pc 3;
    let second =
      [ instruction Isa.Opcode.set Isa.Reg_id.reg_x 0xa5
      ; instruction Isa.Opcode.out 0 0
      ; halt_instruction
      ; halt_instruction
      ]
    in
    load sim i second;
    expect o.tx 0;
    expect o.x_reg 42;
    restart sim i;
    expect o.halted_by_instruction 0;
    expect o.pc 0;
    expect o.x_reg 0;
    expect o.y_reg 0;
    expect o.tx 1;
    Cyclesim.cycle ~n:3 sim;
    expect o.running 0;
    expect o.halted_by_instruction 1;
    expect o.x_reg 0x52;
    expect o.tx 1;
    List.iteri second ~f:(fun address data -> read sim i o address data);
    restart sim i;
    Cyclesim.cycle ~n:3 sim;
    expect o.x_reg 0x52;
    expect o.halted_by_instruction 1)
;;

let%test_unit "halt interrupts WAIT and suppresses instruction retirement" =
  with_core (fun sim i o ->
    let wait = instruction Isa.Opcode.wait_ Isa.Reg_id.pin_rx 1 in
    load sim i
      [ instruction Isa.Opcode.set Isa.Reg_id.reg_x 42
      ; wait
      ; instruction Isa.Opcode.set Isa.Reg_id.reg_x 99
      ; halt_instruction
      ];
    i.ui_in <--. 0;
    restart sim i;
    Cyclesim.cycle ~n:3 sim;
    expect o.running 1;
    expect o.pc 1;
    expect o.x_reg 42;
    write sim i 1 halt_instruction;
    expect o.write_accepted 0;
    expect o.read_valid 0;
    expect o.read_data 0;
    restart sim i;
    expect o.pc 1;
    expect o.x_reg 42;
    (* Even a satisfied WAIT must not retire on the host HALT edge. *)
    i.ui_in <--. 1;
    i.halt <--. 1;
    Cyclesim.cycle sim;
    i.halt <--. 0;
    expect o.running 0;
    expect o.halted_by_instruction 0;
    expect o.pc 1;
    expect o.x_reg 42;
    read sim i o 1 wait;
    Cyclesim.cycle ~n:3 sim;
    expect o.pc 1;
    restart sim i;
    Cyclesim.cycle ~n:4 sim;
    expect o.x_reg 99;
    expect o.halted_by_instruction 1)
;;

let%test_unit "invalid requests, command conflicts, disable, and reset" =
  with_core (fun sim i o ->
    let wait = instruction Isa.Opcode.wait_ Isa.Reg_id.pin_rx 1 in
    write sim i 0 wait;
    write sim i 32 0;
    expect o.write_accepted 0;
    expect o.read_valid 0;
    expect o.read_data 0;
    write sim i 255 0;
    expect o.write_accepted 0;
    read sim i o 0 wait;
    read sim i o 31 halt_instruction;
    i.restart <--. 1;
    write sim i 0 0;
    expect o.write_accepted 0;
    expect o.restart_accepted 0;
    expect o.running 0;
    i.restart <--. 0;
    read sim i o 0 wait;
    i.halt <--. 1;
    restart sim i;
    expect o.running 0;
    write sim i 0 0;
    expect o.write_accepted 0;
    i.halt <--. 0;
    read sim i o 0 wait;
    i.ui_in <--. 0;
    restart sim i;
    Cyclesim.cycle sim;
    i.ena <--. 0;
    i.ui_in <--. 1;
    Cyclesim.cycle sim;
    expect o.running 0;
    expect o.pc 0;
    write sim i 0 0;
    expect o.write_accepted 0;
    restart sim i;
    expect o.running 0;
    i.ena <--. 1;
    read sim i o 0 wait;
    expect o.running 0;
    restart sim i;
    Cyclesim.cycle ~n:2 sim;
    expect o.halted_by_instruction 1;
    i.rst_n <--. 0;
    i.restart <--. 1;
    write sim i 0 0;
    expect o.running 0;
    expect o.halted_by_instruction 0;
    expect o.pc 0;
    expect o.x_reg 0;
    expect o.y_reg 0;
    expect o.tx 1;
    expect o.write_accepted 0;
    expect o.restart_accepted 0;
    i.restart <--. 0;
    i.rst_n <--. 1;
    for address = 0 to 31 do
      read sim i o address halt_instruction
    done)
;;

let%test_unit "loaded UART program receives a byte and exposes halted state" =
  with_core (fun sim i o ->
    let program =
      Silverfox_programs.Uart.rx_program ~clock_hz:25_000_000 ~baud_rate:115_200
    in
    let program =
      List.mapi program ~f:(fun address word ->
        if address = List.length program - 1 then halt_instruction else word)
    in
    load sim i program;
    restart sim i;
    Cyclesim.cycle ~n:5 sim;
    let byte = 0xb2 in
    let drive bit =
      i.ui_in <--. bit;
      Cyclesim.cycle ~n:217 sim
    in
    drive 0;
    for bit = 0 to 7 do
      drive ((byte lsr bit) land 1)
    done;
    drive 1;
    expect o.running 0;
    expect o.halted_by_instruction 1;
    expect o.x_reg byte;
    (* A following frame cannot overwrite the result after ISA HALT. *)
    drive 0;
    expect o.x_reg byte)
;;
