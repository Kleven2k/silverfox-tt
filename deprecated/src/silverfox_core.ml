open! Core
open! Hardcaml

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

let create (i : _ I.t) =
  let open Signal in
  (* rst_n is active-low; Hardcaml's Reg_spec ~clear expects active-high, so invert *)
  let rst = ~:(i.rst_n) in
  let spec = Reg_spec.create ~clock:i.clk ~clear:rst () in
  let count = reg_fb spec ~width:8 ~f:(fun d -> d +:. 1) in
  (* Placeholder: gate the counter with ena, echo ui_in on the bidir pins as inputs-only *)
  let uo_out = mux2 i.ena count (zero 8) in
  { O.uo_out; uio_out = zero 8; uio_oe = zero 8 }
;;

let hierarchical scope (i : _ I.t) =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"silverfox_core" (fun (_scope : Scope.t) i -> create i) i
;;
