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

(* --- IN --- *)

let%test_unit "IN LSB-first shifts 1 into X bit 7" =
  let instruction =
    { In.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; destination = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000_0001
    ; uio_in = 0
    }
  in
  let before = State.reset in
  let after = execute_in instruction inputs before in
  [%test_result: State.t] after ~expect:{ before with x = 0b1000_0000; pc = 1 }
;;

let%test_unit "IN LSB-first shifts existing X right" =
  let instruction =
    { In.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; destination = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in
  let before =
    { State.reset with
      x = 0b0101_0101
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000_0001
    ; uio_in = 0
    }
  in
  let after = execute_in instruction inputs before in
  (*
   * old X:
   *  0101_0101
   * shift right:
   *  0010_1010
   * sampled 1 inserted into bit 7:
   *  1010_1010
   *)
  [%test_result: State.t] after ~expect:{ before with x = 0b1010_1010; pc = 1 }
;;

let%test_unit "IN LSB-first samples zero" =
  let instruction =
    { In.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; destination = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in
  let before =
    { State.reset with
      x = 0b1111_1111
    }
  in
  let after = execute_in instruction Inputs.zero before in
  [%test_result: State.t] after ~expect:{ before with x = 0b0111_1111; pc = 1 }
;;

let%test_unit "IN MSB-first shifts bit into bit 0" =
  let instruction =
    { In.pin = Pin.of_int_exn 2
    ; bank = Input_bank.Ui
    ; destination = Shift_register.X
    ; order = Shift_order.Msb_first
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000_0100
    ; uio_in = 0
    }
  in
  let before = State.reset in
  let after = execute_in instruction inputs before in
  [%test_result: State.t] after ~expect:{ before with x = 0b0000_0001; pc = 1 }
;;

let%test_unit "IN MSB-first drops the old bit 7" =
  let instruction =
    { In.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; destination = Shift_register.X
    ; order = Shift_order.Msb_first
    }
  in
  let before =
    { State.reset with
      x = 0b1000_0001
    }
  in
  (* Shifting left pushes bit 7 out. Without the 8-bit mask, X would become
     0b1_0000_0010 (258) instead of 0b0000_0010. *)
  let after = execute_in instruction Inputs.zero before in
  [%test_result: State.t] after ~expect:{ before with x = 0b0000_0010; pc = 1 }
;;

let%test_unit "IN can shift into Y" =
  let instruction =
    { In.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; destination = Shift_register.Y
    ; order = Shift_order.Lsb_first
    }
  in
  let inputs =
    { Inputs.ui_in = 1
    ; uio_in = 0
    }
  in
  let before = State.reset in
  let after = execute_in instruction inputs before in
  [%test_result: State.t] after ~expect:{ before with y = 0x80; pc = 1 }
;;

let%test_unit "IN reads selected input bank" =
  let instruction =
    { In.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Uio
    ; destination = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000_0001
    ; uio_in = 0b0000_0000
    }
  in
  let before = State.reset in
  let after = execute_in instruction inputs before in
  (* UI pin0 is high, but we're sampling UIO pin0 *)
  [%test_result: State.t] after ~expect:{ before with pc = 1 }
;;

let%test_unit "IN reads selected pin only" =
  let instruction =
    { In.pin = Pin.of_int_exn 3
    ; bank = Input_bank.Ui
    ; destination = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in
  let inputs =
    { Inputs.ui_in = 0b0000_0100
    ; uio_in = 0
    }
  in
  let before = State.reset in
  (* pin2 is high, but we're sampling pin3. *)
  let after = execute_in instruction inputs before in
  [%test_result: State.t] after ~expect:{ before with pc = 1 }
;;

let%test_unit "IN reconstructs an LSB-first byte" =
  let instruction =
    { In.pin = Pin.of_int_exn 0
    ; bank = Input_bank.Ui
    ; destination = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in
  (* 0xB2 = 1011_0010, sent LSB-first (bit 0 first). The byte is not a
     palindrome in binary, so a swapped bit order would give 0x4D instead.
     (0xA5 = 1010_0101 reads the same both ways and could not catch that.) *)
  let bits =
    [ 0; 1; 0; 0; 1; 1; 0; 1 ]
  in
  let final_state =
    List.fold bits ~init:State.reset ~f:(fun state received_bit ->
      let inputs =
        { Inputs.ui_in = received_bit
        ; uio_in = 0
        }
      in
      (* Reset PC here only because we're directly unit-testing execute_in.
         In a real program there would be eight IN instructions / a loop. *)
      let state =
        { state with pc = 0 }
      in
      execute_in instruction inputs state)
  in
  [%test_result: int] final_state.x ~expect:0xB2
;;

(* --- OUT --- *)

let%test_unit "OUT UO LSB-first outputs X[0]" =
  let instruction =
    { Out.target = Uo { pin = Pin.of_int_exn 0 }
    ; source = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in

  let before =
    { State.reset with 
      x = 0b1010_0101
    }
  in

  let after = execute_out before instruction in
  [%test_result: int] after.uo_out ~expect:0b0000_0001;
  [%test_result: int] after.x ~expect:0b0101_0010;
  [%test_result: int] after.pc ~expect:1
;;

let%test_unit "OUT only modifies selected UO pin" =
  let instruction =
    { Out.target = Uo { pin = Pin.of_int_exn 3 }
    ; source = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in

  let before = 
    { State.reset with x = 1
    ; uo_out = 0b1010_0000
    }
  in

  let after = execute_out before instruction in 
  [%test_result: int] after.uo_out ~expect:0b1010_1000
;;

let%test_unit "OUT can clear selected UO pin" =
  let instruction = 
    { Out.target = Uo { pin = Pin.of_int_exn 2 }
    ; source = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in

  let before =
    { State.reset with x = 0
    ; uo_out = 0b1111_1111 
    }
  in

  let after = execute_out before instruction in 
  [%test_result: int] after.uo_out ~expect:0b1111_1011
;;

let%test_unit "OUT MSB-first outputs bit 7 and shifts left" =
  let instruction = 
    { Out.target = Uo { pin = Pin.of_int_exn 0 }
    ; source = Shift_register.X
    ; order = Shift_order.Msb_first
    }
  in

  let before =
    { State.reset with x = 0b1010_0101 }
  in

  let after = execute_out before instruction in
  [%test_result: int] after.uo_out ~expect:1;
  [%test_result: int] after.x ~expect:0b0100_1010
;;

let%test_unit "OUT can use Y without modifying X" =
  let instruction =
    { Out.target = Uo { pin = Pin.of_int_exn 0 }
    ; source = Shift_register.Y
    ; order = Shift_order.Lsb_first
    }
  in

  let before =
    { State.reset with x = 0x55
    ; y = 0x03
    }
  in

  let after = execute_out before instruction in
  [%test_result: int] after.x ~expect:0x55;
  [%test_result: int] after.y ~expect:0x01;
  [%test_result: int] after.uo_out ~expect:1
;;

let%test_unit "OUT UIO push-pull writes PINS_OUT" =
  let instruction =
    { Out.target = Uio { pin = Pin.of_int_exn 2; mode = Out.Mode.Push_pull }
    ; source = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in

  let before =
    { State.reset with x = 1 }
  in

  let after = execute_out before instruction in
  [%test_result: int] after.pins_out ~expect:0b0000_0100
;;

let%test_unit "OUT UIO push-pull does not change PINS_OE" =
  let instruction = 
    { Out.target = Uio { pin = Pin.of_int_exn 2; mode = Out.Mode.Push_pull }
    ; source = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in

  let before = 
    { State.reset with x = 1; pins_oe = 0b1010_1010 }
  in

  let after = execute_out before instruction in
  [%test_result: int] after.pins_oe ~expect:0b1010_1010
;;

let%test_unit "OUT open-drain zero actively drives low" =
  let instruction =
    { Out.target = Uio { pin = Pin.of_int_exn 1; mode = Out.Mode.Open_drain }
    ; source = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in

  let before = 
    {State.reset with x = 0
    ; pins_out = 0xff
    ; pins_oe = 0 
    }
  in
  
  let after = execute_out before instruction in
  [%test_result: int] after.pins_out ~expect:0b1111_1101;
  [%test_result: int] after.pins_oe ~expect:0b0000_0010
;;

let%test_unit "OUT open-drain one releases pin" =
  let instruction =
    { Out.target = Uio { pin = Pin.of_int_exn 1; mode = Out.Mode.Open_drain }
    ; source = Shift_register.X
    ; order = Shift_order.Lsb_first
    }
  in

  let before = 
    { State.reset with x = 1; pins_out = 0; pins_oe = 0xff }
  in

  let after = execute_out before instruction in
  [%test_result: int] after.pins_oe ~expect:0b1111_1101
;;

let%test_unit "OUT wraps PC at end of program memory" = 
  let instruction =
    { Out.target = Uo { pin = Pin.of_int_exn 0 }; source = Shift_register.X; order = Shift_order.Lsb_first }
  in

  let before = 
    { State.reset with pc = 63 }
  in

  let after = execute_out before instruction in
  [%test_result: int] after.pc ~expect:0
;;