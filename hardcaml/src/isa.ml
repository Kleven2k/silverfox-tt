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

(* ISA opcode/condition/register constants. Exposed via the .mli so
   callers (generate.ml, tests, protocol programs) can build their own
   instruction sequences using [encode] below rather than hand-computing
   opcode bit patterns. *)
module Opcode = struct
  let set = 0b000
  let wait_ = 0b001 (* trailing underscore avoids clashing with OCaml's [wait] *)
  let in_ = 0b010 (* trailing underscore avoids clashing with OCaml's [in] keyword *)
  let out = 0b011
  let jmp = 0b100
  let mov = 0b101
  let halt = 0b111
end

(* Extended with a second scratch register, Y: a receiver needs a
   delay-loop countdown that runs concurrently with IN accumulating a
   received byte in X, and one register can't do both jobs at once. Y
   mirrors X's pattern exactly (SET, and JMP's Y_NOT_ZERO condition).
   This mirrors the RP2040 PIO's own X/Y scratch-register design, for
   the same reason. *)
module Cond = struct
  let always = 0b000
  let not_tx_valid = 0b001
  let x_not_zero = 0b010
  let rx_high = 0b011
  let y_not_zero = 0b100
end

module Reg_id = struct
  let pin_tx = 0b000
  let pin_tx_ready = 0b001
  let reg_x = 0b010
  let pin_rx = 0b011
  let reg_y = 0b100
end

let pc_width = 5 (* 5-bit PC -> 2^5 = 32 addressable instructions *)
let mem_depth = 1 lsl pc_width (* [lsl] = logical shift left; 1 lsl 5 = 32 *)

(* Packs opcode/arg1/arg2 into a single 16-bit int, matching the
   opcode[15:13]/arg1[12:10]/arg2[9:0] layout documented in isa.md.
   This runs in plain OCaml, not in hardware -- it's just arithmetic used to
   build instruction lists (programs), not signals. *)
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
   instructions, so unused memory does something well-defined rather than
   being garbage. *)
let pad_program program =
  let pad = mem_depth - List.length program in
  if pad < 0
  then failwith "Program exceeds instruction memory depth"
  else program @ List.init pad ~f:(fun _ -> encode ~opcode:Opcode.halt ~arg1:0 ~arg2:0)
;;

(* Extra output-only interface used solely for testing: exposes the raw
   internal registers ([x_reg], [pc]) so a test can read them directly via
   Cyclesim.outputs, instead of inferring their values indirectly through
   [uo_out] and hand-derived timing offsets -- which is what led to a long
   debugging session for the OUT test (see decisions.md). Never used by
   generate.ml or the real TT submission; test-only. *)
module Debug_o = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; x_reg : 'a [@bits 8]
    ; y_reg : 'a [@bits 8]
    ; pc : 'a [@bits 5]
    }
  [@@deriving hardcaml]
end

(* [compute] builds the actual circuit logic once and returns every signal
   both the production [create] and the test-only [create_debug] need --
   this avoids duplicating the whole decode/execute block between the two.
   Everything below describes *hardware*, not a sequence of steps that
   "run": all these signals exist and update simultaneously, every clock
   cycle, the way real logic gates do. *)
