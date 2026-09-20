open! Core
open! Hardcaml
open! Hardcaml_test_harness
module Isa = Silverfox.Isa
module Uart = Silverfox_programs.Uart
module Debug_harness = Cyclesim_harness.Make (Isa.I) (Isa.Debug_o)

let ( <--. ) = Bits.( <--. )

(* UART TX: verify correct 8-N-1 framing (start=0, 8 data bits LSB-first,
   stop=1) by sampling one cycle per bit-block, at a fixed offset (the
   4th cycle of each 7-cycle block -- comfortably inside the delay loop,
   after TX has settled following that bit's SET, and before the block
   ends), rather than inferring bit boundaries from merged runs in the
   raw per-cycle trace (which the register latency between PC and TX
   makes easy to miscount by hand -- see decisions.md). *)
let%test_unit "UART TX sends byte with correct 8-N-1 framing" =
  let byte_to_send = 0b1011_0010 in
  let clock_hz = 20 in
  let baud_rate = 4 in
  let program = Uart.tx_program ~clock_hz ~baud_rate ~byte:byte_to_send in
  let cycles_per_block = (clock_hz / baud_rate - 1) + 3 in
  (* SET TX; SET X; JMP loop -- 3 non-looped/looped instructions total,
     block length = n + 3 where n = cycles_per_bit - 1. *)
  let num_bits = 10 in
  (* 1 start + 8 data + 1 stop *)
  let sampled_bits = ref [] in
  Debug_harness.run_advanced
    ~waves_config:Waves_config.no_waves
    ~create:(fun (_scope : Scope.t) i -> Isa.create_debug ~program i)
    (fun (sim : Debug_harness.Sim.t) ->
      let inputs = Cyclesim.inputs sim in
      let outputs = Cyclesim.outputs sim in
      let cycle ?n () = Cyclesim.cycle ?n sim in
      inputs.rst_n <--. 0;
      inputs.ena <--. 0;
      inputs.ui_in <--. 0;
      inputs.uio_in <--. 0;
      cycle ~n:2 ();
      inputs.rst_n <--. 1;
      inputs.ena <--. 1;
      for bit_index = 0 to num_bits - 1 do
        for cycle_in_block = 1 to cycles_per_block do
          cycle ();
          if cycle_in_block = 4
          then
            sampled_bits
            := (Bits.to_unsigned_int !(outputs.uo_out) land 1) :: !sampled_bits
        done;
        ignore bit_index
      done);
  let sampled_bits = List.rev !sampled_bits in
  let data_bits = List.init 8 ~f:(fun i -> (byte_to_send lsr i) land 1) in
  let expected_bits = (0 :: data_bits) @ [ 1 ] in
  [%test_eq: int list] sampled_bits expected_bits
;;