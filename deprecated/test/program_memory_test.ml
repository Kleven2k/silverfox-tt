open! Core 
open! Hardcaml
open! Hardcaml_test_harness

module Memory = Silverfox.Program_memory
module Harness = Cyclesim_harness.Make (Memory.I) (Memory.O)
let ( <--. ) = Bits.( <--. )

let%test_unit "program memory reset, loading and write protection" =
  Harness.run_advanced
    ~waves_config:Waves_config.no_waves
    ~create:(fun (_scope : Scope.t) i -> Memory.create i)
    (fun (sim : Harness.Sim.t) ->
      let i = Cyclesim.inputs sim in
      let o = Cyclesim.outputs sim in
      let cycle () = Cyclesim.cycle sim in
      let check_word address expected =
        i.write_enable <--. 0;
        i.read_address <--. address;
        cycle ();
        [%test_eq: int] (Bits.to_unsigned_int !(o.read_data)) expected
      in
      let write address data ~accepted =
        i.write_address <--. address;
        i.write_data <--. data;
        i.write_enable <--. 1;
        cycle ();
        [%test_eq: int] (Bits.to_unsigned_int !(o.write_accepted)) accepted;
        i.write_enable <--. 0
      in
      i.rst_n <--. 0;
      i.halted <--. 1;
      i.write_enable <--. 0;
      i.write_address <--. 0;
      i.write_data <--. 0;
      i.read_address <--. 0;
      cycle ();
      i.rst_n <--. 1;
      for address = 0 to 31 do 
        check_word address 0xe000
      done;
      for address = 0 to 31 do 
        write address (0xa500 + address) ~accepted:1
      done;
      for address = 0 to 31 do 
        check_word address (0xa500 + address)
      done;
      i.halted <--. 0;
      write 0 0xffff ~accepted:0;
      check_word 0 0xa500;
      i.halted <--. 1;
      write 32 0xffff ~accepted:0;
      write 255 0xffff ~accepted:0;
      check_word 0 0xa500;
      check_word 31 0xa51f;
      (* Reset wins even with an otherwise valid write request. *)
      i.rst_n <--. 0;
      write 0 0xffff ~accepted:0;
      i.rst_n <--. 1;
      for address = 0 to 31 do
        check_word address 0xe000
      done)
;;