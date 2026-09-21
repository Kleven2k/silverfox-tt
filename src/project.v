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
    wire [15:0] signal_const_7;
    wire [15:0] signal_const_8;
    wire [15:0] signal_const_9;
    wire [15:0] signal_const_10;
    wire [15:0] signal_const_12;
    wire [15:0] signal_const_13;
    wire [15:0] signal_const_16;
    wire [15:0] signal_const_19;
    wire [15:0] signal_const_22;
    wire [15:0] signal_const_25;
    wire [15:0] signal_const_28;
    wire [15:0] signal_const_31;
    wire [15:0] signal_const_34;
    wire [4:0] signal_const_37;
    wire [4:0] signal_const_38;
    wire [4:0] signal_add;
    wire [9:0] signal_select_2;
    wire [4:0] signal_select_3;
    wire [4:0] signal_add_1;
    wire [2:0] signal_const_42;
    wire signal_eq_1;
    wire [7:0] signal_mux_5;
    wire [7:0] signal_const_43;
    wire [7:0] signal_sub;
    wire signal_eq_2;
    wire [7:0] signal_mux_6;
    wire [7:0] signal_mux_7;
    wire [7:0] signal_mux_8;
    wire [7:0] signal_mux_9;
    wire [7:0] signal_wire;
    reg [7:0] signal_reg;
    wire signal_eq_3;
    wire signal_not;
    wire signal_eq_4;
    wire signal_and;
    wire [2:0] signal_const_46;
    wire signal_eq_5;
    wire signal_and_1;
    wire signal_wire_1;
    wire signal_not_1;
    wire signal_wire_2;
    wire [2:0] signal_const_49;
    wire signal_eq_6;
    wire [7:0] signal_mux_10;
    wire [7:0] signal_sub_1;
    wire signal_eq_7;
    wire [7:0] signal_mux_11;
    wire [7:0] signal_mux_12;
    wire [6:0] signal_select_4;
    wire [7:0] signal_cat;
    wire [6:0] signal_select_5;
    wire [7:0] signal_cat_1;
    wire [7:0] signal_mux_13;
    wire [7:0] signal_mux_14;
    wire [7:0] signal_mux_15;
    wire [7:0] signal_mux_16;
    wire [7:0] signal_mux_17;
    wire [7:0] signal_mux_18;
    wire [7:0] signal_wire_3;
    reg [7:0] signal_reg_1;
    wire signal_eq_8;
    wire signal_not_2;
    wire signal_eq_9;
    wire signal_and_2;
    wire [2:0] signal_const_54;
    wire signal_eq_10;
    wire [2:0] signal_select_6;
    wire signal_eq_11;
    wire signal_or;
    wire signal_or_1;
    wire signal_or_2;
    wire signal_or_3;
    wire [4:0] signal_mux_19;
    wire [4:0] signal_add_2;
    wire [7:0] signal_select_7;
    wire signal_select_8;
    wire [7:0] signal_wire_4;
    wire signal_select_9;
    wire signal_eq_12;
    wire [4:0] signal_mux_20;
    wire [4:0] signal_add_3;
    wire [4:0] signal_add_4;
    wire [4:0] signal_add_5;
    wire [4:0] signal_add_6;
    wire [2:0] signal_const_61;
    wire signal_eq_13;
    wire [4:0] signal_mux_21;
    wire [2:0] signal_const_62;
    wire signal_eq_14;
    wire [4:0] signal_mux_22;
    wire signal_eq_15;
    wire [4:0] signal_mux_23;
    wire signal_eq_16;
    wire [4:0] signal_mux_24;
    wire signal_eq_17;
    wire [4:0] signal_mux_25;
    wire signal_eq_18;
    wire [4:0] signal_mux_26;
    wire [4:0] signal_mux_27;
    wire [4:0] signal_wire_5;
    reg [4:0] signal_reg_2;
    reg [15:0] signal_mux_28;
    wire [2:0] signal_select_10;
    wire signal_eq_19;
    wire signal_mux_29;
    wire signal_wire_6;
    reg signal_reg_3;
    wire [6:0] signal_const_67;
    wire [7:0] signal_cat_2;
    assign signal_const = 8'b00000000;
    assign signal_const_2 = 1'b0;
    assign signal_select = signal_select_7[0:0];
    assign signal_const_3 = 3'b000;
    assign signal_eq = signal_select_6 == signal_const_3;
    assign signal_mux = signal_eq ? signal_select : signal_reg_3;
    assign signal_select_1 = signal_reg_1[0:0];
    assign signal_mux_1 = signal_eq_15 ? signal_select_1 : signal_reg_3;
    assign signal_mux_2 = signal_eq_16 ? signal_reg_3 : signal_mux_1;
    assign signal_mux_3 = signal_eq_17 ? signal_reg_3 : signal_mux_2;
    assign signal_mux_4 = signal_eq_18 ? signal_reg_3 : signal_mux_3;
    assign signal_const_5 = 16'b1110000000000000;
    assign signal_const_7 = 16'b1000100000011101;
    assign signal_const_8 = 16'b0000100011010110;
    assign signal_const_9 = 16'b0000000000000001;
    assign signal_const_10 = 16'b1000100000011010;
    assign signal_const_12 = 16'b0000000000000000;
    assign signal_const_13 = 16'b1000100000010111;
    assign signal_const_16 = 16'b1000100000010100;
    assign signal_const_19 = 16'b1000100000010001;
    assign signal_const_22 = 16'b1000100000001110;
    assign signal_const_25 = 16'b1000100000001011;
    assign signal_const_28 = 16'b1000100000001000;
    assign signal_const_31 = 16'b1000100000000101;
    assign signal_const_34 = 16'b1000100000000010;
    assign signal_const_37 = 5'b00000;
    assign signal_const_38 = 5'b00001;
    assign signal_add = signal_reg_2 + signal_const_38;
    assign signal_select_2 = signal_mux_28[9:0];
    assign signal_select_3 = signal_select_2[4:0];
    assign signal_add_1 = signal_reg_2 + signal_const_38;
    assign signal_const_42 = 3'b100;
    assign signal_eq_1 = signal_select_6 == signal_const_42;
    assign signal_mux_5 = signal_eq_1 ? signal_select_7 : signal_reg;
    assign signal_const_43 = 8'b00000001;
    assign signal_sub = signal_reg - signal_const_43;
    assign signal_eq_2 = signal_select_6 == signal_const_42;
    assign signal_mux_6 = signal_eq_2 ? signal_sub : signal_reg;
    assign signal_mux_7 = signal_or_3 ? signal_mux_6 : signal_reg;
    assign signal_mux_8 = signal_eq_18 ? signal_mux_7 : signal_reg;
    assign signal_mux_9 = signal_eq_19 ? signal_mux_5 : signal_mux_8;
    assign signal_wire = signal_mux_9;
    always @(posedge signal_wire_2) begin
        if (signal_not_1)
            signal_reg <= signal_const;
        else
            signal_reg <= signal_wire;
    end
    assign signal_eq_3 = signal_reg == signal_const;
    assign signal_not = ~ signal_eq_3;
    assign signal_eq_4 = signal_select_6 == signal_const_42;
    assign signal_and = signal_eq_4 & signal_not;
    assign signal_const_46 = 3'b011;
    assign signal_eq_5 = signal_select_6 == signal_const_46;
    assign signal_and_1 = signal_eq_5 & signal_select_9;
    assign signal_wire_1 = rst_n;
    assign signal_not_1 = ~ signal_wire_1;
    assign signal_wire_2 = clk;
    assign signal_const_49 = 3'b010;
    assign signal_eq_6 = signal_select_6 == signal_const_49;
    assign signal_mux_10 = signal_eq_6 ? signal_select_7 : signal_reg_1;
    assign signal_sub_1 = signal_reg_1 - signal_const_43;
    assign signal_eq_7 = signal_select_6 == signal_const_49;
    assign signal_mux_11 = signal_eq_7 ? signal_sub_1 : signal_reg_1;
    assign signal_mux_12 = signal_or_3 ? signal_mux_11 : signal_reg_1;
    assign signal_select_4 = signal_reg_1[7:1];
    assign signal_cat = { signal_select_9,
                          signal_select_4 };
    assign signal_select_5 = signal_reg_1[7:1];
    assign signal_cat_1 = { signal_const_2,
                            signal_select_5 };
    assign signal_mux_13 = signal_eq_14 ? signal_wire_4 : signal_reg_1;
    assign signal_mux_14 = signal_eq_15 ? signal_cat_1 : signal_mux_13;
    assign signal_mux_15 = signal_eq_16 ? signal_cat : signal_mux_14;
    assign signal_mux_16 = signal_eq_17 ? signal_reg_1 : signal_mux_15;
    assign signal_mux_17 = signal_eq_18 ? signal_mux_12 : signal_mux_16;
    assign signal_mux_18 = signal_eq_19 ? signal_mux_10 : signal_mux_17;
    assign signal_wire_3 = signal_mux_18;
    always @(posedge signal_wire_2) begin
        if (signal_not_1)
            signal_reg_1 <= signal_const;
        else
            signal_reg_1 <= signal_wire_3;
    end
    assign signal_eq_8 = signal_reg_1 == signal_const;
    assign signal_not_2 = ~ signal_eq_8;
    assign signal_eq_9 = signal_select_6 == signal_const_49;
    assign signal_and_2 = signal_eq_9 & signal_not_2;
    assign signal_const_54 = 3'b001;
    assign signal_eq_10 = signal_select_6 == signal_const_54;
    assign signal_select_6 = signal_mux_28[12:10];
    assign signal_eq_11 = signal_select_6 == signal_const_3;
    assign signal_or = signal_eq_11 | signal_eq_10;
    assign signal_or_1 = signal_or | signal_and_2;
    assign signal_or_2 = signal_or_1 | signal_and_1;
    assign signal_or_3 = signal_or_2 | signal_and;
    assign signal_mux_19 = signal_or_3 ? signal_select_3 : signal_add_1;
    assign signal_add_2 = signal_reg_2 + signal_const_38;
    assign signal_select_7 = signal_mux_28[7:0];
    assign signal_select_8 = signal_select_7[0:0];
    assign signal_wire_4 = ui_in;
    assign signal_select_9 = signal_wire_4[0:0];
    assign signal_eq_12 = signal_select_9 == signal_select_8;
    assign signal_mux_20 = signal_eq_12 ? signal_add_2 : signal_reg_2;
    assign signal_add_3 = signal_reg_2 + signal_const_38;
    assign signal_add_4 = signal_reg_2 + signal_const_38;
    assign signal_add_5 = signal_reg_2 + signal_const_38;
    assign signal_add_6 = signal_reg_2 + signal_const_38;
    assign signal_const_61 = 3'b111;
    assign signal_eq_13 = signal_select_10 == signal_const_61;
    assign signal_mux_21 = signal_eq_13 ? signal_reg_2 : signal_add_6;
    assign signal_const_62 = 3'b101;
    assign signal_eq_14 = signal_select_10 == signal_const_62;
    assign signal_mux_22 = signal_eq_14 ? signal_add_5 : signal_mux_21;
    assign signal_eq_15 = signal_select_10 == signal_const_46;
    assign signal_mux_23 = signal_eq_15 ? signal_add_4 : signal_mux_22;
    assign signal_eq_16 = signal_select_10 == signal_const_49;
    assign signal_mux_24 = signal_eq_16 ? signal_add_3 : signal_mux_23;
    assign signal_eq_17 = signal_select_10 == signal_const_54;
    assign signal_mux_25 = signal_eq_17 ? signal_mux_20 : signal_mux_24;
    assign signal_eq_18 = signal_select_10 == signal_const_42;
    assign signal_mux_26 = signal_eq_18 ? signal_mux_19 : signal_mux_25;
    assign signal_mux_27 = signal_eq_19 ? signal_add : signal_mux_26;
    assign signal_wire_5 = signal_mux_27;
    always @(posedge signal_wire_2) begin
        if (signal_not_1)
            signal_reg_2 <= signal_const_37;
        else
            signal_reg_2 <= signal_wire_5;
    end
    always @* begin
        case (signal_reg_2)
        0:
            signal_mux_28 <= signal_const_12;
        1:
            signal_mux_28 <= signal_const_8;
        2:
            signal_mux_28 <= signal_const_34;
        3:
            signal_mux_28 <= signal_const_9;
        4:
            signal_mux_28 <= signal_const_8;
        5:
            signal_mux_28 <= signal_const_31;
        6:
            signal_mux_28 <= signal_const_12;
        7:
            signal_mux_28 <= signal_const_8;
        8:
            signal_mux_28 <= signal_const_28;
        9:
            signal_mux_28 <= signal_const_9;
        10:
            signal_mux_28 <= signal_const_8;
        11:
            signal_mux_28 <= signal_const_25;
        12:
            signal_mux_28 <= signal_const_12;
        13:
            signal_mux_28 <= signal_const_8;
        14:
            signal_mux_28 <= signal_const_22;
        15:
            signal_mux_28 <= signal_const_9;
        16:
            signal_mux_28 <= signal_const_8;
        17:
            signal_mux_28 <= signal_const_19;
        18:
            signal_mux_28 <= signal_const_12;
        19:
            signal_mux_28 <= signal_const_8;
        20:
            signal_mux_28 <= signal_const_16;
        21:
            signal_mux_28 <= signal_const_9;
        22:
            signal_mux_28 <= signal_const_8;
        23:
            signal_mux_28 <= signal_const_13;
        24:
            signal_mux_28 <= signal_const_12;
        25:
            signal_mux_28 <= signal_const_8;
        26:
            signal_mux_28 <= signal_const_10;
        27:
            signal_mux_28 <= signal_const_9;
        28:
            signal_mux_28 <= signal_const_8;
        29:
            signal_mux_28 <= signal_const_7;
        30:
            signal_mux_28 <= signal_const_5;
        default:
            signal_mux_28 <= signal_const_5;
        endcase
    end
    assign signal_select_10 = signal_mux_28[15:13];
    assign signal_eq_19 = signal_select_10 == signal_const_3;
    assign signal_mux_29 = signal_eq_19 ? signal_mux : signal_mux_4;
    assign signal_wire_6 = signal_mux_29;
    always @(posedge signal_wire_2) begin
        if (signal_not_1)
            signal_reg_3 <= signal_const_2;
        else
            signal_reg_3 <= signal_wire_6;
    end
    assign signal_const_67 = 7'b0000000;
    assign signal_cat_2 = { signal_const_67,
                            signal_reg_3 };
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

