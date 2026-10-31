open! Core
open Silverfox.Isa

let encode = Instruction.encode

let decode_ok word =
  match Instruction.decode word with
  | Ok i -> i
  | Error e -> raise_s [%message "expected a legal word" (word : Int.Hex.t) (e : Error.t)]
;;

let is_illegal word = Result.is_error (Instruction.decode word)

let%test_unit "every legal instruction survives encode -> decode" =
  List.iter Instruction.all ~f:(fun i ->
    [%test_result: Instruction.t] (decode_ok (encode i)) ~expect:i)
;;

(* Exhaustive over the whole 16-bit space. Together with the test above, and
   the counts matching, this shows encode/decode is a bijection between legal
   instructions and legal words. *)
let%test_unit "decoder classifies all 65,536 words" =
  let legal_words = ref 0 in
  for word = 0 to 0xFFFF do
    match Instruction.decode word with
    | Error _ -> ()
    | Ok i ->
      incr legal_words;
      [%test_result: Int.Hex.t] (encode i) ~expect:word
  done;
  [%test_result: int] (List.length Instruction.all) ~expect:!legal_words;
  (* 14,674 = SET 3,840 + WAIT 64 + IN 64 + OUT 96 + JMP 2,368 + MOV 48
     + DELAY 8,192 + SYS 2. A change here means the legal space changed. *)
  [%test_result: int] !legal_words ~expect:14_674
;;

(* Pins the actual bit patterns, so reordering or renaming anything that
   changes the encoding shows up here. Values are hand-computed from isa.md. *)
let%test_unit "reference encodings" =
  let check i expect = [%test_result: Int.Hex.t] (encode i) ~expect in
  let byte = Byte.of_int_exn in
  let target = Target.of_int_exn in
  let pin = Pin.of_int_exn in
  check (Sys Halt) 0xE000;
  check (Sys Nop) 0xE400;
  check (Delay { cycles = Delay_cycles.of_int_exn 1 }) 0xC000;
  check (Delay { cycles = Delay_cycles.of_int_exn 8192 }) 0xDFFF;
  check (Set (Reg { register = X; value = byte 0xA5 })) 0x00A5;
  check (Set (Reg { register = C; value = byte 8 })) 0x0808;
  check (Jmp (C_nz_dec { target = target 5 })) 0x9005;
  check (Jmp (If_pin { level = High; bank = Ui; pin = pin 3; target = target 10 })) 0x9ACA;
  check
    (Out { target = Uio { pin = pin 0; mode = Push_pull }; source = X; order = Lsb_first })
    0x6000;
  check (Mov { destination = X; source = Ui_in }) 0xA003
;;

let%test_unit "reserved and illegal encodings are rejected" =
  List.iter
    [ 0xE001 (* HALT with a reserved bit set *)
    ; 0xE800 (* SYS sub-op 010 is reserved *)
    ; 0x0100 (* SET X with a non-WRITE operation *)
    ; 0x1800 (* SET destination 110 is reserved *)
    ; 0x9C00 (* JMP condition 111 is reserved *)
    ; 0x8040 (* ALWAYS jump with the pin field set *)
    ; 0xAC00 (* MOV into UI_IN (read-only) *)
    ; 0x600C (* OUT open-drain on UO *)
    ; 0x10000 (* not a 16-bit word *)
    ]
    ~f:(fun word ->
      if not (is_illegal word)
      then raise_s [%message "expected illegal" (word : Int.Hex.t)])
;;

let%test_unit "cycle costs" =
  [%test_result: int option] (Instruction.cycles (Sys Nop)) ~expect:(Some 1);
  [%test_result: int option]
    (Instruction.cycles (Delay { cycles = Delay_cycles.of_int_exn 102 }))
    ~expect:(Some 102);
  [%test_result: int option]
    (Instruction.cycles (Wait { pin = Pin.of_int_exn 0; bank = Uio; condition = Falling }))
    ~expect:None
;;

let%test_unit "smart constructors reject out-of-range values" =
  assert (Or_error.is_error (Pin.of_int 8));
  assert (Or_error.is_error (Target.of_int 64));
  assert (Or_error.is_error (Byte.of_int 256));
  assert (Or_error.is_error (Delay_cycles.of_int 0));
  assert (Or_error.is_error (Delay_cycles.of_int 8193))
;;
