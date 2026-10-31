open! Core
open! Hardcaml

(*
 * Silverfox ISA v0.3
 *
 * This module defines the architectural encoding vocabulary:
 *
 *   - architectural constants
 *   - major opcodes
 *   - sub-opcode/operand enumerations
 *   - abstract OCaml instruction representation
 *   - legality/validation rules
 *   - DELAY encoding helpers
 *
 * This module does NOT contain the RTL decoder.
 *
 * Suggested separation:
 *
 *   isa.ml       - ISA types, enums, constants, validation
 *   encode.ml    - Instruction.t -> 16-bit machine word
 *   decode.ml    - 16-bit machine word -> Instruction.t / illegal
 *   decoder.ml   - independent Hardcaml RTL decoder
 *)

(* -------------------------------------------------------------------------- *)
(* Architectural constants                                                    *)
(* -------------------------------------------------------------------------- *)

module Arch = struct
  let instruction_width = 16

  let opcode_width = 3
  let arg1_width = 3
  let arg2_width = 10

  let data_width = 8

  let program_words = 64
  let pc_width = 6

  let pin_count = 8
  let pin_width = 3

  (*
   * DELAY uses the entire 13-bit operand field:
   *
   *   instr[12:0]
   *
   * The machine encoding stores:
   *
   *   payload = cycles - 1
   *
   * Therefore DELAY supports 1..8192 cycles.
   *)
  let delay_width = 13
  let delay_min_cycles = 1
  let delay_max_cycles = 1 lsl delay_width
end

module type Cases = sig
  type t [@@deriving sexp_of, compare ~localize, enumerate, equal]
end

module type Enum = sig
  module Cases : Cases
  include Hardcaml.Enum.S_enum with module Cases := Cases

  val width : int
  val to_int : Cases.t -> int
  val of_int : int -> Cases.t Or_error.t
end

module Make_enum (Cases : Cases) = struct
  include Hardcaml.Enum.Make_binary (Cases)

  let width = to_raw port_widths
  let to_int t = to_raw (Of_bits.of_enum t) |> Bits.to_unsigned_int

  let of_int i =
    match List.nth Cases.all i with
    | Some t -> Ok t
    | None -> Or_error.error_s [%message "wrong enum code" (i : int)]
  ;;
end

(* -------------------------------------------------------------------------- *)
(* Major opcode                                                               *)
(* -------------------------------------------------------------------------- *)

module Opcode = struct
  module Cases = struct
    type t =
      | Set
      | Wait
      | In
      | Out
      | Jmp
      | Mov
      | Delay
      | Sys
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

(*
 * Major opcode encoding:
 *
 *   000 SET
 *   001 WAIT
 *   010 IN
 *   011 OUT
 *   100 JMP
 *   101 MOV
 *   110 DELAY
 *   111 SYS
 *)

(* -------------------------------------------------------------------------- *)
(* SET                                                                        *)
(* -------------------------------------------------------------------------- *)

module Set_destination = struct
  module Cases = struct
    type t =
      | X
      | Y
      | C
      | Pins_out
      | Pins_oe
      | Uo_out
      | Reserved_6
      | Reserved_7
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

(*
 * SET arg1:
 *
 *   000 X
 *   001 Y
 *   010 C
 *   011 PINS_OUT
 *   100 PINS_OE
 *   101 UO_OUT
 *   110 reserved
 *   111 reserved
 *)

module Set_operation = struct
  module Cases = struct
    type t =
      | Write
      | Set_bits
      | Clear_bits
      | Toggle_bits
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

(*
 * SET encoding:
 *
 *   15       13 12       10 9   8 7              0
 *  +-----------+-----------+------+----------------+
 *  |    000    |   dest    |  op  | value / mask   |
 *  +-----------+-----------+------+----------------+
 *
 * arg1:
 *   destination
 *
 * arg2[9:8]:
 *
 *   00 WRITE
 *   01 SET_BITS
 *   10 CLEAR_BITS
 *   11 TOGGLE_BITS
 *
 * arg2[7:0]:
 *
 *   immediate / mask
 *
 * X, Y and C only support WRITE in v0.3.
 *
 * PINS_OUT, PINS_OE and UO_OUT support all four operations.
 *)

