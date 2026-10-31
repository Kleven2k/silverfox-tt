open! Core

(* Silverfox ISA v0.3 -- software side: instruction types, bit layout, and the
   encoder/decoder. The Hardcaml RTL decoder must read the same [Field]
   positions so that software and hardware cannot disagree.

   Design rule: illegal instructions cannot be constructed. Every rule that can
   be expressed as a type (e.g. "open-drain is only available on UIO") is; the
   remaining numeric ranges are enforced by the [Bounded] smart constructors.
   Reserved encodings exist only as bit patterns, rejected by [decode]. *)

module Arch = struct
  let instruction_width = 16
  let data_width = 8
  let program_words = 64
  let pc_width = Int.ceil_log2 program_words
  let pin_count = 8
  let delay_min_cycles = 1
  let delay_max_cycles = 8192
end

(* Bit positions within the 16-bit word. The single source of truth for the
   encoder, the decoder and the RTL decoder. *)
module Field = struct
  type t =
    { lsb : int
    ; width : int
    }
  [@@deriving sexp_of]

  let mask t = (1 lsl t.width) - 1
  let get t word = (word lsr t.lsb) land mask t

  let put t value word =
    if value < 0 || value > mask t
    then raise_s [%message "BUG: value does not fit in field" (t : t) (value : int)];
    word lor (value lsl t.lsb)
  ;;

  let opcode = { lsb = 13; width = 3 }

  (* Destination (SET, MOV), pin (WAIT, IN, OUT), condition (JMP), sub-op (SYS). *)
  let arg1 = { lsb = 10; width = 3 }

  (* SET *)
  let set_operation = { lsb = 8; width = 2 }
  let set_value = { lsb = 0; width = 8 }

  (* WAIT, IN, OUT *)
  let wait_condition = { lsb = 0; width = 2 }
  let shift_register = { lsb = 0; width = 1 }
  let shift_order = { lsb = 1; width = 1 }
  let bank = { lsb = 2; width = 1 }
  let output_mode = { lsb = 3; width = 1 }

  (* JMP *)
  let jmp_target = { lsb = 0; width = 6 }
  let jmp_pin = { lsb = 6; width = 3 }
  let jmp_bank = { lsb = 9; width = 1 }

  (* MOV *)
  let mov_source = { lsb = 0; width = 3 }

  (* DELAY: the whole 13-bit operand, holding [cycles - 1]. *)
  let delay = { lsb = 0; width = 13 }
end

let reserved ~what bits =
  Or_error.error_s [%message "reserved encoding" (what : string) (bits : int)]
;;

let decode_with ~what of_bits bits =
  match of_bits bits with
  | Some x -> Ok x
  | None -> reserved ~what bits
;;

(* ---------------------------------------------------------------------- *)
(* Range-checked integers                                                  *)
(* ---------------------------------------------------------------------- *)

module type Bounded = sig
  type t = private int [@@deriving sexp_of, compare, equal]

  val min : int
  val max : int
  val of_int : int -> t Or_error.t
  val of_int_exn : int -> t
  val to_int : t -> int
  val all : t list
end

