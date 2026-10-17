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
    ~expect:0x17FF
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
    { pin = Pin.of_int_exn 7; bank = Ui; condition = Rising } ~expect:0x1C06
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
    { pin = Pin.of_int_exn 2; bank = Uio; destination = Y; order = Lsb_first } ~expect:0x0801
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
    { target = Uo { pin = Pin.of_int_exn 7}; source = X; order = Msb_first } ~expect:0x1C06
;;

let%test_unit "OUT: illegal words" =
  check_illegal ~decode:Out.decode 0x000C;   (* open-drain on UO *)
  check_illegal ~decode:Out.decode 0x1C0F
;;

(* --- JMP --- *)

let%test_unit "JMP: round trip" =
  check_round_trip
    ~encode:Jmp.encode
    ~decode:Jmp.decode
    ~equal:Jmp.equal
    ~sexp_of:Jmp.sexp_of_t
    Jmp.all
;;

let%test_unit "JMP: count" =
  [%test_result: int] (List.length Jmp.all) ~expect:2368
;;

let%test_unit "JMP: reference encodings" =
  check_encodes ~encode:Jmp.encode 
    ( Always { target = Target.of_int_exn 0 }) ~expect:0x0000;
  check_encodes ~encode:Jmp.encode
    ( If_zero { register = Y; target = Target.of_int_exn 5 }) ~expect:0x0805;
  check_encodes ~encode:Jmp.encode 
    ( C_nz_dec { target = Target.of_int_exn 5 }) ~expect:0x1005;
  check_encodes ~encode:Jmp.encode
    ( If_pin { level = High; bank = Ui; pin = Pin.of_int_exn 3; target = Target.of_int_exn 10 }) ~expect:0x1ACA;
  check_encodes ~encode:Jmp.encode
    ( If_pin { level = Low; bank = Uio; pin = Pin.of_int_exn 7; target = Target.of_int_exn 63 }) ~expect:0x15FF
;;

let%test_unit "JMP: illegal words" =
  check_illegal ~decode:Jmp.decode 0x1C00   (* reserved condition 111 *)
  (* Unused-bit words (e.g. 0x0040, ALWAYS with a pin bit) are rejected by
     the top-level decode, not here; tested in the Instruction section. *)
;;

(* --- MOV --- *)

let%test_unit "MOV: round trip" =
  check_round_trip
    ~encode:Mov.encode
    ~decode:Mov.decode 
    ~equal:Mov.equal
    ~sexp_of:Mov.sexp_of_t
    Mov.all
;;

let%test_unit "MOV: count" =
  [%test_result: int] (List.length Mov.all) ~expect:48
;;

let%test_unit "MOV: reference encodings" =
  check_encodes ~encode:Mov.encode
    { Mov.destination = X; source = Ui_in } ~expect:0x0003;
  check_encodes ~encode:Mov.encode
    { Mov.destination = Pins_out; source = X } ~expect:0x1400;
  check_encodes ~encode:Mov.encode
    { Mov.destination = Uo_out; source = Uio_in } ~expect:0x1C04
;;

let%test_unit "MOV: illegal words" =
  check_illegal ~decode:Mov.decode 0x0C00;
  check_illegal ~decode:Mov.decode 0x1001
;;


(* --- DELAY --- *)

let%test_unit "DELAY: round trip" =
  check_round_trip
    ~encode:Delay.encode
    ~decode:Delay.decode 
    ~equal:Delay.equal
    ~sexp_of:Delay.sexp_of_t
    Delay.all
;;

let%test_unit "DELAY: count" =
  [%test_result: int] (List.length Delay.all) ~expect:8192
;;

let%test_unit "DELAY: reference encodings" =
  let delay n = { Delay.cycles = Delay_cycles.of_int_exn n } in
  check_encodes ~encode:Delay.encode (delay 1) ~expect:0x0000;      (* minimum *)
  check_encodes ~encode:Delay.encode (delay 2) ~expect:0x0001;      
  check_encodes ~encode:Delay.encode (delay 8192) ~expect:0x1FFF;   (* maximum *)
  check_encodes ~encode:Delay.encode (delay 102) ~expect:0x0065   
;;

