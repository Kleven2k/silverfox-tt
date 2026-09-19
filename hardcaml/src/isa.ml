open! Core 
open! Hardcaml
open! Signal 

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end 

module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

(* ISA constants *)
module Opcode = struct
  [@@@warning "-32"]
  let set = 0b000
  let wait_ = 0b001
  let in_ = 0b010
  let out = 0b011
  let jmp = 0b100
  let mov = 0b101
  let halt = 0b111
end

module Cond = struct
  let always = 0b000
  let not_tx_valid = 0b001
  let x_not_zero = 0b010
  let rx_high = 0b011
end

module Reg_id = struct
  [@@@warning "-32"]
  let pin_tx = 0b000
  let pin_tx_ready = 0b001
  let reg_x = 0b010
  let pin_rx = 0b011
end

let pc_width = 5
let mem_depth = 1 lsl pc_width

let encode ~opcode ~arg1 ~arg2 =
  (opcode lsl 13) lor (arg1 lsl 10) lor (arg2 land 0x3ff)
;;

(* Placeholder program: toggle TX forever via SET + JMP.
   Proves decode/PC/jump logic; WAIT/IN/OUT/MOV come next. *)
let program =
  [ encode ~opcode:Opcode.set ~arg1:Reg_id.pin_tx ~arg2:1
  ; encode ~opcode:Opcode.set ~arg1:Reg_id.pin_tx ~arg2:0
  ; encode ~opcode:Opcode.jmp ~arg1:Cond.always ~arg2:0
  ]
;;

let program_padded =
  let pad = mem_depth - List.length program in
  program @ List.init pad ~f:(fun _ -> encode ~opcode:Opcode.halt ~arg1:0 ~arg2:0)
;;

let rom_entries = List.map program_padded ~f:(fun v -> of_int_trunc ~width:16 v)

let create (i : _ I.t) =
  let spec = Reg_spec.create ~clock:i.clk ~clear:(~:(i.rst_n)) () in
  let open Always in
  let pc = Variable.reg spec ~width:pc_width in
  let x_reg = Variable.reg spec ~width:8 in
  let tx = Variable.reg spec ~width:1 in
  let instr = mux pc.value rom_entries in
  let opcode = select instr ~high:15 ~low:13 in
  let arg1 = select instr ~high:12 ~low:10 in
  let arg2_imm = select instr ~high:7 ~low:0 in
  let jmp_target = uresize (select instr ~high:9 ~low:0) ~width:pc_width in
  let is_op op = opcode ==:. op in
  let is_arg1 v = arg1 ==:. v in
  let x_is_zero = x_reg.value ==:. 0 in
  let jmp_taken =
    is_arg1 Cond.always
    |: is_arg1 Cond.not_tx_valid
    |: (is_arg1 Cond.x_not_zero &: ~:x_is_zero)
    |: (is_arg1 Cond.rx_high &: select i.ui_in ~high:0 ~low:0)
  in
  compile
    [ if_
        (is_op Opcode.set)
        [ if_ (is_arg1 Reg_id.pin_tx) [ tx <-- select arg2_imm ~high:0 ~low:0 ][]
        ; if_ (is_arg1 Reg_id.reg_x) [ x_reg <-- arg2_imm ] []
        ; pc <-- pc.value +:. 1
        ]
        [ if_ 
            (is_op Opcode.jmp)
            [ if_ 
                jmp_taken
                [ pc <-- jmp_target
                ; if_ 
                    (is_arg1 Cond.x_not_zero)
                    [ x_reg <-- x_reg.value -:. 1]
                    []
                ]
                [ pc <-- pc.value +:. 1 ]
            ]
            [ if_ (is_op Opcode.halt) [] [ pc <-- pc.value +:. 1 ] ]
        ]
    ];
  { O.uo_out = uresize tx.value ~width:8; uio_out = zero 8; uio_oe = zero 8 }
;;

let hierarchical scope (i : _ I.t) =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"silverfox_isa" (fun (_scope : Scope.t) i -> create i) i
;;
