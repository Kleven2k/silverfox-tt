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
    ~create:Isa.hierarchical
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
      tx_trace
      := List.init 6 ~f:(fun _ ->
           cycle ();
           Bits.to_unsigned_int !(outputs.uo_out) land 1));
  [%test_eq: int list] !tx_trace [ 0; 0; 1; 0; 0; 1 ]
;;
