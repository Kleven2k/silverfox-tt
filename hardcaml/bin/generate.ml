(* Command-line tool for emitting Verilog from the Hardcaml sources in
   src/. Run with `dune exec bin/generate.exe -- <subcommand>`; each
   subcommand generates one circuit's RTL to stdout. *)
open! Core
open! Hardcaml
open! Silverfox

(* Generates the placeholder counter (silverfox_core) -- kept as a
   known-good toolchain sanity check, not part of the real submission. *)
let generate_core_rtl () =
  let module C = Circuit.With_interface (Silverfox_core.I) (Silverfox_core.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit =
    C.create_exn ~name:"tt_um_silverfox_kleven2k" (Silverfox_core.hierarchical scope)
  in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  print_endline (Rtl.full_hierarchy rtl_circuits |> Rope.to_string)
;;

(* Generates the ISA core running Isa.default_program (the toggle-TX
   placeholder), under the Tiny-Tapeout-required top-level module name. *)
let generate_isa_rtl () =
  let module C = Circuit.With_interface (Isa.I) (Isa.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit =
    C.create_exn
      ~name:"tt_um_silverfox_kleven2k"
      (Isa.hierarchical ~program:Isa.default_program scope)
  in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  print_endline (Rtl.full_hierarchy rtl_circuits |> Rope.to_string)
;;

(* Generates the ISA core running the real UART TX program, at the actual
   target clock/baud rate. This is what src/project.v should contain for
   the Phase 2 UART TX submission. *)
let generate_uart_tx_rtl () =
  let module C = Circuit.With_interface (Isa.I) (Isa.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let program =
    Silverfox_programs.Uart.tx_program
      ~clock_hz:25_000_000
      ~baud_rate:115_200
      ~byte:0x55
  in
  let circuit =
    C.create_exn ~name:"tt_um_silverfox_kleven2k" (Isa.hierarchical ~program scope)
  in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  print_endline (Rtl.full_hierarchy rtl_circuits |> Rope.to_string)
;;

let generate_uart_rx_rtl () =
  let module C = Circuit.With_interface (Isa.I) (Isa.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let program =
    Silverfox_programs.Uart.rx_program
      ~clock_hz: 25_000_000
      ~baud_rate: 115_200
  in
  let circuit =
    C.create_exn ~name:"tt_um_silverfox_kleven2k" (Isa.hierarchical ~program scope)
  in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  print_endline (Rtl.full_hierarchy rtl_circuits |> Rope.to_string)
;;

let core_rtl_command =
  Command.basic
    ~summary:""
    [%map_open.Command
      let () = return () in
      fun () -> generate_core_rtl ()]
;;

let isa_rtl_command =
  Command.basic
    ~summary:""
    [%map_open.Command
      let () = return () in
      fun () -> generate_isa_rtl ()]
;;

let uart_tx_rtl_command =
  Command.basic
    ~summary:""
    [%map_open.Command
      let () = return () in
      fun () -> generate_uart_tx_rtl ()]
;;

let uart_rx_rtl_command =
  Command.basic
    ~summary:""
    [%map_open.Command
      let () = return () in
      fun () -> generate_uart_rx_rtl ()]

(* Entry point: `dune exec bin/generate.exe -- core|isa|uart-tx`. *)
let () =
  Command_unix.run
    (Command.group
       ~summary:""
       [ "core", core_rtl_command
       ; "isa", isa_rtl_command
       ; "uart-tx", uart_tx_rtl_command 
       ; "uart-rx", uart_rx_rtl_command
       ])
;;
