module silverfox_isa (
    clk,
    rst_n,
    ui_in,
    ena,
    uio_in,
    uo_out,
    uio_out,
    uio_oe
);

    input clk;
    input rst_n;
    input [7:0] ui_in;
    input ena;
    input [7:0] uio_in;
    output [7:0] uo_out;
    output [7:0] uio_out;
    output [7:0] uio_oe;

    wire [7:0] signal_const;
    wire signal_const_2;
    wire signal_select;
    wire [2:0] signal_const_3;
    wire signal_eq;
    wire signal_mux;
    wire signal_select_1;
    wire signal_mux_1;
    wire signal_mux_2;
    wire signal_mux_3;
    wire signal_mux_4;
    wire [15:0] signal_const_5;
    wire [15:0] signal_const_34;
    wire [15:0] signal_const_35;
    wire [15:0] signal_const_36;
    wire [4:0] signal_const_37;
    wire [4:0] signal_const_38;
    wire [4:0] signal_add;
    wire [9:0] signal_select_2;
    wire [4:0] signal_select_3;
    wire [4:0] signal_add_1;
    wire [2:0] signal_const_40;
    wire signal_eq_1;
    wire signal_and;
    wire signal_wire;
    wire signal_not;
    wire signal_wire_1;
    wire [2:0] signal_const_43;
    wire signal_eq_2;
    wire [7:0] signal_mux_5;
    wire [7:0] signal_const_44;
    wire [7:0] signal_sub;
    wire signal_eq_3;
    wire [7:0] signal_mux_6;
    wire [7:0] signal_mux_7;
    wire [6:0] signal_select_4;
    wire [7:0] signal_cat;
    wire [6:0] signal_select_5;
    wire [7:0] signal_cat_1;
    wire [7:0] signal_mux_8;
    wire [7:0] signal_mux_9;
    wire [7:0] signal_mux_10;
    wire [7:0] signal_mux_11;
    wire [7:0] signal_mux_12;
    wire [7:0] signal_mux_13;
    wire [7:0] signal_wire_2;
    reg [7:0] signal_reg;
    wire signal_eq_4;
    wire signal_not_1;
    wire signal_eq_5;
    wire signal_and_1;
    wire [2:0] signal_const_48;
    wire signal_eq_6;
    wire [2:0] signal_select_6;
    wire signal_eq_7;
    wire signal_or;
    wire signal_or_1;
    wire signal_or_2;
    wire [4:0] signal_mux_14;
    wire [4:0] signal_add_2;
    wire [7:0] signal_select_7;
    wire signal_select_8;
    wire [7:0] signal_wire_3;
    wire signal_select_9;
    wire signal_eq_8;
    wire [4:0] signal_mux_15;
    wire [4:0] signal_add_3;
    wire [4:0] signal_add_4;
    wire [4:0] signal_add_5;
    wire [4:0] signal_add_6;
    wire [2:0] signal_const_55;
    wire signal_eq_9;
    wire [4:0] signal_mux_16;
    wire [2:0] signal_const_56;
    wire signal_eq_10;
    wire [4:0] signal_mux_17;
    wire signal_eq_11;
    wire [4:0] signal_mux_18;
    wire signal_eq_12;
    wire [4:0] signal_mux_19;
    wire signal_eq_13;
    wire [4:0] signal_mux_20;
    wire [2:0] signal_const_60;
    wire signal_eq_14;
    wire [4:0] signal_mux_21;
    wire [4:0] signal_mux_22;
    wire [4:0] signal_wire_4;
    reg [4:0] signal_reg_1;
    reg [15:0] signal_mux_23;
    wire [2:0] signal_select_10;
    wire signal_eq_15;
    wire signal_mux_24;
    wire signal_wire_5;
    reg signal_reg_2;
    wire [6:0] signal_const_61;
    wire [7:0] signal_cat_2;
    assign signal_const = 8'b00000000;
    assign signal_const_2 = 1'b0;
    assign signal_select = signal_select_7[0:0];
    assign signal_const_3 = 3'b000;
    assign signal_eq = signal_select_6 == signal_const_3;
    assign signal_mux = signal_eq ? signal_select : signal_reg_2;
    assign signal_select_1 = signal_reg[0:0];
    assign signal_mux_1 = signal_eq_11 ? signal_select_1 : signal_reg_2;
    assign signal_mux_2 = signal_eq_12 ? signal_reg_2 : signal_mux_1;
    assign signal_mux_3 = signal_eq_13 ? signal_reg_2 : signal_mux_2;
    assign signal_mux_4 = signal_eq_14 ? signal_reg_2 : signal_mux_3;
    assign signal_const_5 = 16'b1110000000000000;
    assign signal_const_34 = 16'b1000000000000000;
    assign signal_const_35 = 16'b0000000000000000;
    assign signal_const_36 = 16'b0000000000000001;
    assign signal_const_37 = 5'b00000;
    assign signal_const_38 = 5'b00001;
    assign signal_add = signal_reg_1 + signal_const_38;
    assign signal_select_2 = signal_mux_23[9:0];
    assign signal_select_3 = signal_select_2[4:0];
    assign signal_add_1 = signal_reg_1 + signal_const_38;
    assign signal_const_40 = 3'b011;
    assign signal_eq_1 = signal_select_6 == signal_const_40;
    assign signal_and = signal_eq_1 & signal_select_9;
    assign signal_wire = rst_n;
    assign signal_not = ~ signal_wire;
    assign signal_wire_1 = clk;
    assign signal_const_43 = 3'b010;
    assign signal_eq_2 = signal_select_6 == signal_const_43;
    assign signal_mux_5 = signal_eq_2 ? signal_select_7 : signal_reg;
    assign signal_const_44 = 8'b00000001;
    assign signal_sub = signal_reg - signal_const_44;
    assign signal_eq_3 = signal_select_6 == signal_const_43;
    assign signal_mux_6 = signal_eq_3 ? signal_sub : signal_reg;
    assign signal_mux_7 = signal_or_2 ? signal_mux_6 : signal_reg;
    assign signal_select_4 = signal_reg[7:1];
    assign signal_cat = { signal_select_9,
                          signal_select_4 };
    assign signal_select_5 = signal_reg[7:1];
    assign signal_cat_1 = { signal_const_2,
                            signal_select_5 };
    assign signal_mux_8 = signal_eq_10 ? signal_wire_3 : signal_reg;
    assign signal_mux_9 = signal_eq_11 ? signal_cat_1 : signal_mux_8;
    assign signal_mux_10 = signal_eq_12 ? signal_cat : signal_mux_9;
    assign signal_mux_11 = signal_eq_13 ? signal_reg : signal_mux_10;
    assign signal_mux_12 = signal_eq_14 ? signal_mux_7 : signal_mux_11;
    assign signal_mux_13 = signal_eq_15 ? signal_mux_5 : signal_mux_12;
    assign signal_wire_2 = signal_mux_13;
    always @(posedge signal_wire_1) begin
        if (signal_not)
            signal_reg <= signal_const;
        else
            signal_reg <= signal_wire_2;
    end
    assign signal_eq_4 = signal_reg == signal_const;
    assign signal_not_1 = ~ signal_eq_4;
    assign signal_eq_5 = signal_select_6 == signal_const_43;
    assign signal_and_1 = signal_eq_5 & signal_not_1;
    assign signal_const_48 = 3'b001;
    assign signal_eq_6 = signal_select_6 == signal_const_48;
    assign signal_select_6 = signal_mux_23[12:10];
    assign signal_eq_7 = signal_select_6 == signal_const_3;
    assign signal_or = signal_eq_7 | signal_eq_6;
    assign signal_or_1 = signal_or | signal_and_1;
    assign signal_or_2 = signal_or_1 | signal_and;
    assign signal_mux_14 = signal_or_2 ? signal_select_3 : signal_add_1;
    assign signal_add_2 = signal_reg_1 + signal_const_38;
    assign signal_select_7 = signal_mux_23[7:0];
    assign signal_select_8 = signal_select_7[0:0];
    assign signal_wire_3 = ui_in;
    assign signal_select_9 = signal_wire_3[0:0];
    assign signal_eq_8 = signal_select_9 == signal_select_8;
    assign signal_mux_15 = signal_eq_8 ? signal_add_2 : signal_reg_1;
    assign signal_add_3 = signal_reg_1 + signal_const_38;
    assign signal_add_4 = signal_reg_1 + signal_const_38;
    assign signal_add_5 = signal_reg_1 + signal_const_38;
    assign signal_add_6 = signal_reg_1 + signal_const_38;
    assign signal_const_55 = 3'b111;
    assign signal_eq_9 = signal_select_10 == signal_const_55;
    assign signal_mux_16 = signal_eq_9 ? signal_reg_1 : signal_add_6;
    assign signal_const_56 = 3'b101;
    assign signal_eq_10 = signal_select_10 == signal_const_56;
    assign signal_mux_17 = signal_eq_10 ? signal_add_5 : signal_mux_16;
    assign signal_eq_11 = signal_select_10 == signal_const_40;
    assign signal_mux_18 = signal_eq_11 ? signal_add_4 : signal_mux_17;
    assign signal_eq_12 = signal_select_10 == signal_const_43;
    assign signal_mux_19 = signal_eq_12 ? signal_add_3 : signal_mux_18;
    assign signal_eq_13 = signal_select_10 == signal_const_48;
    assign signal_mux_20 = signal_eq_13 ? signal_mux_15 : signal_mux_19;
    assign signal_const_60 = 3'b100;
    assign signal_eq_14 = signal_select_10 == signal_const_60;
    assign signal_mux_21 = signal_eq_14 ? signal_mux_14 : signal_mux_20;
    assign signal_mux_22 = signal_eq_15 ? signal_add : signal_mux_21;
    assign signal_wire_4 = signal_mux_22;
    always @(posedge signal_wire_1) begin
        if (signal_not)
            signal_reg_1 <= signal_const_37;
        else
            signal_reg_1 <= signal_wire_4;
    end
    always @* begin
        case (signal_reg_1)
        0:
            signal_mux_23 <= signal_const_36;
        1:
            signal_mux_23 <= signal_const_35;
        2:
            signal_mux_23 <= signal_const_34;
        3:
            signal_mux_23 <= signal_const_5;
        4:
            signal_mux_23 <= signal_const_5;
        5:
            signal_mux_23 <= signal_const_5;
        6:
            signal_mux_23 <= signal_const_5;
        7:
            signal_mux_23 <= signal_const_5;
        8:
            signal_mux_23 <= signal_const_5;
        9:
            signal_mux_23 <= signal_const_5;
        10:
            signal_mux_23 <= signal_const_5;
        11:
            signal_mux_23 <= signal_const_5;
        12:
            signal_mux_23 <= signal_const_5;
        13:
            signal_mux_23 <= signal_const_5;
        14:
            signal_mux_23 <= signal_const_5;
        15:
            signal_mux_23 <= signal_const_5;
        16:
            signal_mux_23 <= signal_const_5;
        17:
            signal_mux_23 <= signal_const_5;
        18:
            signal_mux_23 <= signal_const_5;
        19:
            signal_mux_23 <= signal_const_5;
        20:
            signal_mux_23 <= signal_const_5;
        21:
            signal_mux_23 <= signal_const_5;
        22:
            signal_mux_23 <= signal_const_5;
        23:
            signal_mux_23 <= signal_const_5;
        24:
            signal_mux_23 <= signal_const_5;
        25:
            signal_mux_23 <= signal_const_5;
        26:
            signal_mux_23 <= signal_const_5;
        27:
            signal_mux_23 <= signal_const_5;
        28:
            signal_mux_23 <= signal_const_5;
        29:
            signal_mux_23 <= signal_const_5;
        30:
            signal_mux_23 <= signal_const_5;
        default:
            signal_mux_23 <= signal_const_5;
        endcase
    end
    assign signal_select_10 = signal_mux_23[15:13];
    assign signal_eq_15 = signal_select_10 == signal_const_3;
    assign signal_mux_24 = signal_eq_15 ? signal_mux : signal_mux_4;
    assign signal_wire_5 = signal_mux_24;
    always @(posedge signal_wire_1) begin
        if (signal_not)
            signal_reg_2 <= signal_const_2;
        else
            signal_reg_2 <= signal_wire_5;
    end
    assign signal_const_61 = 7'b0000000;
    assign signal_cat_2 = { signal_const_61,
                            signal_reg_2 };
    assign uo_out = signal_cat_2;
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
    silverfox_isa
        silverfox_isa
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

