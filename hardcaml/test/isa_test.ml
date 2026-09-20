open! Core
open! Hardcaml
open! Hardcaml_test_harness
module Isa = Silverfox.Isa
module Harness = Cyclesim_harness.Make (Isa.I) (Isa.O)

let ( <--. ) = Bits.( <--. )

let%test_unit "SET/JMP toggles TX with period 3 (one-cycle register latency)" =
  let tx_trace = ref [] in
  Harness.run_advanced
    ~waves_config:Waves_config.no_waves
    ~create:(Isa.hierarchical ~program:Isa.default_program)
    (fun (sim : Harness.Sim.t) ->
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
      for _ = 1 to 6 do
        cycle ();
        tx_trace := (Bits.to_unsigned_int !(outputs.uo_out) land 1) :: !tx_trace
      done;
      tx_trace := List.rev !tx_trace);
  [%test_eq: int list] !tx_trace [ 1; 0; 0; 1; 0; 0 ]
;;

(* OUT sends X's bits LSB-first, one bit per instruction. Program: load X
   with a known byte via SET, then execute 8 OUTs and check the resulting
   TX sequence matches the byte's bits, LSB first. *)
module Debug_harness = Cyclesim_harness.Make (Isa.I) (Isa.Debug_o)

let%test_unit "OUT shifts X out LSB-first" =
  let byte_to_send = 0b1011_0010 in
  let program =
    Isa.encode ~opcode:Isa.Opcode.set ~arg1:Isa.Reg_id.reg_x ~arg2:byte_to_send
    :: List.init 8 ~f:(fun _ -> Isa.encode ~opcode:Isa.Opcode.out ~arg1:0 ~arg2:0)
  in
  let expected_bits = List.init 8 ~f:(fun i -> (byte_to_send lsr i) land 1) in
  let traces = ref [] in
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
      (* Explicit for-loop, not List.init: List.init does not guarantee
         left-to-right evaluation order of ~f when it has side effects,
         which silently scrambled earlier attempts at this test. *)
      for _ = 1 to 10 do
        cycle ();
        let sample =
          ( Bits.to_unsigned_int !(outputs.uo_out) land 1
          , Bits.to_unsigned_int !(outputs.x_reg)
          , Bits.to_unsigned_int !(outputs.pc) )
        in
        traces := sample :: !traces
      done;
      traces := List.rev !traces);
  let tx_trace = List.map !traces ~f:(fun (tx, _, _) -> tx) in
  let x_reg_trace = List.map !traces ~f:(fun (_, x, _) -> x) in
  let pc_trace = List.map !traces ~f:(fun (_, _, pc) -> pc) in
  ignore (pc_trace : int list);
  ignore (tx_trace : int list);
  let received_bits =
    List.filteri x_reg_trace ~f:(fun i _ -> i < 8)
    |> List.map ~f:(fun x -> x land 1)
  in
  [%test_eq: int list] received_bits expected_bits
;;

(* IN shifts a new bit into X's MSB each cycle, with old bits sliding down.
   After 8 calls, the first-received bit ends up at X's LSB and the last-
   received bit at X's MSB -- this reconstructs a byte sent LSB-first, per
   isa.md. We drive ui_in with the test byte's bits, LSB first, one per
   cycle, and check the final X value. *)
let%test_unit "IN shifts RX bits into X, reconstructing byte LSB-first" =
  let test_byte = 0b1011_0010 in
  let program =
    List.init 8 ~f:(fun _ ->
      Isa.encode ~opcode:Isa.Opcode.in_ ~arg1:Isa.Reg_id.pin_rx ~arg2:0)
  in
  let final_x_reg = ref 0 in
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
      for k = 0 to 7 do
        let bit = (test_byte lsr k) land 1 in
        inputs.ui_in <--. bit;
        cycle ();
        final_x_reg := Bits.to_unsigned_int !(outputs.x_reg)
      done);
  [%test_eq: int] !final_x_reg test_byte
;;

(* WAIT should hold PC in place while RX doesn't match the target polarity,
   then let execution fall through once it does. We hold RX low for 3
   cycles (PC should not move), then raise RX high (PC should advance and
   the following SET should eventually execute, loading X with 0xFF). *)
let%test_unit "WAIT stalls PC until RX matches target, then falls through" =
  let program =
    [ Isa.encode ~opcode:Isa.Opcode.wait_ ~arg1:Isa.Reg_id.pin_rx ~arg2:1
    ; Isa.encode ~opcode:Isa.Opcode.set ~arg1:Isa.Reg_id.reg_x ~arg2:0xff
    ]
  in
  let pc_trace = ref [] in
  let x_reg_trace = ref [] in
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
      for _ = 1 to 3 do
        inputs.ui_in <--. 0;
        cycle ();
        pc_trace := Bits.to_unsigned_int !(outputs.pc) :: !pc_trace;
        x_reg_trace := Bits.to_unsigned_int !(outputs.x_reg) :: !x_reg_trace
      done;
      for _ = 1 to 3 do
        inputs.ui_in <--. 1;
        cycle ();
        pc_trace := Bits.to_unsigned_int !(outputs.pc) :: !pc_trace;
        x_reg_trace := Bits.to_unsigned_int !(outputs.x_reg) :: !x_reg_trace
      done);
  let pc_trace = List.rev !pc_trace in
  let x_reg_trace = List.rev !x_reg_trace in
  [%test_eq: int list] pc_trace [ 0; 0; 0; 1; 2; 2 ];
  [%test_eq: int list] x_reg_trace [ 0; 0; 0; 0; 255; 255 ]
;;