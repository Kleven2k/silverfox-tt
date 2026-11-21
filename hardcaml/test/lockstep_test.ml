open! Core 
open Silverfox 

let byte value = 
  Isa.Byte.of_int_exn value 
;;

let set_reg register value = 
  Isa.Instruction.Set
    (Isa.Set.Reg 
      { register
      ; value = byte value 
      })
;;

let set_gpio register operation mask =
  Isa.Instruction.Set
    (Isa.Set.Gpio 
      { register
      ; operation
      ; mask = byte mask
      })
;;

let halt =
  Isa.Instruction.Sys Isa.Sys.Halt
;;

let nop = 
  Isa.Instruction.Sys Isa.Sys.Nop
;;

let jmp_always target =
  Isa.Instruction.Jmp 
    (Isa.Jmp.Always { target = Isa.Target.of_int_exn target })
;;

let jmp_if_zero register target =
  Isa.Instruction.Jmp
    (Isa.Jmp.If_zero { register; target = Isa.Target.of_int_exn target })
;;

(* Runs only if a jump that should have skipped it didn't. *)
let marker =
  set_gpio Isa.Gpio_register.Pins_out Isa.Gpio_operation.Write 0xB2
;;

let jmp_c_nz_dec target =
  Isa.Instruction.Jmp (Isa.Jmp.C_nz_dec { target = Isa.Target.of_int_exn target })
;;

let jmp_if_pin level bank pin target =
  Isa.Instruction.Jmp
    (Isa.Jmp.If_pin
      { level; bank; pin = Isa.Pin.of_int_exn pin; target = Isa.Target.of_int_exn target })
;;

let delay cycles =
  Isa.Instruction.Delay { cycles = Isa.Delay_cycles.of_int_exn cycles }
;;

let wait_for condition bank pin =
  Isa.Instruction.Wait { condition; bank; pin = Isa.Pin.of_int_exn pin }
;;

let in_bit pin bank destination order =
  Isa.Instruction.In { pin = Isa.Pin.of_int_exn pin; bank; destination; order }
;;

let one_pin_inputs ~bank ~pin level =
  let mask = 1 lsl pin in
  let tested_bank = if level = 1 then mask else 0xFF lxor mask in
  let other_bank = if level = 1 then 0x00 else 0xFF in
  match (bank : Isa.Input_bank.t) with
  | Ui -> { Model.Inputs.ui_in = tested_bank; uio_in = other_bank }
  | Uio -> { Model.Inputs.ui_in = other_bank; uio_in = tested_bank }
;;

(* --- SET registers --- *)

let%test_unit "lockstep: SET X/Y/C then HALT" =
  let program =
    Model.Program.of_instructions_exn
      [ set_reg Isa.Register.X 0x12
      ; set_reg Isa.Register.Y 0x34
      ; set_reg Isa.Register.C 0x56
      ; halt
      ]
  in

  Lockstep.run_exn ~cycles:5 program
;;

(* --- SET GPIO operations --- *)

(* Each step starts from the previous result. From step 2 on, the mask
   overlaps the current value in some bits and misses it in others, so all
   four operations give different results. Step 1 just loads a value: from 0,
   Write, Set and Toggle look the same, so Write is tested again in step 5. *)
let gpio_sequence register =
  [ (* 0x00 -> 0xB2 *)
    set_gpio register Isa.Gpio_operation.Write 0xB2

    (* 0xB2 | 0x66 = 0xF6 *)
  ; set_gpio register Isa.Gpio_operation.Set_bits 0x66

    (* 0xF6 & ~0x5A = 0xA4 *)
  ; set_gpio register Isa.Gpio_operation.Clear_bits 0x5A

    (* 0xA4 ^ 0x3C = 0x98 *)
  ; set_gpio register Isa.Gpio_operation.Toggle_bits 0x3C

    (* 0x98 -> 0x4D*)
  ; set_gpio register Isa.Gpio_operation.Write 0x4D
  ]
;;

let%test_unit "lockstep: GPIO operations" =
  let instructions =
    gpio_sequence Isa.Gpio_register.Pins_out
    @ gpio_sequence Isa.Gpio_register.Pins_oe
    @ gpio_sequence Isa.Gpio_register.Uo_out
    @ [ halt ]
  in

  let program = Model.Program.of_instructions_exn instructions in

  Lockstep.run_exn 
    ~cycles:(List.length instructions + 1) 
    program 
;;

(* --- SYS NOP --- *)

let%test_unit "lockstep: NOP then HALT" =
  let program =
    Model.Program.of_instructions_exn
      [ nop
      ; halt
      ]
  in

  Lockstep.run_exn ~cycles:3 program
;;

(* --- Illegal instruction --- *)

let%test_unit "lockstep: illegal SET destination" =
  let illegal_set =
    (Isa.Opcode.to_bits Isa.Opcode.Set
     lsl Isa.Field.opcode.lsb)
    lor
    (0b110
     lsl Isa.Field.arg1.lsb)
  in

  let program =
    Model.Program.of_words_exn
      [ illegal_set ]
  in

  Lockstep.run_exn
    ~cycles:3
    program
;;

(* --- PC wrap --- *)

let%test_unit "lockstep: PC wraps from 63 to 0" =
  let instructions =
    List.init
      Isa.Arch.program_words
      ~f:(fun _ -> nop)
  in

  let program =
    Model.Program.of_instructions_exn
      instructions
  in

  Lockstep.run_exn
    ~cycles:70
    program
;;

(* --- Non-zero-inputs --- *)

let%test_unit "lockstep: previous inputs track ui_in/uio_in, also while halted" =
  let program = Model.Program.of_instructions_exn [ nop; nop; nop; halt ] in 
  let inputs cycle =
    { Model.Inputs.ui_in = (cycle * 37) land 0xff 
    ; uio_in = (cycle * 91) land 0xff
    }
  in
  Lockstep.run_exn ~inputs ~cycles:10 program 
;;

(* --- JMP --- *)

let%test_unit "lockstep: JMP Always skips forward" =
  (* The target must not be PC + 1: a jump to the next address looks the
     same as no jump. If the jump fails, SET X runs and X becomes 0xB2. *)
  let program =
    Model.Program.of_instructions_exn
      [ jmp_always 2
      ; set_reg Isa.Register.X 0xB2
      ; halt
      ]
  in
  Lockstep.run_exn ~cycles:4 program
;;

let%test_unit "lockstep: JMP Always jumps backward (endless loop)" =
  (* 0: NOP, 1: JMP 0 -> loops forever and never reaches HALT. *)
  let program =
    Model.Program.of_instructions_exn
      [ nop
      ; jmp_always 0
      ; halt
      ]
  in
  Lockstep.run_exn ~cycles:10 program 
;;

(* Taken: only the tested register is zero, the other two are made non-zero.
   An RTL that checks the wrong register sees non-zero and falls through. *)
let%test_unit "lockstep: JMP If_zero taken" =
  List.iter Isa.Register.all ~f:(fun register ->
    let others =
      List.filter Isa.Register.all ~f:(fun r -> not (Isa.Register.equal r register))
    in
    let program =
      Model.Program.of_instructions_exn
        (List.map others ~f:(fun r -> set_reg r 0x80)
        @ [ jmp_if_zero register 4  (* 2 *)
          ; marker                  (* 3: skipped *)
          ; halt                    (* 4 *)
          ])
    in
    Lockstep.run_exn ~cycles:6 program)
;;

(* Not taken: only the tested register is non-zero. *)
let%test_unit "lockstep: JMP If_zero not taken" =
  List.iter Isa.Register.all ~f:(fun register ->
    let program =
      Model.Program.of_instructions_exn
        [ set_reg register 0x80     (* 0 *)
        ; jmp_if_zero register 3    (* 1 *)
        ; marker                    (* 2: runs *)
        ; halt                      (* 3 *)  
        ]
    in
    Lockstep.run_exn ~cycles:5 program)
;;

(* C = 0: falls through, C stays 0 (an underflow would give 0xFF).
   C = 1: falls through, C becomes 0.
   C = 2: jumps, C becomes 1. *)
let%test_unit "lockstep: JMP C_nz_dec at C = 0, 1, 2" = 
  List.iter [ 0; 1; 2 ] ~f:(fun initial_c ->
    let program =
      Model.Program.of_instructions_exn
        [ set_reg Isa.Register.C initial_c  (* 0 *)
        ; jmp_c_nz_dec 3                    (* 1 *)
        ; marker                            (* 2: runs only if not taken *)
        ; halt                              (* 3 *)
        ]
    in
    Lockstep.run_exn ~cycles:5 program)
;;

(* The body (the NOP at 1) must run exactly 3 times. *)
let%test_unit "lockstep: JMP C_nz_dec counted loop" =
  let program = 
    Model.Program.of_instructions_exn
      [ set_reg Isa.Register.C 3  (* 0 *)
      ; nop                       (* 1: loop body *)
      ; jmp_c_nz_dec 1            (* 2 *)
      ; halt                      (* 3 *)
      ]
  in
  Lockstep.run_exn ~cycles:12 program 
;;

(* ui_in = 0xB2 and uio_in = 0x4D (= ~0xB2): every pin differs between the
   two banks, so a bank swap shows. 0xB2 also differs from its bit-reversal
   on every pin, so a bits_msb/bits_lsb mix-up shows. Each pin is either 0
   or 1, so for every pin one level is taken and the other is not. *)
let%test_unit "lockstep: JMP If_pin, every pin, bank and level" =
  let inputs _cycle = { Model.Inputs.ui_in = 0xB2; uio_in = 0x4D } in
  List.iter Isa.Level.all ~f:(fun level ->
    List.iter Isa.Input_bank.all ~f:(fun bank ->
      List.iter (List.range 0 8) ~f:(fun pin ->
        let program =
          Model.Program.of_instructions_exn
            [ jmp_if_pin level bank pin 2   (* 0 *)
            ; marker                        (* 1: runs only if not taken *)
            ; halt                          (* 2 *)
            ]
        in
        Lockstep.run_exn ~inputs ~cycles:4 program)))
;;

(* ui_in is 0x00 in cycle 0 and 0xFF in cycle 1, when the JMP runs.
   Reading the current input sees 1 and jumps; reading prev_ui would see 0. *)
let%test_unit "lockstep: JMP If_pin reads the current input" =
  let inputs cycle =
    { Model.Inputs.ui_in = (if cycle = 1 then 0xFF else 0x00); uio_in = 0x00 }
  in
  let program =
    Model.Program.of_instructions_exn
      [ nop                                               (* 0 *)
      ; jmp_if_pin Isa.Level.High Isa.Input_bank.Ui 0 3   (* 1 *)
      ; marker                                            (* 2 *)
      ; halt                                              (* 3 *)
      ]
  in
  Lockstep.run_exn ~inputs ~cycles:5 program 
;;

(* --- DELAY --- *)

(* 1 is the special case (no countdown); 2 is the shortest countdown;
   8192 is the maximum and uses every bit of the 13-bit counter.
   The marker after the DELAY shows the exact cycle it ends on. *)
let%test_unit "lockstep: DELAY n takes exactly n cycles" =
  List.iter [ 1; 2; 3; 7; 8192 ] ~f:(fun n ->
    let program = Model.Program.of_instructions_exn [ delay n; marker; halt ] in
    Lockstep.run_exn ~cycles:(n + 4) program)
;;

(* Back-to-back DELAYs: the second must start only after the first ends.
   Inputs change every cycle, so prev_ui/prev_uio during the countdown are
   checked too. *)
let%test_unit "lockstep: back-to-back DELAYs, inputs changing" =
  let inputs cycle =
    { Model.Inputs.ui_in = (cycle * 37) land 0xff
    ; uio_in = (cycle * 91) land 0xff
    }
  in
  let program =
    Model.Program.of_instructions_exn [ delay 3; delay 2; delay 1; halt ]
  in
  Lockstep.run_exn ~inputs ~cycles:10 program
;;

(* A DELAY inside a counted loop, the shape of a UART bit loop. *)
let%test_unit "lockstep: DELAY inside a C_nz_dec loop" =
  let program =
    Model.Program.of_instructions_exn
      [ set_reg Isa.Register.C 3  (* 0 *)
      ; delay 4                   (* 1: loop body *)
      ; jmp_c_nz_dec 1            (* 2 *)
      ; halt                      (* 3 *)
      ]
  in
  Lockstep.run_exn ~cycles:25 program
;;

(* --- WAIT --- *)

let%test_unit "lockstep: WAIT, every condition, bank, pin and level pair" =
  List.iter Isa.Wait.Condition.all ~f:(fun condition ->
    List.iter Isa.Input_bank.all ~f:(fun bank ->
      List.iter (List.range 0 8) ~f:(fun pin ->
        List.iter [ (0, 0); (0, 1); (1, 0); (1, 1) ] ~f:(fun (before, after) ->
          let inputs cycle = 
            one_pin_inputs ~bank ~pin (if cycle < 3 then before else after) in
          let program = 
            Model.Program.of_instructions_exn
              [ nop
              ; wait_for condition bank pin
              ; marker 
              ; halt
              ]
          in
          Lockstep.run_exn ~inputs ~cycles:8 program))))
;;

let%test_unit "lockstep: WAIT Rising sees high input immediately after reset" =
  let inputs _cycle =
    one_pin_inputs ~bank:Isa.Input_bank.Ui ~pin:0 1
  in
  let program = 
    Model.Program.of_instructions_exn
      [ wait_for
          Isa.Wait.Condition.Rising 
          Isa.Input_bank.Ui
          0
      ; marker 
      ; halt
      ]
  in
  Lockstep.run_exn ~inputs ~cycles:4 program 
;;

let%test_unit "lockstep: WAIT does not remember edge during DELAY" =
  let inputs cycle =
    let level = if cycle >= 2 then 1 else 0 in
    one_pin_inputs ~bank:Isa.Input_bank.Ui ~pin:3 level
  in
  let program =
    Model.Program.of_instructions_exn
      [ delay 5
      ; wait_for 
          Isa.Wait.Condition.Rising
          Isa.Input_bank.Ui
          3
      ; marker
      ; halt
      ]
  in
  Lockstep.run_exn ~inputs ~cycles:12 program
;;

(* --- IN --- *)

let%test_unit "lockstep: IN, every destination, order, bank, pin and level" =
  (* Isa.In.all lists every pin, bank, destination and order. *)
  List.iter Isa.In.all ~f:(fun (in_ : Isa.In.t) ->
    List.iter [ 0; 1 ] ~f:(fun level ->
      let inputs _cycle =
        one_pin_inputs ~bank:in_.bank ~pin:(Isa.Pin.to_int in_.pin) level
      in
      let program =
        Model.Program.of_instructions_exn
          [ set_reg Isa.Register.X 0x96
          ; set_reg Isa.Register.Y 0x69
          ; Isa.Instruction.In in_
          ; halt
          ]
      in
      Lockstep.run_exn ~inputs ~cycles:5 program))
;;

let%test_unit "lockstep: eight INs build a byte, both orders" =
  (* Cycles 0-7:
     MSB-first into X, so the first sampled bit is bit 7 of 0xB2.
     
     Cycles 8-15:
     LSB-first into Y, so the first sampled bit is bit 0 of 0xB2. *)
  let bit cycle =
    if cycle < 8
    then (0xB2 lsr (7 - cycle)) land 1
    else (0xB2 lsr (cycle - 8)) land 1
  in
  let inputs cycle =
    { Model.Inputs.ui_in = bit cycle; uio_in = 0x00 }
  in
  let in_x_msb = in_bit 0 Isa.Input_bank.Ui Isa.Shift_register.X Isa.Shift_order.Msb_first in
  let in_y_lsb = in_bit 0 Isa.Input_bank.Ui Isa.Shift_register.Y Isa.Shift_order.Lsb_first in
  let program =
    Model.Program.of_instructions_exn
      (List.init 8 ~f:(fun _ -> in_x_msb)
       @ List.init 8 ~f:(fun _ -> in_y_lsb)
       @ [ halt ])
  in
  Lockstep.run_exn ~inputs ~cycles:18 program 
;;