open! Core 
open Silverfox.Isa 
open Silverfox.Model 

(* --- SET --- *)

let%test_unit "SET X, Y and C" =
  let before = State.reset in
  let set register value =
    execute_set (Set.Reg { register; value = Byte.of_int_exn value }) before 
  in
  [%test_result: State.t] (set X 0x11) ~expect:{ before with x = 0x11; pc = 1 };
  [%test_result: State.t] (set Y 0x22) ~expect:{ before with y = 0x22; pc = 1 };
  [%test_result: State.t] (set C 0x33) ~expect:{ before with c = 0x33; pc = 1 }
;;

let%test_unit "GPIO operations on PINS_OUT" =
  let before = { State.reset with pins_out = 0b0110 } in
  let run operation =
    execute_set
      (Set.Gpio { register = Pins_out; operation; mask = Byte.of_int_exn 0b0011 })
      before
  in
  [%test_result: State.t] (run Write) ~expect:{ before with pins_out = 0b0011; pc = 1 };
  [%test_result: State.t] (run Set_bits) ~expect:{ before with pins_out = 0b0111; pc = 1 };
  [%test_result: State.t] (run Clear_bits) ~expect:{ before with pins_out = 0b0100; pc = 1 };
  [%test_result: State.t] (run Toggle_bits) ~expect:{ before with pins_out = 0b0101; pc = 1 }
;;

let%test_unit "SET reaches PINS_OE and UO_OUT" =
  let before = State.reset in 
  let set_bits register =
    execute_set
      (Set.Gpio { register; operation = Set_bits; mask = Byte.of_int_exn 0b0001 })
      before
  in
  [%test_result: State.t] (set_bits Pins_oe) ~expect:{ before with pins_oe = 0b0001; pc = 1 };
  [%test_result: State.t] (set_bits Uo_out) ~expect:{ before with uo_out = 0b0001; pc = 1 }
;;

let%test_unit "PC wraps from 63 to 0" =
  let before = { State.reset with pc = 63 } in
  let after = execute_set (Set.Reg { register = X; value = Byte.of_int_exn 1 }) before in
  [%test_result: State.t] after ~expect:{ before with x = 1; pc = 0 }
;;