open! Core
open! Hardcaml

(* Internal, clk-synchronous interface for the future host transport.
   Commands are single-cycle strobes, not asynchronous board pins. *)
module I : sig
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a
    ; halt : 'a
    ; restart : 'a
    ; write_enable : 'a
    ; address : 'a
    ; write_data : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { tx : 'a
    ; pc : 'a
    ; x_reg : 'a
    ; y_reg : 'a
    ; running : 'a
    ; halted_by_instruction : 'a
    ; read_data : 'a
    ; read_valid : 'a
    ; write_accepted : 'a
    ; restart_accepted : 'a
    }
  [@@deriving hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t
