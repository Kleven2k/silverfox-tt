open! Core

module Arch = struct
  let instruction_width = 16
  let data_width = 8
  let program_words = 64
  let pc_width = Int.ceil_log2 program_words
  let pin_count = 8
  let delay_min_cycles = 1
  let delay_max_cycles = 8192
end

(* Bit positions within the 16-bit word. The signle source of truth for the
   encoder, the decoder and the RTL decoder. *)
module Field = struct 
  type t =
    {lsb : int 
    ; width : int
    }
  [@@deriving sexp_of]

  let mask t  = (1 lsl t.width) - 1
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

  (* WAIT *)
  let wait_condition = { lsb = 0; width = 2 }
  let bank = { lsb = 2; width = 1 }
end 

let reserved ~what bits =
  Or_error.error_s [%message "reserved destination" (what : string) (bits : int)]
;;

let decode_with ~what of_bits bits =
  match of_bits bits with 
  | Some x -> Ok x 
  | None -> reserved ~what bits 
;;

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

module Byte = Make_bounded (struct
  let name = "byte" 
  let min = 0
  let max = 0xff
end)

module Register = struct
  type t =
    | X
    | Y
    | C
  [@@deriving sexp_of, compare, equal, enumerate]

  (* Shared by SET destinations and MOV endpoints. *)
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

module Set = struct
  type t =
    | Reg of 
      {register : Register.t
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
      Ok(
        Gpio
          { register
          ; operation = Option.value_exn (Gpio_operation.of_bits operation_bits)
          ; mask = value
          }
      ) in
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
  
end