(* -------------------------------------------------------------------------- *)
(* WAIT                                                                       *)
(* -------------------------------------------------------------------------- *)

module Wait_source = struct
  module Cases = struct
    type t =
      | Uio
      | Ui
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Wait_condition = struct
  module Cases = struct
    type t =
      | Low
      | High
      | Rising
      | Falling
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

(*
 * WAIT encoding:
 *
 *   opcode = 001
 *
 *   arg1[2:0] = pin
 *
 *   arg2[1:0] = condition
 *
 *       00 LOW
 *       01 HIGH
 *       10 RISING
 *       11 FALLING
 *
 *   arg2[2] = input bank
 *
 *       0 UIO
 *       1 UI
 *
 *   arg2[9:3] = reserved, must be zero
 *
 *
 * WAIT semantics operate on the synchronized input signal.
 *
 * LOW/HIGH are level-sensitive.
 *
 * RISING/FALLING are true edge conditions:
 *
 *   RISING:
 *     previous = 0
 *     current  = 1
 *
 *   FALLING:
 *     previous = 1
 *     current  = 0
 *
 * The RTL input synchronizer and previous-sample register are implementation
 * details, but their externally visible behavior must agree with isa.md.
 *)

(* -------------------------------------------------------------------------- *)
(* Shared IN / OUT configuration                                              *)
(* -------------------------------------------------------------------------- *)

module Shift_register = struct
  module Cases = struct
    type t =
      | X
      | Y
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Shift_order = struct
  module Cases = struct
    type t =
      | Lsb_first
      | Msb_first
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Input_source = struct
  module Cases = struct
    type t =
      | Uio
      | Ui
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Output_bank = struct
  module Cases = struct
    type t =
      | Uio
      | Uo
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Output_mode = struct
  module Cases = struct
    type t =
      | Push_pull
      | Open_drain
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

(* -------------------------------------------------------------------------- *)
(* IN                                                                         *)
(* -------------------------------------------------------------------------- *)

(*
 * IN encoding:
 *
 *   opcode = 010
 *
 *   arg1[2:0] = pin
 *
 *   arg2[0] = destination register
 *
 *       0 X
 *       1 Y
 *
 *   arg2[1] = shift order
 *
 *       0 LSB-first
 *       1 MSB-first
 *
 *   arg2[2] = input bank
 *
 *       0 UIO
 *       1 UI
 *
 *   arg2[9:3] = reserved, must be zero
 *
 *
 * LSB-first:
 *
 *   X <- { input_bit, X[7:1] }
 *
 * or equivalently for Y.
 *
 *
 * MSB-first:
 *
 *   X <- { X[6:0], input_bit }
 *
 * or equivalently for Y.
 *)

(* -------------------------------------------------------------------------- *)
(* OUT                                                                        *)
(* -------------------------------------------------------------------------- *)

(*
 * OUT encoding:
 *
 *   opcode = 011
 *
 *   arg1[2:0] = pin
 *
 *   arg2[0] = source register
 *
 *       0 X
 *       1 Y
 *
 *   arg2[1] = shift order
 *
 *       0 LSB-first
 *       1 MSB-first
 *
 *   arg2[2] = output bank
 *
 *       0 UIO
 *       1 UO
 *
 *   arg2[3] = output mode
 *
 *       0 PUSH_PULL
 *       1 OPEN_DRAIN
 *
 *   arg2[9:4] = reserved, must be zero
 *
 *
 * Push-pull UIO OUT modifies only:
 *
 *   PINS_OUT[pin]
 *
 * It does NOT implicitly modify:
 *
 *   PINS_OE[pin]
 *
 * Direction must therefore be configured explicitly.
 *
 *
 * Open-drain UIO behavior:
 *
 * output bit = 0:
 *
 *   PINS_OUT[pin] <- 0
 *   PINS_OE[pin]  <- 1
 *
 * output bit = 1:
 *
 *   PINS_OE[pin] <- 0
 *
 * The core never actively drives logic 1 in open-drain mode.
 *
 *
 * OPEN_DRAIN + UO is illegal because UO has no output-enable control.
 *)

