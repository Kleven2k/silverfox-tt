open! Core
open! Hardcaml

(* Crude, pin-driven host loader standing in for the SPI transport
   described in docs/host-interface.md: a byte-wide bus on uio, advanced
   by a strobe on ui_in[1], enough to load and read back a program
   through real TT pins with no RTL regeneration in between. Matches
   Tiny Tapeout's required top-level interface exactly -- this module IS
   the TT top level, wrapping [Programmable_core] and [Program_memory]
   underneath it. *)

module Command : sig
  val halt : int
  val restart : int
  val write_instr : int
  val read_instr : int
  val read_state : int
end

module State_sel : sig
  val pc : int
  val x : int
  val y : int
  val tx : int
end

module I : sig
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a
    ; uio_in : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { uo_out : 'a
    ; uio_out : 'a
    ; uio_oe : 'a
    }
  [@@deriving hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t
val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t
