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

  let after = execute_out instruction before in
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

  let after = execute_out instruction before in 
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

  let after = execute_out instruction before in 
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

  let after = execute_out instruction before in
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

  let after = execute_out instruction before in
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

  let after = execute_out instruction before in
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

  let after = execute_out instruction before in
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
  
  let after = execute_out instruction before in
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

  let after = execute_out instruction before in
  [%test_result: int] after.pins_oe ~expect:0b1111_1101
;;

let%test_unit "OUT wraps PC at end of program memory" = 
  let instruction =
    { Out.target = Uo { pin = Pin.of_int_exn 0 }; source = Shift_register.X; order = Shift_order.Lsb_first }
  in

  let before = 
    { State.reset with pc = 63 }
  in

  let after = execute_out instruction before in
  [%test_result: int] after.pc ~expect:0
;;

(* --- JMP --- *)

let%test_unit "JMP ALWAYS jumps to target" =
  let instruction =
    Jmp.Always { target = Target.of_int_exn 42 }
  in

  let before =
    { State.reset with pc = 7 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.pc ~expect:42
;;

let%test_unit "JMP X_ZERO jumps when X is zero" =
  let instruction =
    Jmp.If_zero { register = Register.X; target = Target.of_int_exn 20 }
  in

  let before =
    { State.reset with pc = 3; x = 0 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.pc ~expect:20
;;

let%test_unit "JMP X_ZERO falls through when x is nonzero" =
  let instruction =
    Jmp.If_zero { register = Register.X; target = Target.of_int_exn 20 }
  in

  let before =
    { State.reset with pc = 3; x = 1 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.pc ~expect:4;
  [%test_result: int] after.x ~expect:1
;;

let%test_unit "JMP Y_ZERO" =
  let instruction =
    Jmp.If_zero { register = Register.Y; target = Target.of_int_exn 10 }
  in

  let before =
    { State.reset with y = 0 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.pc ~expect:10
;;

let%test_unit "JMP C_ZERO" =
  let instruction =
    Jmp.If_zero { register = Register.C; target = Target.of_int_exn 10 }
  in

  let before =
    { State.reset with c = 0 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.pc ~expect:10
;;

let%test_unit "JMP C_NZ_DEC with C=0 falls through without underflow" =
  let instruction =
    Jmp.C_nz_dec { target = Target.of_int_exn 5 }
  in

  let before =
    { State.reset with pc = 2; c = 0 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.c ~expect:0;
  [%test_result: int] after.pc ~expect:3
;;

let%test_unit "JMP C_NZ_DEC with C=1 decrements and falls through" =
  let instruction =
    Jmp.C_nz_dec { target = Target.of_int_exn 5 }
  in

  let before =
    { State.reset with pc = 2; c = 1 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.c ~expect:0;
  [%test_result: int] after.pc ~expect:3
;;

let%test_unit "JMP C_NZ_DEC with C=2 decrements and jumps" =
  let instruction =
    Jmp.C_nz_dec { target = Target.of_int_exn 5 }
  in

  let before =
    { State.reset with pc = 2; c = 2 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.c ~expect:1;
  [%test_result: int] after.pc ~expect:5
;;

let%test_unit "JMP C_NZ_DEC with C=255" =
  let instruction =
    Jmp.C_nz_dec { target = Target.of_int_exn 7 }
  in

  let before =
    { State.reset with pc = 1; c = 255 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.c ~expect:254;
  [%test_result: int] after.pc ~expect:7
;;

let%test_unit "JMP PIN_HIGH jumps when selected pin is high" =
  let instruction =
    Jmp.If_pin 
      { level = Level.High 
      ; bank = Input_bank.Ui
      ; pin = Pin.of_int_exn 3
      ; target = Target.of_int_exn 5 
      }
  in

  let inputs =
    { Inputs.ui_in = 0b0000_1000
    ; uio_in = 0
    }
  in

  let after = execute_jmp instruction inputs State.reset in
  [%test_result: int] after.pc ~expect:5
;;

let%test_unit "JMP PIN_HIGH falls through when selected pin is low" =
  let instruction =
    Jmp.If_pin 
      { level = Level.High 
      ; bank = Input_bank.Ui
      ; pin = Pin.of_int_exn 3
      ; target = Target.of_int_exn 12 
      }
  in

  let inputs =
    { Inputs.ui_in = 0
    ; uio_in = 0
    }
  in

  let before =
    { State.reset with pc = 4 }
  in

  let after = execute_jmp instruction inputs before in
  [%test_result: int] after.pc ~expect:5
;;

let%test_unit "JMP PIN_LOW jumps when selected pin is low" =
  let instruction =
    Jmp.If_pin 
      { level = Level.Low
      ; bank = Input_bank.Uio
      ; pin = Pin.of_int_exn 2
      ; target = Target.of_int_exn 30
      }
  in

  let inputs =
    { Inputs.ui_in = 0
    ; uio_in = 0b1111_1011
    }
  in

  let after = execute_jmp instruction inputs State.reset in
  [%test_result: int] after.pc ~expect:30
;;

let%test_unit "JMP PIN_HIGH uses selected input bank" =
  let instruction =
    Jmp.If_pin 
      { level = Level.High
      ; bank = Input_bank.Uio
      ; pin = Pin.of_int_exn 0
      ; target = Target.of_int_exn 10
      }
  in

  let inputs =
    { Inputs.ui_in = 1
    ; uio_in = 0
    }
  in

  let after = execute_jmp instruction inputs State.reset in
  (* UI pin0 is high, but JMP is checking UIO pin0. *)
  [%test_result: int] after.pc ~expect:1
;;

let%test_unit "JMP not-taken branch wraps PC" =
  let instruction =
    Jmp.If_zero
      { register = Register.X
      ; target = Target.of_int_exn 10
      }
  in

  let before =
    { State.reset with pc = 63; x = 1 }
  in

  let after = execute_jmp instruction Inputs.zero before in
  [%test_result: int] after.pc ~expect:0
;;

let%test_unit "C_NZ_DEC produces exactly 8 loop iterations" =
  let jump =
    Jmp.C_nz_dec 
      { target = Target.of_int_exn 4 }
  in

  let rec loop state jumps_taken =
    let after =
      execute_jmp jump Inputs.zero state 
    in

    if after.pc = 4
    then
      loop after (jumps_taken + 1)
    else
      after, jumps_taken
  in
  
  let before =
    { State.reset with pc = 5; c = 8 }
  in

  let after, jumps_taken = loop before 0 in
  [%test_result: int] after.c ~expect:0;
  (*
   * For an 8-iteration loop:
   *
   * body #1 -> jump
   * ...
   * body #7 -> jump
   * body #8 -> fall through
   *
   * So JMP is taken seven times.
   *)
  [%test_result: int] jumps_taken ~expect:7
;;

(* --- SYS --- *)

let%test_unit "SYS NOP advances PC" =
  let before = State.reset in
  let after = execute_sys Sys.Nop before in
  [%test_result: State.t] after ~expect:{ before with pc = 1 }
;;

let%test_unit "SYS HALT stops execution and holds PC" =
  let before =
    { State.reset with pc = 7 }
  in

  let after = execute_sys Sys.Halt before in 
  [%test_result: int] after.pc ~expect:7;
  [%test_result: Halt_reason.t option] after.halt_reason ~expect:(Some Halt_reason.Halt_instruction)
;;

let%test_unit "SYS HALT does not modify architectural state" = 
  let before =
    { State.reset with pc = 5
    ; x = 0x12
    ; y = 0x34
    ; c = 8
    ; pins_out = 0xaa
    ; pins_oe = 0x55
    ; uo_out = 0xf0
    }
  in

  let after = execute_sys Sys.Halt before in
  [%test_result: State.t] after
    ~expect:{ before with halt_reason = Some Halt_reason.Halt_instruction }
;; 