(* -------------------------------------------------------------------------- *)
(* JMP                                                                        *)
(* -------------------------------------------------------------------------- *)

module Jump_condition = struct
  module Cases = struct
    type t =
      | Always
      | X_zero
      | Y_zero
      | C_zero
      | C_nz_dec
      | Pin_low
      | Pin_high
      | Reserved
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

(*
 * JMP arg1:
 *
 *   000 ALWAYS
 *   001 X_ZERO
 *   010 Y_ZERO
 *   011 C_ZERO
 *   100 C_NZ_DEC
 *   101 PIN_LOW
 *   110 PIN_HIGH
 *   111 reserved
 *
 *
 * Non-pin JMP encoding:
 *
 *   arg2[5:0] = absolute target
 *   arg2[9:6] = reserved, must be zero
 *
 *
 * PIN_LOW / PIN_HIGH encoding:
 *
 *   arg2[9]   = input bank
 *
 *       0 UIO
 *       1 UI
 *
 *   arg2[8:6] = pin
 *   arg2[5:0] = absolute target
 *
 *
 * C_NZ_DEC semantics:
 *
 *   if C == 0:
 *     C  <- 0
 *     PC <- PC + 1
 *
 *   else:
 *     C <- C - 1
 *
 *     if C != 0:
 *       PC <- target
 *     else:
 *       PC <- PC + 1
 *
 *
 * Therefore:
 *
 *   SET C, 8
 *
 * loop:
 *   ...
 *   JMP C_NZ_DEC, loop
 *
 * executes the loop body exactly eight times.
 *
 * C does not underflow from 0 to 255.
 *)

(* -------------------------------------------------------------------------- *)
(* MOV                                                                        *)
(* -------------------------------------------------------------------------- *)

module Mov_endpoint = struct
  module Cases = struct
    type t =
      | X
      | Y
      | C
      | Ui_in
      | Uio_in
      | Pins_out
      | Pins_oe
      | Uo_out
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

(*
 * MOV encoding:
 *
 *   opcode = 101
 *
 *   arg1[2:0] = destination
 *
 *   arg2[2:0] = source
 *   arg2[9:3] = reserved, must be zero
 *
 *
 * Endpoint encoding:
 *
 *   000 X
 *   001 Y
 *   010 C
 *   011 UI_IN
 *   100 UIO_IN
 *   101 PINS_OUT
 *   110 PINS_OE
 *   111 UO_OUT
 *
 *
 * Examples:
 *
 *   MOV X, UI_IN
 *   MOV Y, UIO_IN
 *   MOV Y, X
 *   MOV PINS_OUT, X
 *   MOV UO_OUT, X
 *
 *
 * UI_IN and UIO_IN are read-only.
 *
 * Thus:
 *
 *   MOV UI_IN, X
 *
 * is illegal.
 *
 * Host-reserved pin masking is performed outside the ISA, in the wrapper /
 * host bridge. MOV observes the core-visible masked input banks.
 *)

(* -------------------------------------------------------------------------- *)
(* SYS                                                                        *)
(* -------------------------------------------------------------------------- *)

module Sys_operation = struct
  module Cases = struct
    type t =
      | Halt
      | Nop
      | Reserved_2
      | Reserved_3
      | Reserved_4
      | Reserved_5
      | Reserved_6
      | Reserved_7
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

(*
 * SYS encoding:
 *
 *   opcode = 111
 *
 *   arg1:
 *
 *       000 HALT
 *       001 NOP
 *       010 reserved
 *       011 reserved
 *       100 reserved
 *       101 reserved
 *       110 reserved
 *       111 reserved
 *
 *   arg2[9:0] = reserved, must be zero
 *
 *
 * This ordering is deliberate:
 *
 *   0xE000 = HALT
 *
 * Therefore an empty/uninitialized program-memory word safely halts
 * execution rather than behaving as a NOP.
 *)

(* -------------------------------------------------------------------------- *)
(* Abstract instruction representation                                        *)
(* -------------------------------------------------------------------------- *)

