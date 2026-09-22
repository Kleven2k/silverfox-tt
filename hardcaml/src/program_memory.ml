open! Core 
open! Hardcaml
open! Signal 

module I = struct
  type 'a t =
    { clk : 'a 
    ; rst_n : 'a 
    ; halted : 'a
    ; write_enable : 'a 
    ; write_address : 'a [@bits 8]
    ; write_data : 'a [@bits 16]
    ; read_address : 'a [@bits 5]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { read_data : 'a [@bits 16]
    ; write_accepted : 'a 
    }
  [@@deriving hardcaml]
end

let create (i : _ I.t) : _ O.t =
  let spec = Reg_spec.create ~clock:i.clk ~clear:(~:(i.rst_n)) () in
  let halt = of_int_trunc ~width:16 0xe000 in
  (* Keep the full host address until it has been validated. *)
  let address_valid = i.write_address <:. 32 in
  let write_accepted =
    i.rst_n &: i.halted &: i.write_enable &: address_valid
  in
  let words = 
    List.init 32 ~f:(fun address ->
      reg spec
        ~clear_to:halt
        ~enable:(write_accepted &: (i.write_address ==:. address))
        i.write_data)
  in
  { O.read_data = mux i.read_address words; write_accepted }
;;