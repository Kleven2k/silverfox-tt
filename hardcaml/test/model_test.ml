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

(* --- WAIT --- *)

(* Success tests expect only the PC to advance; stall tests expect the state
   to be completely unchanged. *)

let%test_unit "WAIT LOW succeeds when pin is low" =
  let wait =
    { Wait.pin = Pin.of_int_exn 3
    ; bank = Input_bank.Ui
    ; condition = Wait.Condition.Low
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000
    ; uio_in = 0
    }
  in
  let before = State.reset in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:{ before with pc = 1 }
;;

let%test_unit "WAIT LOW stalls while pin is high" =
  let wait =
    { Wait.pin = Pin.of_int_exn 3
    ; bank = Input_bank.Ui
    ; condition = Wait.Condition.Low
    }
  in
  let inputs =
    { Inputs.ui_in = 0b1000
    ; uio_in = 0
    }
  in
  let before = State.reset in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:before
;;

let%test_unit "WAIT HIGH succeeds when pin is high" =
  let wait =
    { Wait.pin = Pin.of_int_exn 2
    ; bank = Input_bank.Uio
    ; condition = Wait.Condition.High
    }
  in
  let inputs =
    { Inputs.ui_in = 0
    ; uio_in = 0b0100
    }
  in
  let before = State.reset in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:{ before with pc = 1 }
;;

let%test_unit "WAIT RISING detects 0 -> 1" =
  let wait =
    { Wait.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; condition = Wait.Condition.Rising
    }
  in
  let before =
    { State.reset with
      prev_ui = 0b0000
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0001
    ; uio_in = 0
    }
  in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:{ before with pc = 1 }
;;

let%test_unit "WAIT RISING does not trigger on steady high" =
  let wait =
    { Wait.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; condition = Wait.Condition.Rising
    }
  in
  let before =
    { State.reset with
      prev_ui = 0b0001
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0001
    ; uio_in = 0
    }
  in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:before
;;

let%test_unit "WAIT RISING does not trigger on 1 -> 0" =
  let wait =
    { Wait.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; condition = Wait.Condition.Rising
    }
  in
  let before =
    { State.reset with
      prev_ui = 0b0001
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000
    ; uio_in = 0
    }
  in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:before
;;

let%test_unit "WAIT FALLING detects 1 -> 0" =
  let wait =
    { Wait.pin = Pin.of_int_exn 5
    ; bank = Input_bank.Uio
    ; condition = Wait.Condition.Falling
    }
  in
  let before =
    { State.reset with
      prev_uio = 0b0010_0000
    }
  in
  let inputs =
    { Inputs.ui_in = 0
    ; uio_in = 0b0000_0000
    }
  in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:{ before with pc = 1 }
;;

let%test_unit "WAIT FALLING does not trigger on steady low" =
  let wait =
    { Wait.pin = Pin.of_int_exn 5
    ; bank = Input_bank.Uio
    ; condition = Wait.Condition.Falling
    }
  in
  let before =
    { State.reset with
      prev_uio = 0b0000_0000
    }
  in
  let inputs =
    { Inputs.ui_in = 0
    ; uio_in = 0b0000_0000
    }
  in
  (* The pin is low, so a FALLING that behaved like LOW would wrongly succeed. *)
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:before
;;

let%test_unit "WAIT only observes selected pin" =
  let wait =
    { Wait.pin = Pin.of_int_exn 3
    ; bank = Input_bank.Ui
    ; condition = Wait.Condition.High
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000_0100
    ; uio_in = 0
    }
  in
  (* pin2 is high, but we're waiting on pin3 *)
  let before = State.reset in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:before
;;

let%test_unit "WAIT distinguishes UI and UIO banks" =
  let wait =
    { Wait.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Uio
    ; condition = Wait.Condition.High
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000_0001
    ; uio_in = 0b0000_0000
    }
  in
  (* UI pin0 is high, but WAIT is looking at UIO pin0. *)
  let before = State.reset in
  let after = execute_wait wait inputs before in
  [%test_result: State.t] after ~expect:before
;;

let%test_unit "WAIT wraps PC after address 63" =
  let wait =
    { Wait.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; condition = Wait.Condition.Low
    }
  in
  let before =
    { State.reset with
      pc = 63
    }
  in
  let after = execute_wait wait Inputs.zero before in
  [%test_result: State.t] after ~expect:{ before with pc = 0 }
;;
