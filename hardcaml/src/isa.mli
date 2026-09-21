open! Core
open! Hardcaml

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

module Opcode : sig
  val set : int
  val wait_ : int
  val in_ : int
  val out : int
  val jmp : int
  val mov : int
  val halt : int
end

module Cond : sig
  val always : int
  val not_tx_valid : int
  val x_not_zero : int
  val rx_high : int
  val y_not_zero : int
end

module Reg_id : sig
  val pin_tx : int
  val pin_tx_ready : int
  val reg_x : int
  val pin_rx : int
  val reg_y : int
end

val pc_width : int
val mem_depth : int
val encode : opcode:int -> arg1:int -> arg2:int -> int
val default_program : int list
val create : program:int list -> Signal.t I.t -> Signal.t O.t
val hierarchical : program:int list -> Scope.t -> Signal.t I.t -> Signal.t O.t

(* Extra output-only interface used solely for testing: exposes the raw
   internal registers ([x_reg], [y_reg], [pc]) so a test can read them
   directly via Cyclesim.outputs, instead of inferring their values
   indirectly through [uo_out] and hand-derived timing offsets -- which is
   what led to a long debugging session for the OUT test (see
   decisions.md). Never used by generate.ml or the real TT submission;
   test-only. *)
module Debug_o : sig
  type 'a t =
    { uo_out : 'a
    ; x_reg : 'a
    ; y_reg : 'a
    ; pc : 'a
    }
  [@@deriving hardcaml]
end

val create_debug : program:int list -> Signal.t I.t -> Signal.t Debug_o.t