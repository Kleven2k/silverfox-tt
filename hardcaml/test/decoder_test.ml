open! Core 
open! Hardcaml
open Silverfox 

module Sim =
  Cyclesim.With_interface
    (Decoder.I)
    (Decoder.O)

let create_sim () =
  Sim.create 
    (Decoder.create
      (Scope.create ~flatten_design:true ()))
;;

let%test_unit "decoder: every field matches Isa.Field for all words" =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  for word = 0 to 0xffff do 
    inputs.instruction := Bits.of_unsigned_int ~width:16 word;
    Cyclesim.cycle sim;
    let check name (field : Isa.Field.t) (output : Bits.t ref) =
      let rtl = Bits.to_unsigned_int !output in 
      let sw = Isa.Field.get field word in 
      if rtl <> sw 
      then 
        raise_s 
          [%message
            "decoder field mismatch"
              (name : string)
              (word : Int.Hex.t)
              (rtl : int)
              (sw : int)]
    in 
    check "opcode" Isa.Field.opcode outputs.opcode;
    check "arg1" Isa.Field.arg1 outputs.arg1;
    check "set_operation" Isa.Field.set_operation outputs.set_operation;
    check "set_value" Isa.Field.set_value outputs.set_value;
    check "wait_condition" Isa.Field.wait_condition outputs.wait_condition;
    check "shift_register" Isa.Field.shift_register outputs.shift_register;
    check "shift_order" Isa.Field.shift_order outputs.shift_order;
    check "bank" Isa.Field.bank outputs.bank;
    check "output_mode" Isa.Field.output_mode outputs.output_mode;
    check "jmp_target" Isa.Field.jmp_target outputs.jmp_target;
    check "jmp_pin" Isa.Field.jmp_pin outputs.jmp_pin;
    check "jmp_bank" Isa.Field.jmp_bank outputs.jmp_bank;
    check "mov_source" Isa.Field.mov_source outputs.mov_source;
    check "delay" Isa.Field.delay outputs.delay;
  done
;;

let check_illegal_matches ~first ~last =
  let sim = create_sim () in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  for word = first to last do
    inputs.instruction := Bits.of_unsigned_int ~width:16 word;
    Cyclesim.cycle sim;
    let rtl_illegal = Bits.to_bool !(outputs.illegal) in
    let sw_illegal = Result.is_error (Isa.Instruction.decode word) in
    if Bool.(rtl_illegal <> sw_illegal)
    then
      raise_s
        [%message "illegal mismatch" (word : Int.Hex.t) (rtl_illegal : bool) (sw_illegal : bool)]
  done
;;

let%test_unit "decoder: illegal matches software for SET words" =
  check_illegal_matches ~first:0x0000 ~last:0x1FFF
;;

let%test_unit "decoder: illegal matches software for WAIT words" =
  check_illegal_matches ~first:0x2000 ~last:0x3FFF
;;

let%test_unit "decoder: illegal matches software for IN words" =
  check_illegal_matches ~first:0x4000 ~last:0x5FFF
;;

let%test_unit "decoder: illegal matches software for OUT words" =
  check_illegal_matches ~first:0x6000 ~last:0x7FFF
;;

let%test_unit "decoder: illegal matches software for JMP words" =
  check_illegal_matches ~first:0x8000 ~last:0x9FFF
;;

let%test_unit "decoder: illegal matches software for MOV words" =
  check_illegal_matches ~first:0xA000 ~last:0xBFFF
;;

let%test_unit "decoder: illegal matches software for DELAY words" =
  check_illegal_matches ~first:0xC000 ~last:0xdFFF
;;

let%test_unit "decoder: illegal matches software for SYS words" =
  check_illegal_matches ~first:0xE000 ~last:0xFFFF
;;