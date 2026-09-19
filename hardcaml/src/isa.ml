open! Core
open! Hardcaml
open! Signal

(* [I] defines the module's input ports. [@@deriving hardcaml] auto-generates
   all the boilerplate Hardcaml needs (port creation, naming, etc.) from this
   plain-looking record type. *)
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

(* [O] defines the output ports, same mechanism as [I]. *)
module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

(* ISA constants, mirroring core_pkg.vh. Exposed via the .mli so callers
   (generate.ml, tests, future protocol programs) can build their own
   instruction sequences using [encode] below rather than hand-computing
   opcode bit patterns. *)
module Opcode = struct
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
  let pin_tx = 0b000
  let pin_tx_ready = 0b001
  let reg_x = 0b010
  let pin_rx = 0b011
end

let pc_width = 5 (* 5-bit PC -> 2^5 = 32 addressable instructions *)
let mem_depth = 1 lsl pc_width

(* Packs opcode/arg1/arg2 into a single 16-bit int, matching the
   opcode[15:13]/arg1[12:10]/arg2[9:0] layout documented in isa.md.
   Plain OCaml arithmetic -- used to build instruction lists, not hardware. *)
let encode ~opcode ~arg1 ~arg2 =
  (opcode lsl 13) lor (arg1 lsl 10) lor (arg2 land 0x3ff)
;;

(* The original toggle-TX placeholder program, kept as the default used by
   generate.ml's "isa" command and by the SET/JMP regression test. Real
   programs (UART, SPI, I2C, and per-opcode tests) are passed into [create]
   directly instead of living here. *)
let default_program =
  [ encode ~opcode:Opcode.set ~arg1:Reg_id.pin_tx ~arg2:1
  ; encode ~opcode:Opcode.set ~arg1:Reg_id.pin_tx ~arg2:0
  ; encode ~opcode:Opcode.jmp ~arg1:Cond.always ~arg2:0
  ]
;;

(* Pads a program out to the full [mem_depth]-entry memory with HALT
   instructions, so unused memory does something well-defined. *)
let pad_program program =
  let pad = mem_depth - List.length program in
  if pad < 0
  then failwith "Program exceeds instruction memory depth"
  else program @ List.init pad ~f:(fun _ -> encode ~opcode:Opcode.halt ~arg1:0 ~arg2:0)
;;

(* ... everything above [create] is unchanged: I, O, Opcode, Cond, Reg_id,
   pc_width, mem_depth, encode, default_program, pad_program ... *)

(* Extra output-only interface used solely for testing: exposes the raw
   internal registers so a test can read [x_reg]/[pc] directly via
   Cyclesim.outputs, instead of inferring their values indirectly through
   [uo_out] and hand-derived timing offsets. Never used by generate.ml or
   the real TT submission -- test-only. *)
module Debug_o = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; x_reg : 'a [@bits 8]
    ; pc : 'a [@bits 5]
    }
  [@@deriving hardcaml]
end

(* Shared internals: builds the actual logic once, returning every signal
   both the production [create] and the test-only [create_debug] need.
   This avoids duplicating the whole decode/execute block. *)
let compute ~program (i : _ I.t) =
  let rom_entries =
    List.map (pad_program program) ~f:(fun v -> of_int_trunc ~width:16 v)
  in
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
  let rx_bit = select i.ui_in ~high:0 ~low:0 in
  let wait_target = select arg2_imm ~high:0 ~low:0 in
  let wait_satisfied = rx_bit ==: wait_target in
  let jmp_taken =
    is_arg1 Cond.always
    |: is_arg1 Cond.not_tx_valid
    |: (is_arg1 Cond.x_not_zero &: ~:x_is_zero)
    |: (is_arg1 Cond.rx_high &: rx_bit)
  in
  let in_shifted = concat_msb [ rx_bit; select x_reg.value ~high:7 ~low:1 ] in
  let out_bit = select x_reg.value ~high:0 ~low:0 in
  let out_shifted = concat_msb [ zero 1; select x_reg.value ~high:7 ~low:1 ] in
  compile
    [ if_
        (is_op Opcode.set)
        [ if_ (is_arg1 Reg_id.pin_tx) [ tx <-- select arg2_imm ~high:0 ~low:0 ] []
        ; if_ (is_arg1 Reg_id.reg_x) [ x_reg <-- arg2_imm ] []
        ; pc <-- pc.value +:. 1
        ]
        [ if_
            (is_op Opcode.jmp)
            [ if_
                jmp_taken
                [ pc <-- jmp_target
                ; if_ (is_arg1 Cond.x_not_zero) [ x_reg <-- x_reg.value -:. 1 ] []
                ]
                [ pc <-- pc.value +:. 1 ]
            ]
            [ if_
                (is_op Opcode.wait_)
                [ if_ wait_satisfied [ pc <-- pc.value +:. 1 ] [] ]
                [ if_
                    (is_op Opcode.in_)
                    [ x_reg <-- in_shifted; pc <-- pc.value +:. 1 ]
                    [ if_
                        (is_op Opcode.out)
                        [ tx <-- out_bit
                        ; x_reg <-- out_shifted
                        ; pc <-- pc.value +:. 1
                        ]
                        [ if_
                            (is_op Opcode.mov)
                            [ x_reg <-- i.ui_in; pc <-- pc.value +:. 1 ]
                            [ if_ (is_op Opcode.halt) [] [ pc <-- pc.value +:. 1 ] ]
                        ]
                    ]
                ]
            ]
        ]
    ];
  `Signals (tx.value, x_reg.value, pc.value)
;;

let create ~program (i : _ I.t) =
  let (`Signals (tx, _x_reg, _pc)) = compute ~program i in
  { O.uo_out = uresize tx ~width:8; uio_out = zero 8; uio_oe = zero 8 }
;;

(* Test-only variant: same logic as [create], but also exposes [x_reg] and
   [pc] directly as outputs, so a test can read their exact values via
   Cyclesim.outputs without inferring them from uo_out and hand-counted
   timing offsets. *)
let create_debug ~program (i : _ I.t) : _ Debug_o.t =
  let (`Signals (tx, x_reg, pc)) = compute ~program i in
  { Debug_o.uo_out = uresize tx ~width:8; x_reg; pc = uresize pc ~width:5 }
;;

let hierarchical ~program scope (i : _ I.t) =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical
    ~scope
    ~name:"silverfox_isa"
    (fun (_scope : Scope.t) i -> create ~program i)
    i
;;