open! Core 
open! Hardcaml
open Signal 

module I = struct 
  type 'a t =
    { instruction : 'a [@bits 16] }
  [@@deriving hardcaml]
end 

module O = struct 
  type 'a t =
    { opcode : 'a [@bits 3]
    ; arg1 : 'a [@bits 3]
    
    ; set_operation : 'a [@bits 2]
    ; set_value : 'a [@bits 8]

    ; wait_condition : 'a [@bits 2]

    ; shift_register : 'a 
    ; shift_order : 'a 
    ; bank : 'a 
    ; output_mode : 'a 

    ; jmp_target : 'a [@bits 6]
    ; jmp_pin : 'a [@bits 3]
    ; jmp_bank : 'a 

    ; mov_source : 'a [@bits 3]

    ; delay : 'a [@bits 13]

    ; illegal : 'a 
    }
  [@@deriving hardcaml]
end

(* --- Field extraction --- *)

let field (field : Isa.Field.t) word =
  Signal.select 
    word 
    ~high:(field.lsb + field.width - 1)
    ~low:field.lsb 
;;

(* --- Generic helpers --- *)

let is_zero signal =
    signal ==:. 0
;;

let is_nonzero signal =
    ~:(is_zero signal)
;;

let eq signal value =
    signal ==:. value 
;;

(* --- SET legality --- *)

let set_illegal instruction =
  let destination = field Isa.Field.arg1 instruction in
  let operation = field Isa.Field.set_operation instruction in
  let register_destination = 
    eq destination 0b000
    |: eq destination 0b001
    |: eq destination 0b010
  in
  let reserved_destination =
    eq destination 0b110
    |: eq destination 0b111
  in
  let non_write_operation = is_nonzero operation in
  reserved_destination |: (register_destination &: non_write_operation)
;;

(*--- WAIT legality --- *)

let wait_illegal instruction = 
  let reserved_bits = select instruction ~high:9 ~low:3 in
  is_nonzero reserved_bits
;; 

(* --- IN legality --- *)

let in_illegal instruction =
  let reserved_bits = select instruction ~high:9 ~low:3 in
  is_nonzero reserved_bits
;;

(* --- OUT legality --- *)

let out_illegal instruction =
    let bank = field Isa.Field.bank instruction in
    let mode = field Isa.Field.output_mode instruction in
    let reserved_bits = select instruction ~high:9 ~low:4 in
    let open_drain_on_uo = bank &: mode in
    is_nonzero reserved_bits |: open_drain_on_uo
;;

(* --- JMP legality --- *)

let jmp_illegal instruction =
    let conditon = field Isa.Field.arg1 instruction in
    let upper = select instruction ~high:9 ~low:6 in
    let pin_condition = eq conditon 0b101 |: eq conditon 0b110 in
    let reserved_condition = eq conditon 0b111 in
    let upper_must_be_zero = ~:pin_condition in
    reserved_condition |: (upper_must_be_zero &: is_nonzero upper)
;;

(* --- MOV legality --- *)

let mov_illegal instruction =
    let destination = field Isa.Field.arg1 instruction in
    let reserved_bits = select instruction ~high:9 ~low:3 in
    let readonly_destination = eq destination 0b011 |: eq destination 0b100 in
    readonly_destination |: is_nonzero reserved_bits
;;

(* --- DELAY legality --- *)

let delay_illegal _instruction =
    gnd
;;

(* --- SYS legality --- *)

let sys_illegal instruction = 
    let operation = field Isa.Field.arg1 instruction in
    let arg2 = select instruction ~high:9 ~low:0 in
    let valid_operation = eq operation 0b000 |: eq operation 0b001 in
    ~:valid_operation |: is_nonzero arg2
;;

let create (_scope : Scope.t) (i : _ I.t) =
  let instruction = i.instruction in 
  let opcode = field Isa.Field.opcode instruction in

  let illegal =
    mux 
        opcode 
        [ set_illegal instruction
        ; wait_illegal instruction
        ; in_illegal instruction
        ; out_illegal instruction 
        ; jmp_illegal instruction
        ; mov_illegal instruction
        ; delay_illegal instruction
        ; sys_illegal instruction
        ]
  in

  { O.opcode =
      field Isa.Field.opcode instruction
  ; arg1 =
      field Isa.Field.arg1 instruction 
  ; set_operation =
      field Isa.Field.set_operation instruction
  ; set_value =
      field Isa.Field.set_value instruction
  ; wait_condition =
      field Isa.Field.wait_condition instruction
  ; shift_register =
      field Isa.Field.shift_register instruction 
  ; shift_order =
      field Isa.Field.shift_order instruction 
  ; bank =
      field Isa.Field.bank instruction
  ; output_mode =
      field Isa.Field.output_mode instruction 
  ; jmp_target =
      field Isa.Field.jmp_target instruction
  ; jmp_pin =
      field Isa.Field.jmp_pin instruction
  ; jmp_bank =
      field Isa.Field.jmp_bank instruction
  ; mov_source =
      field Isa.Field.mov_source instruction
  ; delay =
      field Isa.Field.delay instruction 
      
  ; illegal
  }
;;