let compute ~program (i : _ I.t) =
  let rom_entries =
    List.map (pad_program program) ~f:(fun v -> of_int_trunc ~width:16 v)
  in
  (* [Reg_spec] bundles together the clock and reset signal that every
     register in this circuit will share. [~:(i.rst_n)] inverts rst_n,
     since it's active-low but Hardcaml's [~clear] expects active-high. *)
  let spec = Reg_spec.create ~clock:i.clk ~clear:(~:(i.rst_n)) () in
  let open Always in
  (* [Variable.reg] declares a register. Unlike a plain wire, its [.value]
     reflects last cycle's assignment -- the assignment made via [<--]
     below only takes effect on the *next* clock edge. This is what causes
     the one-cycle latency documented in isa.md. *)
  let pc = Variable.reg spec ~width:pc_width in
  let x_reg = Variable.reg spec ~width:8 in
  (* [y_reg]: second scratch register, dedicated to delay-loop countdowns
     (e.g. a receiver's mid-bit-sample timing) so it doesn't collide with
     [x_reg] when [x_reg] is simultaneously accumlating received data via
     IN. *)
  let y_reg = Variable.reg spec ~width:8 in
  let tx = Variable.reg spec ~width:1 in

  (* Instruction fetch: [mux pc.value rom_entries] is a big multiplexer
     that selects one of the ROM entries based on the current PC value --
     a purely combinational read, so [instr] reflects the instruction at
     whatever PC currently holds. *)
  let instr = mux pc.value rom_entries in

  (* Field decode: [select signal ~high ~low] pulls out a sub-range of
     bits, same as Verilog's [signal[high:low]]. *)
  let opcode = select instr ~high:15 ~low:13 in
  let arg1 = select instr ~high:12 ~low:10 in
  let arg2_imm = select instr ~high:7 ~low:0 in
  (* [uresize ... ~width:pc_width] truncates/zero-extends the 10-bit jump
     field down to the PC's actual width (5 bits), since our program
     memory is smaller than what arg2 could theoretically address. *)
  let jmp_target = uresize (select instr ~high:9 ~low:0) ~width:pc_width in

  (* Small helpers to make the [compile] block below read more like
     English. Each returns a 1-bit signal (a comparator), not an OCaml
     bool -- [opcode ==:. op] means "build hardware that computes whether
     opcode currently equals this constant", evaluated fresh every cycle. *)
  let is_op op = opcode ==:. op in
  let is_arg1 v = arg1 ==:. v in
  let x_is_zero = x_reg.value ==:. 0 in
  let y_is_zero = y_reg.value ==:. 0 in

  let rx_bit = select i.ui_in ~high:0 ~low:0 in (* RX is wired to ui_in's bit 0 *)
  let wait_target = select arg2_imm ~high:0 ~low:0 in (* WAIT's target polarity *)
  let wait_satisfied = rx_bit ==: wait_target in

  (* All four JMP conditions OR'd together -- true if *any* applies.
     RX_HIGH is ANDed with the live [rx_bit] so the jump only fires when
     that specific condition is both *selected* (arg1) and *true* (pin
     state). *)
  let jmp_taken =
    is_arg1 Cond.always
    |: is_arg1 Cond.not_tx_valid
    |: (is_arg1 Cond.x_not_zero &: ~:x_is_zero)
    |: (is_arg1 Cond.rx_high &: rx_bit)
    |: (is_arg1 Cond.y_not_zero &: ~:y_is_zero)
  in

  (* IN: shift a new bit into X from the MSB side, so that after 8 calls
     the earliest-received (LSB-first, per UART convention) bit ends up in
     X's bit 0 -- reconstructing the byte in the correct order. Verified
     against a hand-traced shift sequence; see decisions.md. *)
  let in_shifted = concat_msb [ rx_bit; select x_reg.value ~high:7 ~low:1 ] in

  (* OUT: send X's current LSB (the next bit to transmit, LSB-first), then
     shift X right so the following bit becomes the new LSB. *)
  let out_bit = select x_reg.value ~high:0 ~low:0 in
  let out_shifted = concat_msb [ zero 1; select x_reg.value ~high:7 ~low:1 ] in

  (* [compile] takes a list of [Always] statements and wires up every
     register's next value. [if_ cond then_branch else_branch] is
     Hardcaml's if/else -- there's no built-in elif, so we nest [if_] as
     the sole item of an else-branch to build a chain, checking each
     opcode in turn. *)
  compile
    [ if_
        (is_op Opcode.set)
        [ if_ (is_arg1 Reg_id.pin_tx) [ tx <-- select arg2_imm ~high:0 ~low:0 ] []
        ; if_ (is_arg1 Reg_id.reg_x) [ x_reg <-- arg2_imm ] []
        ; if_ (is_arg1 Reg_id.reg_y) [ y_reg <-- arg2_imm ] []
        ; pc <-- pc.value +:. 1
        ]
        [ if_
            (is_op Opcode.jmp)
            [ if_
                jmp_taken
                [ pc <-- jmp_target
                  (* X/Y only decrement when the jump is actually taken AND
                     the condition was the matching *_NOT_ZERO -- mirrors
                     RP2040 PIO's combined "decrement and branch"
                     instruction. *)
                ; if_ (is_arg1 Cond.x_not_zero) [ x_reg <-- x_reg.value -:. 1 ] []
                ; if_ (is_arg1 Cond.y_not_zero) [ y_reg <-- y_reg.value -:. 1 ] [] 
                ]
                [ pc <-- pc.value +:. 1 ]
            ]
            [ if_
                (is_op Opcode.wait_)
                (* WAIT does NOT jump anywhere -- it holds PC still until
                   the condition becomes true, then falls through
                   normally. *)
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
                            (* Current MOV: parallel-loads all of ui_in
                               into X in one cycle. Only variant
                               implemented so far -- untested by a
                               dedicated unit test, treated as low-risk
                               given its simplicity. *)
                            [ x_reg <-- i.ui_in; pc <-- pc.value +:. 1 ]
                            (* Final fallback: HALT holds PC in place
                               (empty then-branch); anything else just
                               increments PC as a safe default. *)
                            [ if_ (is_op Opcode.halt) [] [ pc <-- pc.value +:. 1 ] ]
                        ]
                    ]
                ]
            ]
        ]
    ];
  (* Return the four signals both [create] and [create_debug] need,
     tagged with a polymorphic variant purely so the tuple's meaning is
     self-documenting at each call site. *)
  `Signals (tx.value, x_reg.value, y_reg.value, pc.value)
;;

(* Production interface: only exposes [uo_out]/[uio_out]/[uio_oe], matching
   what generate.ml emits as the real TT submission. *)
let create ~program (i : _ I.t) =
  let (`Signals (tx, _x_reg, _y_reg, _pc)) = compute ~program i in
  { O.uo_out = uresize tx ~width:8; uio_out = zero 8; uio_oe = zero 8 }
;;

(* Test-only variant: same logic as [create], but also exposes [x_reg] and
   [pc] directly as outputs, so a test can read their exact values via
   Cyclesim.outputs without inferring them from uo_out and hand-counted
   timing offsets. *)
let create_debug ~program (i : _ I.t) : _ Debug_o.t =
  let (`Signals (tx, x_reg, y_reg, pc)) = compute ~program i in
  { Debug_o.uo_out = uresize tx ~width:8; x_reg; y_reg; pc = uresize pc ~width:5 }
;;

(* Wraps [create] for use inside a larger design's hierarchy -- gives this
   module a clean instance name ("silverfox_isa") when it shows up nested
   inside another circuit's generated Verilog, e.g. under
   tt_um_silverfox_kleven2k. [program] is threaded through so a caller
   (generate.ml, a test) can supply whichever program this instance should
   run. *)
let hierarchical ~program scope (i : _ I.t) =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical
    ~scope
    ~name:"silverfox_isa"
    (fun (_scope : Scope.t) i -> create ~program i)
    i
;;