module Instruction = struct
  type set =
    { destination : Set_destination.Cases.t
    ; operation : Set_operation.Cases.t
    ; value : int
    }
  [@@deriving sexp_of, compare ~localize, equal]

  type wait =
    { pin : int
    ; source : Wait_source.Cases.t
    ; condition : Wait_condition.Cases.t
    }
  [@@deriving sexp_of, compare ~localize, equal]

  type input =
    { pin : int
    ; destination : Shift_register.Cases.t
    ; order : Shift_order.Cases.t
    ; source : Input_source.Cases.t
    }
  [@@deriving sexp_of, compare ~localize, equal]

  type output =
    { pin : int
    ; source : Shift_register.Cases.t
    ; order : Shift_order.Cases.t
    ; bank : Output_bank.Cases.t
    ; mode : Output_mode.Cases.t
    }
  [@@deriving sexp_of, compare ~localize, equal]

  (*
   * Normal branches and pin branches deliberately have different operand
   * representations.
   *
   * This prevents impossible states such as:
   *
   *   Pin_high with no pin
   *
   * or:
   *
   *   Always with a meaningless pin field.
   *)
  type jump_operand =
    | Target of
        { target : int
        }
    | Pin_target of
        { target : int
        ; pin : int
        ; source : Input_source.Cases.t
        }
  [@@deriving sexp_of, compare ~localize, equal]

  type jump =
    { condition : Jump_condition.Cases.t
    ; operand : jump_operand
    }
  [@@deriving sexp_of, compare ~localize, equal]

  type mov =
    { destination : Mov_endpoint.Cases.t
    ; source : Mov_endpoint.Cases.t
    }
  [@@deriving sexp_of, compare ~localize, equal]

  type t =
    | Set of set
    | Wait of wait
    | In of input
    | Out of output
    | Jmp of jump
    | Mov of mov
    | Delay of
        { cycles : int
        }
    | Sys of Sys_operation.Cases.t
  [@@deriving sexp_of, compare ~localize, equal]

  let opcode = function
    | Set _ -> Opcode.Cases.Set
    | Wait _ -> Opcode.Cases.Wait
    | In _ -> Opcode.Cases.In
    | Out _ -> Opcode.Cases.Out
    | Jmp _ -> Opcode.Cases.Jmp
    | Mov _ -> Opcode.Cases.Mov
    | Delay _ -> Opcode.Cases.Delay
    | Sys _ -> Opcode.Cases.Sys
  ;;
end

(* -------------------------------------------------------------------------- *)
(* Validation                                                                 *)
(* -------------------------------------------------------------------------- *)

