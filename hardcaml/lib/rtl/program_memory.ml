open! Core
open! Hardcaml
open! Signal

module I = struct 
  type 'a t =
    { clock : 'a 
    ; reset : 'a 
    ; read_addr : 'a [@bits Isa.Arch.pc_width]
    ; write_enable : 'a 
    ; write_addr : 'a [@bits Isa.Arch.pc_width]
    ; write_data : 'a [@bits Isa.Arch.instruction_width]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a  t =
    { instruction : 'a [@bits Isa.Arch.instruction_width] }
  [@@deriving hardcaml]
end

let create (_scope : Scope.t) (i : _ I.t) =
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.reset () in
  let halt = 
    of_int_trunc ~width:Isa.Arch.instruction_width
      (Isa.Instruction.encode (Isa.Instruction.Sys Isa.Sys.Halt))
  in
  let words =
    List.init Isa.Arch.program_words 
    ~f:(fun address ->
      reg 
        spec 
          ~enable:
            (i.write_enable &: (i.write_addr ==:. address))
          ~clear_to:halt
          i.write_data)
  in
  { O.instruction = mux i.read_addr words }
;;