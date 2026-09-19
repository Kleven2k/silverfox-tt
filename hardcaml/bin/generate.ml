open! Core
open! Hardcaml
open! Silverfox

let generate_core_rtl () =
  let module C = Circuit.With_interface (Silverfox_core.I) (Silverfox_core.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit =
    C.create_exn ~name:"tt_um_silverfox_kleven2k" (Silverfox_core.hierarchical scope)
  in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  let rtl = Rtl.full_hierarchy rtl_circuits |> Rope.to_string in
  print_endline rtl
;;

let generate_isa_rtl () =
  let module C = Circuit.With_interface (Isa.I) (Isa.O) in
  let scope  = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"tt_um_silverfox_kleven2k" (Isa.hierarchical scope) in
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

let () =
  Command_unix.run
    (Command.group ~summary:"" [ "core", core_rtl_command; "isa", isa_rtl_command ])
;;