module Validate = struct
  let pin pin =
    if pin < 0 || pin >= Arch.pin_count
    then
      Or_error.errorf
        "Pin index %d is invalid; expected 0..%d"
        pin
        (Arch.pin_count - 1)
    else Ok ()
  ;;

  let byte value =
    if value < 0 || value > 0xff
    then Or_error.errorf "Value %d does not fit in 8 bits" value
    else Ok ()
  ;;

  let jump_target target =
    if target < 0 || target >= Arch.program_words
    then
      Or_error.errorf
        "Jump target %d is invalid; expected 0..%d"
        target
        (Arch.program_words - 1)
    else Ok ()
  ;;

  let delay_cycles cycles =
    if cycles < Arch.delay_min_cycles || cycles > Arch.delay_max_cycles
    then
      Or_error.errorf
        "Delay %d is invalid; expected %d..%d cycles"
        cycles
        Arch.delay_min_cycles
        Arch.delay_max_cycles
    else Ok ()
  ;;

  let set_destination_is_reserved = function
    | Set_destination.Cases.Reserved_6
    | Reserved_7 -> true
    | X
    | Y
    | C
    | Pins_out
    | Pins_oe
    | Uo_out -> false
  ;;

  let set_operation_allowed ~destination ~operation =
    match destination with
    | Set_destination.Cases.X
    | Y
    | C ->
      Set_operation.Cases.equal operation Write
    | Pins_out
    | Pins_oe
    | Uo_out ->
      true
    | Reserved_6
    | Reserved_7 ->
      false
  ;;

  let output_mode_allowed ~bank ~mode =
    match bank, mode with
    | Output_bank.Cases.Uo, Output_mode.Cases.Open_drain -> false
    | _ -> true
  ;;

  let mov_is_writable = function
    | Mov_endpoint.Cases.X
    | Y
    | C
    | Pins_out
    | Pins_oe
    | Uo_out -> true
    | Ui_in
    | Uio_in -> false
  ;;

  let jump_condition_is_reserved = function
    | Jump_condition.Cases.Reserved -> true
    | Always
    | X_zero
    | Y_zero
    | C_zero
    | C_nz_dec
    | Pin_low
    | Pin_high -> false
  ;;

  let jump_condition_is_pin = function
    | Jump_condition.Cases.Pin_low
    | Pin_high -> true
    | Always
    | X_zero
    | Y_zero
    | C_zero
    | C_nz_dec
    | Reserved -> false
  ;;

  let sys_operation_is_valid = function
    | Sys_operation.Cases.Halt
    | Nop -> true
    | Reserved_2
    | Reserved_3
    | Reserved_4
    | Reserved_5
    | Reserved_6
    | Reserved_7 -> false
  ;;

  let jump ({ condition; operand } : Instruction.jump) =
    let open Or_error.Let_syntax in

    if jump_condition_is_reserved condition
    then Or_error.error_string "JMP uses a reserved condition"
    else
      match condition, operand with
      | ( (Always | X_zero | Y_zero | C_zero | C_nz_dec)
        , Instruction.Target { target } ) ->
        jump_target target

      | ( (Pin_low | Pin_high)
        , Instruction.Pin_target { target; pin = pin_index; _ } ) ->
        let%bind () = jump_target target in
        pin pin_index

      | ( (Pin_low | Pin_high)
        , Instruction.Target _ ) ->
        Or_error.error_string
          "PIN_LOW/PIN_HIGH JMP requires a pin target operand"

      | ( (Always | X_zero | Y_zero | C_zero | C_nz_dec)
        , Instruction.Pin_target _ ) ->
        Or_error.error_string
          "Non-pin JMP condition cannot use a pin target operand"

      | Reserved, _ ->
        (* Handled above, but keep the pattern exhaustive. *)
        Or_error.error_string "JMP uses a reserved condition"
  ;;

  let instruction = function
    | Instruction.Set { destination; operation; value } ->
      let open Or_error.Let_syntax in
      let%bind () = byte value in

      if set_destination_is_reserved destination
      then Or_error.error_string "SET uses a reserved destination"
      else if not (set_operation_allowed ~destination ~operation)
      then
        Or_error.error_string
          "SET operation is not valid for this destination"
      else Ok ()

    | Wait { pin = pin_index; _ } ->
      pin pin_index

    | In { pin = pin_index; _ } ->
      pin pin_index

    | Out { pin = pin_index; bank; mode; _ } ->
      let open Or_error.Let_syntax in
      let%bind () = pin pin_index in

      if output_mode_allowed ~bank ~mode
      then Ok ()
      else
        Or_error.error_string
          "Open-drain OUT is only valid for the UIO bank"

    | Jmp jump_instruction ->
      jump jump_instruction

    | Mov { destination; _ } ->
      if mov_is_writable destination
      then Ok ()
      else
        Or_error.error_string
          "MOV destination is read-only"

    | Delay { cycles } ->
      delay_cycles cycles

    | Sys operation ->
      if sys_operation_is_valid operation
      then Ok ()
      else
        Or_error.error_string
          "SYS uses a reserved operation"
  ;;
end

(* -------------------------------------------------------------------------- *)
(* DELAY encoding helpers                                                     *)
(* -------------------------------------------------------------------------- *)

module Delay = struct
  (*
   * Machine encoding:
   *
   *   payload = cycles - 1
   *
   * Thus:
   *
   *   payload 0    -> 1 cycle
   *   payload 1    -> 2 cycles
   *   ...
   *   payload 8191 -> 8192 cycles
   *)

  let cycles_to_payload_exn cycles =
    if cycles < Arch.delay_min_cycles || cycles > Arch.delay_max_cycles
    then
      invalid_argf
        "Silverfox DELAY must be between %d and %d cycles"
        Arch.delay_min_cycles
        Arch.delay_max_cycles
        ();

    cycles - 1
  ;;

  let payload_to_cycles payload =
    payload + 1
  ;;
end