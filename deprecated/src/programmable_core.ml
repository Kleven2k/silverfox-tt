open! Core
open! Hardcaml
open! Signal

(* Internal, clk-synchronous interface for the future host transport.
   Commands are single-cycle strobes, not asynchronous board pins. *)
module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a [@bits 8]
    ; halt : 'a
    ; restart : 'a
    ; write_enable : 'a
    ; address : 'a [@bits 8]
    ; write_data : 'a [@bits 16]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { tx : 'a
    ; pc : 'a [@bits 5]
    ; x_reg : 'a [@bits 8]
    ; y_reg : 'a [@bits 8]
    ; running : 'a
    ; halted_by_instruction : 'a
    ; read_data : 'a [@bits 16]
    ; read_valid : 'a
    ; write_accepted : 'a
    ; restart_accepted : 'a
    }
  [@@deriving hardcaml]
end

let create (i : _ I.t) : _ O.t =
  let spec = Reg_spec.create ~clock:i.clk ~clear:(~:(i.rst_n)) () in
  let open Always in
  let running = Variable.reg spec ~width:1 in
  let halted_by_instruction = Variable.reg spec ~width:1 in
  let active = i.rst_n &: i.ena in
  let stopped = ~:(running.value) in
  (* HALT wins over every other request. Conflicting write/restart strobes
     are rejected rather than starting with a partially updated program. *)
  let restart_accepted =
    active &: stopped &: ~:(i.halt) &: i.restart &: ~:(i.write_enable)
  in
  let execute_enable = active &: running.value &: ~:(i.halt) in
  let read_valid = active &: stopped &: (i.address <:. Isa.mem_depth) in
  let read_data = wire 16 in
  let write_accepted = wire 1 in
  let halt_instruction = wire 1 in
  let state =
    Isa.execute
      ~fetch:(fun pc ->
        let memory =
          Program_memory.create
            { clk = i.clk
            ; rst_n = i.rst_n
            ; halted = stopped
            ; write_enable =
                active &: i.write_enable &: ~:(i.halt) &: ~:(i.restart)
            ; write_address = i.address
            ; write_data = i.write_data
            ; read_address = mux2 running.value pc (uresize i.address ~width:5)
            }
        in
        Signal.assign read_data (mux2 read_valid memory.read_data (zero 16));
        Signal.assign write_accepted memory.write_accepted;
        Signal.assign halt_instruction
          (select memory.read_data ~high:15 ~low:13 ==:. Isa.Opcode.halt);
        memory.read_data)
      ~enable:execute_enable
      ~restart:restart_accepted
      ~reset_tx:vdd
      { Isa.I.clk = i.clk
      ; rst_n = i.rst_n
      ; ena = i.ena
      ; ui_in = i.ui_in
      ; uio_in = zero 8
      }
  in
  compile
    [ if_ (~:(i.ena) |: i.halt)
        [ running <-- gnd; halted_by_instruction <-- gnd ]
        [ if_ restart_accepted
            [ running <-- vdd; halted_by_instruction <-- gnd ]
            [ if_ (execute_enable &: halt_instruction)
                [ running <-- gnd; halted_by_instruction <-- vdd ]
                []
            ]
        ]
    ];
  { O.tx = select state.uo_out ~high:0 ~low:0
  ; pc = state.pc
  ; x_reg = state.x_reg
  ; y_reg = state.y_reg
  ; running = running.value
  ; halted_by_instruction = halted_by_instruction.value
  ; read_data
  ; read_valid
  ; write_accepted
  ; restart_accepted
  }
;;