module Make_bounded (B : sig
    val name : string
    val min : int
    val max : int
  end) : Bounded = struct
  type t = int [@@deriving sexp_of, compare, equal]

  let min = B.min
  let max = B.max

  let of_int i =
    if i < min || i > max
    then
      Or_error.error_s
        [%message "value out of range" (B.name : string) (i : int) (min : int) (max : int)]
    else Ok i
  ;;

  let of_int_exn i = Or_error.ok_exn (of_int i)
  let to_int t = t
  let all = List.range min max ~stop:`inclusive
end

module Pin = Make_bounded (struct
    let name = "pin"
    let min = 0
    let max = Arch.pin_count - 1
  end)

module Target = Make_bounded (struct
    let name = "jump target"
    let min = 0
    let max = Arch.program_words - 1
  end)

module Byte = Make_bounded (struct
    let name = "byte"
    let min = 0
    let max = 0xff
  end)

module Delay_cycles = Make_bounded (struct
    let name = "delay cycles"
    let min = Arch.delay_min_cycles
    let max = Arch.delay_max_cycles
  end)

(* ---------------------------------------------------------------------- *)
(* Shared operand enums. Bit codes are written out explicitly, so reordering *)
(* constructors can never silently change the encoding.                   *)
(* ---------------------------------------------------------------------- *)

module Register = struct
  type t =
    | X
    | Y
    | C
  [@@deriving sexp_of, compare, equal, enumerate]

  (* Shared by SET destinations and MOV endpoints (000, 001, 010). *)
  let to_bits = function
    | X -> 0b000
    | Y -> 0b001
    | C -> 0b010
  ;;

  let of_bits = function
    | 0b000 -> Some X
    | 0b001 -> Some Y
    | 0b010 -> Some C
    | _ -> None
  ;;
end

module Shift_register = struct
  type t =
    | X
    | Y
  [@@deriving sexp_of, compare, equal, enumerate]

  let to_bits = function
    | X -> 0
    | Y -> 1
  ;;

  let of_bits = function
    | 0 -> Some X
    | 1 -> Some Y
    | _ -> None
  ;;
end

module Shift_order = struct
  type t =
    | Lsb_first
    | Msb_first
  [@@deriving sexp_of, compare, equal, enumerate]

  let to_bits = function
    | Lsb_first -> 0
    | Msb_first -> 1
  ;;

  let of_bits = function
    | 0 -> Some Lsb_first
    | 1 -> Some Msb_first
    | _ -> None
  ;;
end

module Input_bank = struct
  type t =
    | Uio
    | Ui
  [@@deriving sexp_of, compare, equal, enumerate]

  let to_bits = function
    | Uio -> 0
    | Ui -> 1
  ;;

  let of_bits = function
    | 0 -> Some Uio
    | 1 -> Some Ui
    | _ -> None
  ;;
end

module Level = struct
  type t =
    | Low
    | High
  [@@deriving sexp_of, compare, equal, enumerate]
end

module Gpio_register = struct
  type t =
    | Pins_out
    | Pins_oe
    | Uo_out
  [@@deriving sexp_of, compare, equal, enumerate]
end

module Gpio_operation = struct
  type t =
    | Write
    | Set_bits
    | Clear_bits
    | Toggle_bits
  [@@deriving sexp_of, compare, equal, enumerate]

  let to_bits = function
    | Write -> 0b00
    | Set_bits -> 0b01
    | Clear_bits -> 0b10
    | Toggle_bits -> 0b11
  ;;

  let of_bits = function
    | 0b00 -> Some Write
    | 0b01 -> Some Set_bits
    | 0b10 -> Some Clear_bits
    | 0b11 -> Some Toggle_bits
    | _ -> None
  ;;
end

(* ---------------------------------------------------------------------- *)
(* Instructions. Each module owns its type, encoder, decoder and the list  *)
(* of every legal instance. [encode] returns operand bits (12..0) only;    *)
(* [decode] reads operand fields from a full word. Reserved-bit checking is *)
(* done once, centrally, in [Instruction.decode].                          *)
(* ---------------------------------------------------------------------- *)

(* SET: registers support WRITE only; GPIO registers support all four ops. *)
module Set = struct
  type t =
    | Reg of
        { register : Register.t
        ; value : Byte.t
        }
    | Gpio of
        { register : Gpio_register.t
        ; operation : Gpio_operation.t
        ; mask : Byte.t
        }
  [@@deriving sexp_of, compare, equal]

  let gpio_to_bits = function
    | Gpio_register.Pins_out -> 0b011
    | Pins_oe -> 0b100
    | Uo_out -> 0b101
  ;;

  let encode t =
    let destination, operation, value =
      match t with
      | Reg { register; value } -> Register.to_bits register, Gpio_operation.Write, value
      | Gpio { register; operation; mask } -> gpio_to_bits register, operation, mask
    in
    0
    |> Field.put Field.arg1 destination
    |> Field.put Field.set_operation (Gpio_operation.to_bits operation)
    |> Field.put Field.set_value (Byte.to_int value)
  ;;

  let decode word =
    let value = Byte.of_int_exn (Field.get Field.set_value word) in
    let operation_bits = Field.get Field.set_operation word in
    let gpio register =
      Ok
        (Gpio
           { register
           ; operation = Option.value_exn (Gpio_operation.of_bits operation_bits)
           ; mask = value
           })
    in
    match Field.get Field.arg1 word with
    | (0b000 | 0b001 | 0b010) as code ->
      if operation_bits = 0
      then Ok (Reg { register = Option.value_exn (Register.of_bits code); value })
      else Or_error.error_string "SET on X/Y/C supports WRITE only"
    | 0b011 -> gpio Pins_out
    | 0b100 -> gpio Pins_oe
    | 0b101 -> gpio Uo_out
    | code -> reserved ~what:"SET destination" code
  ;;

  let all =
    List.map (List.cartesian_product Register.all Byte.all) ~f:(fun (register, value) ->
      Reg { register; value })
    @ List.concat_map Gpio_register.all ~f:(fun register ->
      List.map
        (List.cartesian_product Gpio_operation.all Byte.all)
        ~f:(fun (operation, mask) -> Gpio { register; operation; mask }))
  ;;
end

module Wait = struct
  module Condition = struct
    type t =
      | Low
      | High
      | Rising
      | Falling
    [@@deriving sexp_of, compare, equal, enumerate]

    let to_bits = function
      | Low -> 0b00
      | High -> 0b01
      | Rising -> 0b10
      | Falling -> 0b11
    ;;

    let of_bits = function
      | 0b00 -> Some Low
      | 0b01 -> Some High
      | 0b10 -> Some Rising
      | 0b11 -> Some Falling
      | _ -> None
    ;;
  end

  type t =
    { pin : Pin.t
    ; bank : Input_bank.t
    ; condition : Condition.t
    }
  [@@deriving sexp_of, compare, equal]

  let encode { pin; bank; condition } =
    0
    |> Field.put Field.arg1 (Pin.to_int pin)
    |> Field.put Field.bank (Input_bank.to_bits bank)
    |> Field.put Field.wait_condition (Condition.to_bits condition)
  ;;

  let decode word =
    let open Or_error.Let_syntax in
    let%bind bank = decode_with ~what:"WAIT bank" Input_bank.of_bits (Field.get Field.bank word) in
    let%map condition =
      decode_with ~what:"WAIT condition" Condition.of_bits (Field.get Field.wait_condition word)
    in
    { pin = Pin.of_int_exn (Field.get Field.arg1 word); bank; condition }
  ;;

  let all =
    List.concat_map Pin.all ~f:(fun pin ->
      List.concat_map Input_bank.all ~f:(fun bank ->
        List.map Condition.all ~f:(fun condition -> { pin; bank; condition })))
  ;;
end

module In = struct
  type t =
    { pin : Pin.t
    ; bank : Input_bank.t
    ; destination : Shift_register.t
    ; order : Shift_order.t
    }
  [@@deriving sexp_of, compare, equal]

  let encode { pin; bank; destination; order } =
    0
    |> Field.put Field.arg1 (Pin.to_int pin)
    |> Field.put Field.bank (Input_bank.to_bits bank)
    |> Field.put Field.shift_register (Shift_register.to_bits destination)
    |> Field.put Field.shift_order (Shift_order.to_bits order)
  ;;

  let decode word =
    let open Or_error.Let_syntax in
    let%bind bank = decode_with ~what:"IN bank" Input_bank.of_bits (Field.get Field.bank word) in
    let%bind destination =
      decode_with ~what:"IN destination" Shift_register.of_bits (Field.get Field.shift_register word)
    in
    let%map order =
      decode_with ~what:"IN order" Shift_order.of_bits (Field.get Field.shift_order word)
    in
    { pin = Pin.of_int_exn (Field.get Field.arg1 word); bank; destination; order }
  ;;

  let all =
    List.concat_map Pin.all ~f:(fun pin ->
      List.concat_map Input_bank.all ~f:(fun bank ->
        List.concat_map Shift_register.all ~f:(fun destination ->
          List.map Shift_order.all ~f:(fun order -> { pin; bank; destination; order }))))
  ;;
end

module Out = struct
  module Mode = struct
    type t =
      | Push_pull
      | Open_drain
    [@@deriving sexp_of, compare, equal, enumerate]
  end

  (* UO has no output-enable, so there is no way to even write "open-drain on
     UO". Push-pull on UIO writes PINS_OUT[pin] and leaves PINS_OE alone. *)
  type target =
    | Uio of
        { pin : Pin.t
        ; mode : Mode.t
        }
    | Uo of { pin : Pin.t }
  [@@deriving sexp_of, compare, equal]

  type t =
    { target : target
    ; source : Shift_register.t
    ; order : Shift_order.t
    }
  [@@deriving sexp_of, compare, equal]

  let encode { target; source; order } =
    let pin, bank, mode =
      match target with
      | Uio { pin; mode = Push_pull } -> pin, 0, 0
      | Uio { pin; mode = Open_drain } -> pin, 0, 1
      | Uo { pin } -> pin, 1, 0
    in
    0
    |> Field.put Field.arg1 (Pin.to_int pin)
    |> Field.put Field.bank bank
    |> Field.put Field.output_mode mode
    |> Field.put Field.shift_register (Shift_register.to_bits source)
    |> Field.put Field.shift_order (Shift_order.to_bits order)
  ;;

  let decode word =
    let open Or_error.Let_syntax in
    let pin = Pin.of_int_exn (Field.get Field.arg1 word) in
    let%bind target =
      match Field.get Field.bank word, Field.get Field.output_mode word with
      | 0, 0 -> Ok (Uio { pin; mode = Push_pull })
      | 0, 1 -> Ok (Uio { pin; mode = Open_drain })
      | 1, 0 -> Ok (Uo { pin })
      | 1, 1 -> Or_error.error_string "OUT: open-drain is not available on UO"
      | bank, mode -> raise_s [%message "BUG: 1-bit field out of range" (bank : int) (mode : int)]
    in
    let%bind source =
      decode_with ~what:"OUT source" Shift_register.of_bits (Field.get Field.shift_register word)
    in
    let%map order =
      decode_with ~what:"OUT order" Shift_order.of_bits (Field.get Field.shift_order word)
    in
    { target; source; order }
  ;;

  let all =
    let targets =
      List.concat_map Pin.all ~f:(fun pin ->
        Uo { pin } :: List.map Mode.all ~f:(fun mode -> Uio { pin; mode }))
    in
    List.concat_map targets ~f:(fun target ->
      List.concat_map Shift_register.all ~f:(fun source ->
        List.map Shift_order.all ~f:(fun order -> { target; source; order })))
  ;;
end

module Jmp = struct
  (* [C_nz_dec]: if C = 0, fall through with C unchanged (no underflow);
     otherwise decrement C and jump if the new value is nonzero. So
     "SET C, n; loop: ...; JMP C_nz_dec, loop" runs the body exactly n times. *)
  type t =
    | Always of { target : Target.t }
    | If_zero of
        { register : Register.t
        ; target : Target.t
        }
    | C_nz_dec of { target : Target.t }
    | If_pin of
        { level : Level.t
        ; bank : Input_bank.t
        ; pin : Pin.t
        ; target : Target.t
        }
  [@@deriving sexp_of, compare, equal]

  let target = function
    | Always { target } | If_zero { target; _ } | C_nz_dec { target } | If_pin { target; _ } ->
      target
  ;;

  let condition_to_bits = function
    | Always _ -> 0b000
    | If_zero { register = X; _ } -> 0b001
    | If_zero { register = Y; _ } -> 0b010
    | If_zero { register = C; _ } -> 0b011
    | C_nz_dec _ -> 0b100
    | If_pin { level = Low; _ } -> 0b101
    | If_pin { level = High; _ } -> 0b110
  ;;

  let encode t =
    let word =
      0
      |> Field.put Field.arg1 (condition_to_bits t)
      |> Field.put Field.jmp_target (Target.to_int (target t))
    in
    match t with
    | If_pin { bank; pin; _ } ->
      word
      |> Field.put Field.jmp_bank (Input_bank.to_bits bank)
      |> Field.put Field.jmp_pin (Pin.to_int pin)
    | Always _ | If_zero _ | C_nz_dec _ -> word
  ;;

  let decode word =
    let target = Target.of_int_exn (Field.get Field.jmp_target word) in
    let if_pin level =
      let pin = Pin.of_int_exn (Field.get Field.jmp_pin word) in
      Or_error.map
        (decode_with ~what:"JMP bank" Input_bank.of_bits (Field.get Field.jmp_bank word))
        ~f:(fun bank -> If_pin { level; bank; pin; target })
    in
    match Field.get Field.arg1 word with
    | 0b000 -> Ok (Always { target })
    | 0b001 -> Ok (If_zero { register = X; target })
    | 0b010 -> Ok (If_zero { register = Y; target })
    | 0b011 -> Ok (If_zero { register = C; target })
    | 0b100 -> Ok (C_nz_dec { target })
    | 0b101 -> if_pin Low
    | 0b110 -> if_pin High
    | code -> reserved ~what:"JMP condition" code
  ;;

  let all =
    List.concat_map Target.all ~f:(fun target ->
      [ Always { target }; C_nz_dec { target } ]
      @ List.map Register.all ~f:(fun register -> If_zero { register; target })
      @ List.concat_map Level.all ~f:(fun level ->
        List.concat_map Input_bank.all ~f:(fun bank ->
          List.map Pin.all ~f:(fun pin -> If_pin { level; bank; pin; target }))))
  ;;
end

module Mov = struct
  (* The input banks are not writable destinations, so they are not in this type. *)
  module Destination = struct
    type t =
      | X
      | Y
      | C
      | Pins_out
      | Pins_oe
      | Uo_out
    [@@deriving sexp_of, compare, equal, enumerate]

    let to_bits = function
      | X -> 0b000
      | Y -> 0b001
      | C -> 0b010
      | Pins_out -> 0b101
      | Pins_oe -> 0b110
      | Uo_out -> 0b111
    ;;

    let of_bits = function
      | 0b000 -> Some X
      | 0b001 -> Some Y
      | 0b010 -> Some C
      | 0b101 -> Some Pins_out
      | 0b110 -> Some Pins_oe
      | 0b111 -> Some Uo_out
      | _ -> None
    ;;
  end

  module Source = struct
    type t =
      | X
      | Y
      | C
      | Ui_in
      | Uio_in
      | Pins_out
      | Pins_oe
      | Uo_out
    [@@deriving sexp_of, compare, equal, enumerate]

    let to_bits = function
      | X -> 0b000
      | Y -> 0b001
      | C -> 0b010
      | Ui_in -> 0b011
      | Uio_in -> 0b100
      | Pins_out -> 0b101
      | Pins_oe -> 0b110
      | Uo_out -> 0b111
    ;;

    let of_bits = function
      | 0b000 -> Some X
      | 0b001 -> Some Y
      | 0b010 -> Some C
      | 0b011 -> Some Ui_in
      | 0b100 -> Some Uio_in
      | 0b101 -> Some Pins_out
      | 0b110 -> Some Pins_oe
      | 0b111 -> Some Uo_out
      | _ -> None
    ;;
  end

  (* Host-reserved pins are masked by the wrapper; MOV sees the masked banks. *)
  type t =
    { destination : Destination.t
    ; source : Source.t
    }
  [@@deriving sexp_of, compare, equal]

  let encode { destination; source } =
    0
    |> Field.put Field.arg1 (Destination.to_bits destination)
    |> Field.put Field.mov_source (Source.to_bits source)
  ;;

  let decode word =
    let open Or_error.Let_syntax in
    let%bind destination =
      decode_with
        ~what:"MOV destination (input banks are read-only)"
        Destination.of_bits
        (Field.get Field.arg1 word)
    in
    let%map source =
      decode_with ~what:"MOV source" Source.of_bits (Field.get Field.mov_source word)
    in
    { destination; source }
  ;;

  let all =
    List.map
      (List.cartesian_product Destination.all Source.all)
      ~f:(fun (destination, source) -> { destination; source })
  ;;
end

module Delay = struct
  (* Machine encoding stores [cycles - 1], so DELAY is always 1..8192 cycles. *)
  type t = { cycles : Delay_cycles.t } [@@deriving sexp_of, compare, equal]

  let encode { cycles } = Field.put Field.delay (Delay_cycles.to_int cycles - 1) 0

  let decode word =
    Ok { cycles = Delay_cycles.of_int_exn (Field.get Field.delay word + 1) }
  ;;

  let all = List.map Delay_cycles.all ~f:(fun cycles -> { cycles })
end

module Sys = struct
  (* HALT is SYS 000 on purpose: program memory resets to 0xE000, so empty
     memory halts instead of sliding through NOPs. *)
  type t =
    | Halt
    | Nop
  [@@deriving sexp_of, compare, equal, enumerate]

  let encode t =
    Field.put
      Field.arg1
      (match t with
       | Halt -> 0b000
       | Nop -> 0b001)
      0
  ;;

  let decode word =
    match Field.get Field.arg1 word with
    | 0b000 -> Ok Halt
    | 0b001 -> Ok Nop
    | code -> reserved ~what:"SYS operation" code
  ;;
end

(* ---------------------------------------------------------------------- *)
(* Top level                                                               *)
(* ---------------------------------------------------------------------- *)

module Opcode = struct
  type t =
    | Set
    | Wait
    | In
    | Out
    | Jmp
    | Mov
    | Delay
    | Sys
  [@@deriving sexp_of, compare, equal, enumerate]

  let to_bits = function
    | Set -> 0b000
    | Wait -> 0b001
    | In -> 0b010
    | Out -> 0b011
    | Jmp -> 0b100
    | Mov -> 0b101
    | Delay -> 0b110
    | Sys -> 0b111
  ;;

  let of_bits = function
    | 0b000 -> Set
    | 0b001 -> Wait
    | 0b010 -> In
    | 0b011 -> Out
    | 0b100 -> Jmp
    | 0b101 -> Mov
    | 0b110 -> Delay
    | 0b111 -> Sys
    | bits -> raise_s [%message "BUG: opcode field out of range" (bits : int)]
  ;;
end

module Instruction = struct
  type t =
    | Set of Set.t
    | Wait of Wait.t
    | In of In.t
    | Out of Out.t
    | Jmp of Jmp.t
    | Mov of Mov.t
    | Delay of Delay.t
    | Sys of Sys.t
  [@@deriving sexp_of, compare, equal]

  let encode t =
    let opcode, operands =
      match t with
      | Set x -> Opcode.Set, Set.encode x
      | Wait x -> Opcode.Wait, Wait.encode x
      | In x -> Opcode.In, In.encode x
      | Out x -> Opcode.Out, Out.encode x
      | Jmp x -> Opcode.Jmp, Jmp.encode x
      | Mov x -> Opcode.Mov, Mov.encode x
      | Delay x -> Opcode.Delay, Delay.encode x
      | Sys x -> Opcode.Sys, Sys.encode x
    in
    Field.put Field.opcode (Opcode.to_bits opcode) operands
  ;;

  (* Canonical decode: after decoding the meaningful fields, re-encode and
     require an exact match. This rejects any word with nonzero reserved bits
     without listing reserved fields per instruction, and guarantees
     [encode] and [decode] are exact inverses on legal words. *)
  let decode word =
    let open Or_error.Let_syntax in
    if word < 0 || word > 0xFFFF
    then Or_error.error_s [%message "not a 16-bit word" (word : int)]
    else (
      let%bind t =
        match Opcode.of_bits (Field.get Field.opcode word) with
        | Set -> Set.decode word >>| fun x -> Set x
        | Wait -> Wait.decode word >>| fun x -> Wait x
        | In -> In.decode word >>| fun x -> In x
        | Out -> Out.decode word >>| fun x -> Out x
        | Jmp -> Jmp.decode word >>| fun x -> Jmp x
        | Mov -> Mov.decode word >>| fun x -> Mov x
        | Delay -> Delay.decode word >>| fun x -> Delay x
        | Sys -> Sys.decode word >>| fun x -> Sys x
      in
      if encode t = word
      then Ok t
      else Or_error.error_s [%message "reserved bits must be zero" (word : int) (t : t)])
  ;;

  (* Cycles an instruction occupies before the next one starts. [None] means
     it depends on external input (WAIT) or never completes (HALT). This is the
     shared cost table for the reference model and the static timing checker. *)
  let cycles = function
    | Set _ | In _ | Out _ | Jmp _ | Mov _ | Sys Nop -> Some 1
    | Delay { cycles } -> Some (Delay_cycles.to_int cycles)
    | Wait _ | Sys Halt -> None
  ;;

  (* Every legal instruction. Used by the round-trip tests. *)
  let all =
    List.concat
      [ List.map Set.all ~f:(fun x -> Set x)
      ; List.map Wait.all ~f:(fun x -> Wait x)
      ; List.map In.all ~f:(fun x -> In x)
      ; List.map Out.all ~f:(fun x -> Out x)
      ; List.map Jmp.all ~f:(fun x -> Jmp x)
      ; List.map Mov.all ~f:(fun x -> Mov x)
      ; List.map Delay.all ~f:(fun x -> Delay x)
      ; List.map Sys.all ~f:(fun x -> Sys x)
      ]
  ;;
end
