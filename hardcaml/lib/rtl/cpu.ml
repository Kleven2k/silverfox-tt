open! Core 
open! Hardcaml 
open! Signal 

module I = struct
  type 'a t =
    { clock : 'a 
    ; reset : 'a 

    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]

    ; prog_we : 'a 
    ; prog_addr : 'a [@bits 6]
    ; prog_data : 'a [@bits 16]
    }
  [@@deriving hardcaml]
end

module O = struct 
  type 'a t =
    { pc : 'a [@bits 6]
    ; x : 'a [@bits 8]
    ; y : 'a [@bits 8]
    ; c : 'a [@bits 8]

    ; pins_out : 'a [@bits 8]
    ; pins_oe : 'a [@bits 8]
    ; uo_out : 'a [@bits 8]

    ; halt_status : 'a [@bits 2]
    }
  [@@deriving hardcaml]
end
