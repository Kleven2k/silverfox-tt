(* Short builders for instructions, shared by the test files. *)

open! Core
open Silverfox

let byte value =
  Isa.Byte.of_int_exn value
;;

(* --- SET --- *)

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

(* Runs only if a jump that should have skipped it didn't. *)
let marker =
  set_gpio Isa.Gpio_register.Pins_out Isa.Gpio_operation.Write 0xB2
;;

(* --- SYS --- *)

let halt =
  Isa.Instruction.Sys Isa.Sys.Halt
;;

let nop =
  Isa.Instruction.Sys Isa.Sys.Nop
;;

(* --- JMP --- *)

let jmp_always target =
  Isa.Instruction.Jmp
    (Isa.Jmp.Always { target = Isa.Target.of_int_exn target })
;;

let jmp_if_zero register target =
  Isa.Instruction.Jmp
    (Isa.Jmp.If_zero { register; target = Isa.Target.of_int_exn target })
;;

let jmp_c_nz_dec target =
  Isa.Instruction.Jmp (Isa.Jmp.C_nz_dec { target = Isa.Target.of_int_exn target })
;;

let jmp_if_pin level bank pin target =
  Isa.Instruction.Jmp
    (Isa.Jmp.If_pin
      { level; bank; pin = Isa.Pin.of_int_exn pin; target = Isa.Target.of_int_exn target })
;;

(* --- DELAY, WAIT, IN, OUT, MOV --- *)

let delay cycles =
  Isa.Instruction.Delay { cycles = Isa.Delay_cycles.of_int_exn cycles }
;;

let wait_for condition bank pin =
  Isa.Instruction.Wait { condition; bank; pin = Isa.Pin.of_int_exn pin }
;;

let in_bit pin bank destination order =
  Isa.Instruction.In { pin = Isa.Pin.of_int_exn pin; bank; destination; order }
;;

let out_bit target source order =
  Isa.Instruction.Out { target; source; order }
;;

let uo_pin pin = Isa.Out.Uo { pin = Isa.Pin.of_int_exn pin }
let uio_pin pin mode = Isa.Out.Uio { pin = Isa.Pin.of_int_exn pin; mode }

let mov destination source =
  Isa.Instruction.Mov { destination; source }
;;
