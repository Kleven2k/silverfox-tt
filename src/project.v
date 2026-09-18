module silverfox_core (
    clk,
    rst_n,
    ena,
    ui_in,
    uio_in,
    uo_out,
    uio_out,
    uio_oe
);

    input clk;
    input rst_n;
    input ena;
    input [7:0] ui_in;
    input [7:0] uio_in;
    output [7:0] uo_out;
    output [7:0] uio_out;
    output [7:0] uio_oe;

    wire [7:0] signal_const;
    wire signal_wire;
    wire signal_not;
    wire signal_wire_1;
    wire [7:0] signal_const_3;
    wire [7:0] signal_add;
    wire [7:0] signal_wire_2;
    reg [7:0] signal_reg;
    wire signal_wire_3;
    wire [7:0] signal_mux;
    assign signal_const = 8'b00000000;
    assign signal_wire = rst_n;
    assign signal_not = ~ signal_wire;
    assign signal_wire_1 = clk;
    assign signal_const_3 = 8'b00000001;
    assign signal_add = signal_reg + signal_const_3;
    assign signal_wire_2 = signal_add;
    always @(posedge signal_wire_1) begin
        if (signal_not)
            signal_reg <= signal_const;
        else
            signal_reg <= signal_wire_2;
    end
    assign signal_wire_3 = ena;
    assign signal_mux = signal_wire_3 ? signal_reg : signal_const;
    assign uo_out = signal_mux;
    assign uio_out = signal_const;
    assign uio_oe = signal_const;

endmodule
module tt_um_silverfox_kleven2k (
    clk,
    rst_n,
    ena,
    ui_in,
    uio_in,
    uo_out,
    uio_out,
    uio_oe
);

    input clk;
    input rst_n;
    input ena;
    input [7:0] ui_in;
    input [7:0] uio_in;
    output [7:0] uo_out;
    output [7:0] uio_out;
    output [7:0] uio_oe;

    wire [7:0] signal_select;
    wire [7:0] signal_select_1;
    wire [7:0] signal_wire;
    wire [7:0] signal_wire_1;
    wire signal_wire_2;
    wire signal_wire_3;
    wire signal_wire_4;
    wire [23:0] signal_inst;
    wire [7:0] signal_select_2;
    assign signal_select = signal_inst[23:16];
    assign signal_select_1 = signal_inst[15:8];
    assign signal_wire = uio_in;
    assign signal_wire_1 = ui_in;
    assign signal_wire_2 = ena;
    assign signal_wire_3 = rst_n;
    assign signal_wire_4 = clk;
    silverfox_core
        silverfox_core
        ( .clk(signal_wire_4),
          .rst_n(signal_wire_3),
          .ena(signal_wire_2),
          .ui_in(signal_wire_1),
          .uio_in(signal_wire),
          .uo_out(signal_inst[7:0]),
          .uio_out(signal_inst[15:8]),
          .uio_oe(signal_inst[23:16]) );
    assign signal_select_2 = signal_inst[7:0];
    assign uo_out = signal_select_2;
    assign uio_out = signal_select_1;
    assign uio_oe = signal_select;

endmodule

