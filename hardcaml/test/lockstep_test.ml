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