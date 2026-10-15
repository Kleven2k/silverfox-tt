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
  | Ok _ -> raise_s [%message "expected decode to fail" (word : Int.Hex.t)]
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

let%test_unit "SET: count 3840" =
  [%test_result: int] (List.length Set.all) ~expect:3840
;;

let%test_unit "SET: reference encodings" =
  check_encodes
    ~encode:Set.encode
    (Reg { register = C; value = Byte.of_int_exn 8 })
    ~expect:0x808;
  check_encodes
    ~encode:Set.encode
    (Gpio { register = Pins_out; operation = Set_bits; mask = Byte.of_int_exn 0x01 })
    ~expect:0x0D01;
  check_encodes 
    ~encode:Set.encode
    (Gpio { register = Pins_oe; operation = Clear_bits; mask = Byte.of_int_exn 0x04 })
    ~expect:0x1204;
  check_encodes 
    ~encode:Set.encode 
    (Gpio { register = Uo_out; operation = Toggle_bits; mask = Byte.of_int_exn 0xFF })
    ~expect:0x17FF;
;;

let%test_unit "SET: illegal words" =
  check_illegal ~decode:Set.decode 0x0100;  (* SET_BITS on X *)
  check_illegal ~decode:Set.decode 0x1800;  (* reserved encoding 110 *)
  check_illegal ~decode:Set.decode 0x1C00   (* reserved encoding 111 *)
;;

(* --- WAIT --- *)

let%test_unit "WAIT: round trip" =
  check_round_trip 
    ~encode:Wait.encode 
    ~decode:Wait.decode 
    ~equal:Wait.equal
    ~sexp_of:Wait.sexp_of_t
    Wait.all
;;

let%test_unit "WAIT: 64 instructions" =
  [%test_result: int] (List.length Wait.all) ~expect:64
;;

let%test_unit "WAIT: reference encodings" = 
  check_encodes ~encode:Wait.encode
    { pin = Pin.of_int_exn 0; bank = Uio; condition = Falling } ~expect:0x0003;
  check_encodes ~encode:Wait.encode
    { pin = Pin.of_int_exn 3; bank = Ui; condition = High } ~expect:0x0C05;
  check_encodes ~encode:Wait.encode 
    { pin = Pin.of_int_exn 7; bank = Ui; condition = Rising } ~expect:0x1C06;
;; 

(* --- IN --- *)

let%test_unit "IN: round trip" =
  check_round_trip 
    ~encode:In.encode
    ~decode:In.decode
    ~equal:In.equal
    ~sexp_of:In.sexp_of_t
    In.all
;;

let%test_unit "IN: 64 instructions" =
  [%test_result: int] (List.length In.all) ~expect:64
;;

let%test_unit "IN: reference encodings" =
  check_encodes ~encode:In.encode 
    { pin = Pin.of_int_exn 0; bank = Uio; destination = X; order = Lsb_first } ~expect:0x0000;
  check_encodes ~encode:In.encode
    { pin = Pin.of_int_exn 5; bank = Ui; destination = Y; order = Msb_first } ~expect:0x1407;
  check_encodes ~encode:In.encode
    { pin = Pin.of_int_exn 2; bank = Uio; destination = Y; order = Lsb_first } ~expect:0x0801;
;;

(* --- OUT --- *)

let%test_unit "OUT: round trip" =
  check_round_trip
    ~encode:Out.encode
    ~decode:Out.decode
    ~equal:Out.equal
    ~sexp_of:Out.sexp_of_t
    Out.all
;;

let%test_unit "OUT: count" =
  [%test_result: int] (List.length Out.all) ~expect:96
;;

let%test_unit "OUT: reference encodings" =
  check_encodes ~encode:Out.encode 
    { target = Uio { pin = Pin.of_int_exn 0; mode = Push_pull }; source = X; order = Lsb_first } ~expect:0x0000;
  check_encodes ~encode:Out.encode 
    { target = Uio { pin = Pin.of_int_exn 4; mode = Open_drain }; source = Y; order = Msb_first } ~expect:0x100B;
  check_encodes ~encode:Out.encode
    { target = Uo { pin = Pin.of_int_exn 7}; source = X; order = Msb_first } ~expect:0x1C06;
;;

let%test_unit "OUT: illegal words" =
  check_illegal ~decode:Out.decode 0x000C;   (* open-drain on UO *)
  check_illegal ~decode:Out.decode 0x1C0F;
;;