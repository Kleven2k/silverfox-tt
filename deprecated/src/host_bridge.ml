open! Core
open! Hardcaml
open! Signal

(* Crude, pin-driven host loader: a byte-wide bus on uio, advanced by a
   strobe pin, standing in for the SPI transport described in
   docs/host-interface.md until that's built. Not the final protocol --
   no CS, no serial clock recovery, no result-code byte -- just enough to
   prove a program can be loaded and read back through real TT pins with
   no RTL regeneration in between.

   Transaction shape, 6 bytes per BYTE_STROBE-advanced cycle count:
     0: command   (0x01 HALT, 0x02 RESTART, 0x10 WRITE_INSTR, 0x11 READ_INSTR, 0x20 READ_STATE)
     1: address   (0-31, or register select for READ_STATE: 0=PC 1=X 2=Y 3=TX)
     2: write_data high byte (WRITE_INSTR only, else ignored)
     3: write_data low byte  (WRITE_INSTR only, else ignored)
     4: response high byte, driven by the chip on uio
     5: response low byte, driven by the chip on uio
   The counter then wraps back to 0 for the next command. *)

module Command = struct
  let halt = 0x01
  let restart = 0x02
  let write_instr = 0x10
  let read_instr = 0x11
  let read_state = 0x20
end

module State_sel = struct
  let pc = 0
  let x = 1
  let y = 2
  let tx = 3
end

(* Matches Tiny Tapeout's required top-level interface exactly -- this
   module IS the TT top level, not a sub-block behind one. ui_in[1] is
   BYTE_STROBE, dedicated to this host loader; ui_in[0] remains UART RX,
   per docs/host-interface.md's pin table. *)
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

let create (i : _ I.t) : _ O.t =
  let spec = Reg_spec.create ~clock:i.clk ~clear:(~:(i.rst_n)) () in
  let open Always in
  let byte_strobe = select i.ui_in ~high:1 ~low:1 in
  (* Host pins must never leak into protocol data (docs/host-interface.md):
     mask BYTE_STROBE out of the ui_in the ISA core sees, so MOV's
     parallel read of ui_in can't observe host traffic. *)
  let core_ui_in = i.ui_in &: of_unsigned_int ~width:8 0b1111_1101 in
  let byte_index = Variable.reg spec ~width:3 in
  let command = Variable.reg spec ~width:8 in
  let address = Variable.reg spec ~width:8 in
  let write_data_hi = Variable.reg spec ~width:8 in
  let response = Variable.reg spec ~width:16 in
  (* Driving uio only during the two response bytes keeps the bus released
     (input) the rest of the time, so the host can safely drive it. *)
  let driving_response = byte_index.value ==:. 4 |: (byte_index.value ==:. 5) in
  let is_command byte = command.value ==:. byte in
  let core_halt = wire 1 in
  let core_restart = wire 1 in
  let core_write_enable = wire 1 in
  let core_write_data = wire 16 in
  let core =
    Programmable_core.create
      { Programmable_core.I.clk = i.clk
      ; rst_n = i.rst_n
      ; ena = i.ena
      ; ui_in = core_ui_in
      ; halt = core_halt
      ; restart = core_restart
      ; write_enable = core_write_enable
      ; address = address.value
      ; write_data = core_write_data
      }
  in
  Signal.assign core_write_data (concat_msb [ write_data_hi.value; i.uio_in ]);
  (* Byte 3 (write_data low) landing on the bus is what actually commits a
     WRITE_INSTR; every other command only needs byte 1 (address), so it
     commits as soon as that byte arrives -- issuing it again on byte 3
     would double-strobe restart/halt for one cycle too long. *)
  let committing_byte = mux2 (is_command Command.write_instr) (byte_index.value ==:. 3) (byte_index.value ==:. 1) in
  let commit = byte_strobe &: committing_byte in
  Signal.assign core_halt (commit &: is_command Command.halt);
  Signal.assign core_restart (commit &: is_command Command.restart);
  Signal.assign core_write_enable (commit &: is_command Command.write_instr);
  let state_value =
    mux
      address.value
      [ uresize core.pc ~width:16
      ; uresize core.x_reg ~width:16
      ; uresize core.y_reg ~width:16
      ; uresize core.tx ~width:16
      ]
  in
  let captured_response =
    mux2
      (is_command Command.read_instr)
      core.read_data
      (mux2 (is_command Command.read_state) state_value (zero 16))
  in
  compile
    [ if_
        (byte_strobe &: i.rst_n)
        [ switch
            byte_index.value
            [ ( of_unsigned_int ~width:3 0, [ command <-- i.uio_in ] )
            ; ( of_unsigned_int ~width:3 1, [ address <-- i.uio_in ] )
            ; ( of_unsigned_int ~width:3 2, [ write_data_hi <-- i.uio_in ] )
            ; ( of_unsigned_int ~width:3 3, [ response <-- captured_response ] )
            ]
        ; if_ (byte_index.value ==:. 5) [ byte_index <--. 0 ] [ byte_index <-- byte_index.value +:. 1 ]
        ]
        []
    ];
  let response_byte =
    mux2 (byte_index.value ==:. 4) (select response.value ~high:15 ~low:8) (select response.value ~high:7 ~low:0)
  in
  { O.uo_out = uresize core.tx ~width:8
  ; uio_out = mux2 driving_response response_byte (zero 8)
  ; uio_oe = mux2 driving_response (ones 8) (zero 8)
  }
;;

let hierarchical scope (i : _ I.t) =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"silverfox_host_bridge" (fun (_scope : Scope.t) i -> create i) i
;;
