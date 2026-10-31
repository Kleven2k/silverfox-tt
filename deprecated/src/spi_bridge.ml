open! Core 
open! Hardcaml
open! Signal 

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

  (* Raw host pins, before synchronization. Never used directly below --
     everything downstream reads the *_synced values instead. *)
  let cs_n_raw = select i.ui_in ~high:4 ~low:4 in
  let sclk_raw = select i.ui_in ~high:5 ~low:5 in
  let mosi_raw = select i.ui_in ~high:6 ~low:6 in

  (* 2-flop synchronizer per host pin: the textbook minimum depth to
     resolve metastability from an asynchronous host clock/CS/data line
     down to a safe probability, before this logic ever branches on
     their value. Never branch on cs_n_raw/sclk_raw/mosi_raw directly. *)
  let synchronize raw =
    let stage_1 = Variable.reg spec ~width:1 in
    let stage_2 = Variable.reg spec ~width:1 in
    compile [ stage_1 <-- raw; stage_2 <-- stage_1.value ];
    stage_2.value
  in
  let cs_n_synced = synchronize cs_n_raw in
  let sclk_synced = synchronize sclk_raw in
  let mosi_synced = synchronize mosi_raw in

  (* SCLK edge detector: one more delay register on the already-synced
     SCLK, then compare current vs. previous. rising fires the cycle
     after SCLK's synchronized value goes 0->1 (SPI mode 0: sample MOSI
     here); falling fires the cycle after 1->0 (advance MISO here). *)
  let sclk_prev = Variable.reg spec ~width:1 in
  compile [ sclk_prev <-- sclk_synced ];
  let rising = ~:(sclk_prev.value) &: sclk_synced in
  let falling = sclk_prev.value &: ~:sclk_synced in

  let core_ui_in = i.ui_in &: of_unsigned_int ~width: 8 0b1000_1111 in

  let byte_index = Variable.reg spec ~width:3 in
  let bit_index = Variable.reg spec ~width:3 in
  let mosi_shift_reg = Variable.reg spec ~width:8 in
  let command = Variable.reg spec ~width:8 in
  let address = Variable.reg spec ~width:8 in
  let write_data_hi = Variable.reg spec ~width:8 in
  let response = Variable.reg spec ~width:16 in
  let is_command byte = command.value ==:. byte in

  (* MSB-first shift-in, per the doc's framing. This is *this* rising
     edge's incoming value, not yet registered -- used both to update
     mosi_shift_reg and, on a byte's final bit, as the just-completed
     byte's value (avoids waiting a spurious extra cycle for
     mosi_shift_reg.value to reflect the 8th bit). *)
  let mosi_shifted_in = concat_msb [ select mosi_shift_reg.value ~high:6 ~low:0; mosi_synced ] in
  let byte_complete = rising &: (bit_index.value ==:. 7) in

  (* Byte 3 (write_data low) is the last of the 4 command bytes; per the
     doc, execute the command once here, for every command -- not just
     WRITE_INSTR -- so the response captured at this same edge is ready
     to serialize starting at byte 4. commit already implies rising and
     byte_complete, so it's safe as a top-level (unconditional) statement
     alongside the byte-counter logic below. *)
  let commit = byte_complete &: (byte_index.value ==:. 3) in
  let core_write_data = concat_msb [ write_data_hi.value; mosi_shifted_in ] in
  let core_halt = wire 1 in
  let core_restart = wire 1 in
  let core_write_enable = wire 1 in
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
        cs_n_synced
        [ bit_index <--. 0; byte_index <--. 0 ]
        [ if_
            rising
            [ mosi_shift_reg <-- mosi_shifted_in
            ; if_
                byte_complete
                [ bit_index <--. 0
                ; switch
                    byte_index.value
                    [ ( of_unsigned_int ~width:3 0, [ command <-- mosi_shifted_in ] )
                    ; ( of_unsigned_int ~width:3 1, [ address <-- mosi_shifted_in ] )
                    ; ( of_unsigned_int ~width:3 2, [ write_data_hi <-- mosi_shifted_in ] )
                    ]
                ; if_ (byte_index.value <:. 6) [ byte_index <-- byte_index.value +:. 1 ] []
                ]
                [ bit_index <-- bit_index.value +:. 1 ]
            ]
            []
        ]
    ; if_ commit [ response <-- captured_response ] []
    ];

  (* MISO shift-out. Loaded with the response's high byte the same cycle
     commit fires (byte_index is about to become 4), then re-loaded with
     the low byte when byte 4 completes (byte_index becomes 5) so it's
     ready before byte 5's bits go out. Shifts MSB-first on each falling
     edge -- SPI mode 0: outputs change following falling edges, so the
     new bit is stable well before the host's next rising-edge sample. *)
  let miso_shift_reg = Variable.reg spec ~width:8 in
  let byte_index_will_be_4 = commit in
  let byte_index_will_be_5 = byte_complete &: (byte_index.value ==:. 4) in
  compile
    [ if_
        byte_index_will_be_4
        [ miso_shift_reg <-- select response.value ~high:15 ~low:8 ]
        [ if_
            byte_index_will_be_5
            [ miso_shift_reg <-- select response.value ~high:7 ~low:0 ]
            [ if_
                falling
                [ miso_shift_reg <-- concat_msb [ select miso_shift_reg.value ~high:6 ~low:0; gnd ] ]
                []
            ]
        ]
    ];
  let miso = select miso_shift_reg.value ~high:7 ~low:7 in

  (* Pin mapping per docs/host-interface.md: uo_out[0] is UART TX,
     uo_out[1] is HOST_MISO. uio is untouched by the host interface --
     fully available to a future protocol program. *)
  { O.uo_out = concat_msb [ zero 6; miso; core.tx ]
  ; uio_out = zero 8
  ; uio_oe = zero 8
  }
;;

let hierarchical scope (i : _ I.t) =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"silverfox_spi_bridge" (fun (_scope : Scope.t) i -> create i) i
;;