let%test_unit "DELAY: cycle range" =
  assert (Or_error.is_error (Delay_cycles.of_int 0));     (* no zero-cycle delay *)
  assert (Or_error.is_error (Delay_cycles.of_int 8193));  (* one past the max *)
  assert (Or_error.is_ok (Delay_cycles.of_int 1));
  assert (Or_error.is_ok (Delay_cycles.of_int 8192))
;;

(* --- SYS --- *)

let%test_unit "SYS: round trip" =
  check_round_trip
    ~encode:Sys.encode
    ~decode:Sys.decode 
    ~equal:Sys.equal
    ~sexp_of:Sys.sexp_of_t
    Sys.all
;;

let%test_unit "SYS: reference encodings" =
  check_encodes ~encode:Sys.encode Halt ~expect:0x0000;
  check_encodes ~encode:Sys.encode Nop ~expect:0x0400;
;;

let%test_unit "SYS: illegal words" =
  check_illegal ~decode:Sys.decode 0x0800;
  check_illegal ~decode:Sys.decode 0x1C00;
;;

(* --- Top level --- *)

let%test_unit "Instruction: round trip" =
  check_round_trip
    ~encode:Instruction.encode
    ~decode:Instruction.decode
    ~equal:Instruction.equal
    ~sexp_of:Instruction.sexp_of_t
    Instruction.all 
;;

let%test_unit "Instruction: full-word encodings" =
  let check i expect = check_encodes ~encode:Instruction.encode i ~expect in
  (* SET *)
  check (Set (Reg { register = C; value = Byte.of_int_exn 8 })) 0x0808;

  (* WAIT *)
  check (Wait { pin = Pin.of_int_exn 3; bank = Ui; condition = High }) 0x2C05;

  (* IN *)
  check (In { pin = Pin.of_int_exn 2; bank = Uio; destination = Y; order = Lsb_first }) 0x4801;

  (* OUT *)
  check (Out { target = Uo { pin = Pin.of_int_exn 7}; source = X; order = Msb_first }) 0x7C06;

  (* JMP *)
  check (Jmp ( If_pin { level = Low; bank = Uio; pin = Pin.of_int_exn 7; target = Target.of_int_exn 63 })) 0x95FF;

  (* MOV *)
  check (Mov { Mov.destination = Uo_out; source = Uio_in }) 0xBC04;

  (* DELAY *)
  check (Delay { cycles = Delay_cycles.of_int_exn 1 }) 0xC000;

  (* SYS *)
  check (Sys Halt) 0xE000;
  check (Sys Nop) 0xE400
;;

let%test_unit "Instruction: illegal words" =
  check_illegal ~decode:Instruction.decode 0x8040;    (* JMP ALWAYS with a pin bit set *)
  check_illegal ~decode:Instruction.decode 0x2008;    (* WAIT with reserved bit 3 set  *)
  check_illegal ~decode:Instruction.decode 0x4008;    (* IN with reserved bit 3 set    *)
  check_illegal ~decode:Instruction.decode 0x6010;    (* OUT with reserved bit 4 set   *)
  check_illegal ~decode:Instruction.decode 0xA008;    (* MOV with reserved bit 3 set   *)
  check_illegal ~decode:Instruction.decode 0xE001     (* HALT with a reserved bit set  *)
;;

let%test_unit "Instruction: all 65,536 words" =
  let legal = ref 0 in
  for word = 0 to 0xFFFF do 
    match Instruction.decode word with 
    | Error _ -> ()
    | Ok i ->
      incr legal;
      [%test_result: Int.Hex.t] (Instruction.encode i) ~expect:word
  done;
  [%test_result: int] (List.length Instruction.all) ~expect:!legal;
  [%test_result: int] !legal ~expect:14_674
;;

let%test_unit "Instruction: cycle costs" =
  [%test_result: int option] (Instruction.cycles (Sys Nop)) ~expect:(Some 1);
  [%test_result: int option] (Instruction.cycles (Sys Halt)) ~expect:None;
  [%test_result: int option]
    (Instruction.cycles (Delay { cycles = Delay_cycles.of_int_exn 102 })) ~expect:(Some 102);
  [%test_result: int option]
    (Instruction.cycles (Wait { pin = Pin.of_int_exn 0; bank = Uio; condition = Falling }))
    ~expect:None
;;