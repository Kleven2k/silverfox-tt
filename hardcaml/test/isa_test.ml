open! Core 
open Silverfox.Isa 

(* 1. Every instruction in [all] survives encode -> decode unchanged. *)
let check_round_trip ~encode ~decode ~equal ~sexp_of all =
  List.iter all ~f:(fun i ->
    match decode (encode i) with
    | Ok decoded when equal i decoded -> ()
    | Ok decoded ->
      raise_s
        [%message
          "round trip changed the instruction"
            ~before:(sexp_of i : Sexp.t)
            ~after:(sexp_of decoded : Sexp.t)]
    | Error e ->
      raise_s [%message "decode failed" ~instruction:(sexp_of i : Sexp.t) (e : Error.t)])

;;

(* 2. One instruction encodes to a word you computed by hand. *)
let check_encodes ~encode instruction ~expect =
  [%test_result: Int.Hex.t] (encode instruction) ~expect
;;

(* 3. A word must be rejected by decode. *)
let check_illegal ~decode word =
  match decode word with
  | Error _ -> ()
  | Ok _ -> raise_s [%message "expected decode to fall" (word : Int.Hex.t)]
;;

(* --- SET --- *)

let%test_unit "SET: round trip" =
  check_round_trip
    ~encode:Set.encode
    ~decode:Set.decode
    ~equal:Set.equal
    ~sexp_of:Set.sexp_of_t
    Set.all
;;

let%test_unit "SET: reference encodings" =
  check_encodes
    ~encode:Set.encode
    (Reg { register = C; value = Byte.of_int_exn 8 })
    ~expect:0x808;
  check_encodes
    ~encode:Set.encode
    (Gpio { register = Pins_out; operation = Set_bits; mask = Byte.of_int_exn 0x01 })
    ~expect:0x0D01
;;

let%test_unit "SET: illegal words" =
  check_illegal ~decode:Set.decode 0x0100;  (* SET_BITS on X *)
  check_illegal ~decode:Set.decode 0x1800   (* reserved destination 110 *)
;;