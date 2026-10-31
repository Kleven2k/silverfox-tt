open! Core
open! Hardcaml

(* Writable, register-based instruction memory: 32 16-bit-wide instruction
   words with combinational read. Used by [Programmable_core] as the fetch
   source in place of a fixed ROM. *)

module I : sig
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; halted : 'a
    ; write_enable : 'a
    ; write_address : 'a
    ; write_data : 'a
    ; read_address : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { read_data : 'a
    ; write_accepted : 'a
    }
  [@@deriving hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t
