open! Core
open! Hardcaml
open! Hardcaml_test_harness

module Bridge = Silverfox.Spi_bridge
module Isa = Silverfox.Isa
module Harness = Cyclesim_harness.Make (Bridge.I) (Bridge.O)
let ( <--. ) = Bits.( <--. )
let value signal = Bits.to_unsigned_int !signal
let expect signal expected = [%test_eq: int] (value signal) expected
let instruction opcode arg1 arg2 = Isa.encode ~opcode ~arg1 ~arg2
let halt_instruction = instruction Isa.Opcode.halt 0 0

(* ui_in[0] is RX (kept idle high), [4]=CS_N, [5]=SCLK, [6]=MOSI. Every
   host-pin write must recompose the whole bus so RX and the two host
   pins not being changed right now keep their last-set value, mirroring
   host_bridge_test.ml's rx_bit tracking. *)
let rx_bit = ref 1
let cs_n = ref 1
let sclk = ref 0
let mosi = ref 0

let drive_ui_in (i : _ Bridge.I.t) =
  i.ui_in <--. (!rx_bit lor (!cs_n lsl 4) lor (!sclk lsl 5) lor (!mosi lsl 6))
;;

let set_rx (i : _ Bridge.I.t) bit =
  rx_bit := bit;
  drive_ui_in i
;;

let deassert_cs sim (i : _ Bridge.I.t) =
  cs_n := 1;
  drive_ui_in i;
  (* Let the CS synchronizer (2 flops) actually settle before returning,
     so a following assert_cs is seen as a fresh falling edge, not a
     glitch still propagating through the synchronizer. *)
  Cyclesim.cycle ~n:2 sim
;;

let assert_cs sim (i : _ Bridge.I.t) =
  cs_n := 0;
  drive_ui_in i;
  Cyclesim.cycle ~n:2 sim
;;

(* One SPI mode-0 bit: present MOSI, raise SCLK (the core samples on this
   rising edge, once it's propagated through the 2-flop synchronizer +
   edge detector), then lower it (the core advances MISO on this falling
   edge). Returns the MISO bit sampled while SCLK was high, i.e. the
   value the core drove in response to the *previous* falling edge. *)
let send_bit sim (i : _ Bridge.I.t) (o : _ Bridge.O.t) bit =
  mosi := bit;
  sclk := 0;
  drive_ui_in i;
  Cyclesim.cycle sim;
  sclk := 1;
  drive_ui_in i;
  Cyclesim.cycle ~n:2 sim;
  let miso_bit = value o.uo_out lsr 1 land 1 in
  sclk := 0;
  drive_ui_in i;
  Cyclesim.cycle ~n:2 sim;
  miso_bit
;;

let send_byte sim i o byte =
  let miso_bits = List.init 8 ~f:(fun bit_index ->
    let bit = (byte lsr (7 - bit_index)) land 1 in
    send_bit sim i o bit)
  in
  List.fold miso_bits ~init:0 ~f:(fun acc bit -> (acc lsl 1) lor bit)
;;

let send_command sim i o ~command ~address ~data =
  ignore (send_byte sim i o command : int);
  ignore (send_byte sim i o address : int);
  ignore (send_byte sim i o ((data lsr 8) land 0xff) : int)
;;

(* Byte 3 (write_data low) is where the command commits; the response is
   captured that same edge, so bytes 4 and 5 (sent as the response is
   shifted out) return the result. *)
let finish_command_and_read_response sim i o ~data_lo =
  let _result = send_byte sim i o data_lo in
  let hi = send_byte sim i o 0 in
  let lo = send_byte sim i o 0 in
  (hi lsl 8) lor lo
;;

let write_instr sim i o address data =
  send_command sim i o ~command:Bridge.Command.write_instr ~address ~data;
  ignore (finish_command_and_read_response sim i o ~data_lo:(data land 0xff) : int)
;;

let read_instr sim i o address =
  send_command sim i o ~command:Bridge.Command.read_instr ~address ~data:0;
  finish_command_and_read_response sim i o ~data_lo:0
;;

let read_state sim i o selector =
  send_command sim i o ~command:Bridge.Command.read_state ~address:selector ~data:0;
  finish_command_and_read_response sim i o ~data_lo:0
;;

let restart sim i o =
  send_command sim i o ~command:Bridge.Command.restart ~address:0 ~data:0;
  ignore (finish_command_and_read_response sim i o ~data_lo:0 : int)
;;

let halt sim i o =
  send_command sim i o ~command:Bridge.Command.halt ~address:0 ~data:0;
  ignore (finish_command_and_read_response sim i o ~data_lo:0 : int)
;;

let%test_unit "Setup/reset harness" =
  with_bridge (fun sim i o ->
    ignore (o : _ Bridge.O.t);
    )