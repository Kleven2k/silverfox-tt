open! Core
open! Hardcaml
open! Hardcaml_test_harness

module Bridge = Silverfox.Host_bridge
module Isa = Silverfox.Isa
module Harness = Cyclesim_harness.Make (Bridge.I) (Bridge.O)
let ( <--. ) = Bits.( <--. )
let value signal = Bits.to_unsigned_int !signal
let expect signal expected = [%test_eq: int] (value signal) expected
let instruction opcode arg1 arg2 = Isa.encode ~opcode ~arg1 ~arg2
let halt_instruction = instruction Isa.Opcode.halt 0 0

(* ui_in[0] is RX, ui_in[1] is BYTE_STROBE. Tests set RX directly via
   ui_in and must not clobber the strobe bit when doing so; this tracks
   RX separately and recomposes ui_in on every strobe edge. *)
let rx_bit = ref 1
let set_rx (i : _ Bridge.I.t) bit =
  rx_bit := bit;
  i.ui_in <--. bit
;;
let set_byte_strobe (i : _ Bridge.I.t) strobe =
  i.ui_in <--. (!rx_bit lor (strobe lsl 1))
;;

let with_bridge f =
  Harness.run_advanced
    ~waves_config:Waves_config.no_waves
    ~create:(fun (_scope : Scope.t) i -> Bridge.create i)
    (fun sim ->
      let i = Cyclesim.inputs sim in
      i.rst_n <--. 0;
      i.ena <--. 1;
      set_rx i 1;
      i.uio_in <--. 0;
      Cyclesim.cycle sim;
      i.rst_n <--. 1;
      Cyclesim.cycle sim;
      f sim i (Cyclesim.outputs sim))
;;

(* Drives one byte onto uio_in and pulses byte_strobe for one cycle,
   mirroring what a real host would do: present the byte, strobe it in. *)
let send_byte sim (i : _ Bridge.I.t) byte =
  i.uio_in <--. byte;
  set_byte_strobe i 1;
  Cyclesim.cycle sim;
  set_byte_strobe i 0
;;

(* byte_index has already advanced to 4 by the time the committing byte's
   strobe cycle ends, so the high response byte is on the bus immediately
   -- no extra strobe needed to see it. Strobing then only advances to the
   next byte, consuming whatever is currently on uio_in (driven low here
   since the host has nothing to send on these two cycles). *)
let read_response sim (i : _ Bridge.I.t) (o : _ Bridge.O.t) =
  expect o.uio_oe 0xff;
  let hi = value o.uio_out in
  send_byte sim i 0;
  expect o.uio_oe 0xff;
  let lo = value o.uio_out in
  send_byte sim i 0;
  (hi lsl 8) lor lo
;;

let send_command sim i ~command ~address ~data =
  send_byte sim i command;
  send_byte sim i address;
  send_byte sim i ((data lsr 8) land 0xff);
  send_byte sim i (data land 0xff)
;;

let write_instr sim i address data =
  send_command sim i ~command:Bridge.Command.write_instr ~address ~data;
  ignore (read_response sim i (Cyclesim.outputs sim) : int)
;;

let read_instr sim i address =
  send_command sim i ~command:Bridge.Command.read_instr ~address ~data:0;
  read_response sim i (Cyclesim.outputs sim)
;;

let read_state sim i selector =
  send_command sim i ~command:Bridge.Command.read_state ~address:selector ~data:0;
  read_response sim i (Cyclesim.outputs sim)
;;

let restart sim i =
  send_command sim i ~command:Bridge.Command.restart ~address:0 ~data:0;
  ignore (read_response sim i (Cyclesim.outputs sim) : int)
;;

let halt sim i =
  send_command sim i ~command:Bridge.Command.halt ~address:0 ~data:0;
  ignore (read_response sim i (Cyclesim.outputs sim) : int)
;;

let%test_unit "uio releases the bus outside the two response bytes" =
  with_bridge (fun sim i o ->
    (* Byte 0 (command) and byte 1 (address): uio must stay an input the
       whole time so a real host can drive it without contention. *)
    i.uio_in <--. Bridge.Command.read_state;
    set_byte_strobe i 1;
    Cyclesim.cycle sim;
    set_byte_strobe i 0;
    expect o.uio_oe 0;
    i.uio_in <--. Bridge.State_sel.pc;
    set_byte_strobe i 1;
    Cyclesim.cycle sim;
    set_byte_strobe i 0;
    expect o.uio_oe 0)
;;

let%test_unit "load a program via WRITE_INSTR, restart, and read PC/X/Y/TX back" =
  with_bridge (fun sim i o ->
    ignore (o : _ Bridge.O.t);
    let program =
      [ instruction Isa.Opcode.set Isa.Reg_id.reg_x 42
      ; instruction Isa.Opcode.set Isa.Reg_id.reg_y 7
      ; instruction Isa.Opcode.set Isa.Reg_id.pin_tx 0
      ; halt_instruction
      ]
    in
    List.iteri program ~f:(fun address data -> write_instr sim i address data);
    List.iteri program ~f:(fun address data ->
      [%test_eq: int] (read_instr sim i address) data);
    (* The core keeps executing every clock cycle, including the ones
       spent shifting bridge transaction bytes -- by the time RESTART's
       own 6-byte transaction finishes, this 4-instruction program has
       already run to HALT. Read state after, not immediately after
       restart's response bytes land. *)
    restart sim i;
    [%test_eq: int] (read_state sim i Bridge.State_sel.pc) 3;
    [%test_eq: int] (read_state sim i Bridge.State_sel.x) 42;
    [%test_eq: int] (read_state sim i Bridge.State_sel.y) 7;
    [%test_eq: int] (read_state sim i Bridge.State_sel.tx) 0)
;;

let%test_unit "HALT stops a running program and is idempotent to reissue" =
  with_bridge (fun sim i o ->
    ignore (o : _ Bridge.O.t);
    let wait = instruction Isa.Opcode.wait_ Isa.Reg_id.pin_rx 1 in
    let program = [ wait; halt_instruction ] in
    List.iteri program ~f:(fun address data -> write_instr sim i address data);
    set_rx i 0;
    restart sim i;
    Cyclesim.cycle ~n:4 sim;
    [%test_eq: int] (read_state sim i Bridge.State_sel.pc) 0;
    halt sim i;
    write_instr sim i 0 halt_instruction;
    [%test_eq: int] (read_instr sim i 0) halt_instruction)
;;
