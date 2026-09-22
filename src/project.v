module silverfox_host_bridge (
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
    wire [7:0] signal_const_1;
    wire [7:0] signal_mux;
    wire [7:0] signal_select;
    wire [15:0] signal_const_2;
    wire [7:0] signal_const_4;
    wire signal_lt;
    wire signal_and;
    wire signal_and_1;
    wire [15:0] signal_mux_1;
    wire [15:0] signal_wire;
    wire [14:0] signal_const_5;
    wire [15:0] signal_cat;
    wire [15:0] signal_cat_1;
    wire [15:0] signal_cat_2;
    wire [10:0] signal_const_8;
    wire [15:0] signal_cat_3;
    reg [15:0] signal_mux_2;
    wire signal_eq;
    wire [15:0] signal_mux_3;
    wire [7:0] signal_const_11;
    wire signal_eq_1;
    wire [15:0] signal_mux_4;
    reg [15:0] signal_cases;
    wire [15:0] signal_mux_5;
    wire [15:0] signal_wire_1;
    reg [15:0] signal_reg;
    wire [7:0] signal_select_1;
    wire [2:0] signal_const_13;
    wire signal_eq_2;
    wire [7:0] signal_mux_6;
    wire [2:0] signal_const_15;
    wire signal_eq_3;
    wire signal_eq_4;
    wire signal_or;
    wire [7:0] signal_mux_7;
    wire signal_select_2;
    wire [2:0] signal_const_17;
    wire signal_eq_5;
    wire signal_mux_8;
    wire signal_select_3;
    wire signal_mux_9;
    wire signal_mux_10;
    wire signal_mux_11;
    wire signal_mux_12;
    wire signal_mux_13;
    wire signal_mux_14;
    wire signal_not;
    wire signal_not_1;
    wire signal_const_18;
    wire signal_not_2;
    wire vdd;
    wire gnd;
    wire [2:0] signal_const_19;
    wire [7:0] signal_const_20;
    wire signal_eq_6;
    wire signal_and_2;
    reg [15:0] signal_reg_1;
    wire [7:0] signal_const_21;
    wire signal_eq_7;
    wire signal_and_3;
    reg [15:0] signal_reg_2;
    wire [7:0] signal_const_22;
    wire signal_eq_8;
    wire signal_and_4;
    reg [15:0] signal_reg_3;
    wire [7:0] signal_const_23;
    wire signal_eq_9;
    wire signal_and_5;
    reg [15:0] signal_reg_4;
    wire [7:0] signal_const_24;
    wire signal_eq_10;
    wire signal_and_6;
    reg [15:0] signal_reg_5;
    wire [7:0] signal_const_25;
    wire signal_eq_11;
    wire signal_and_7;
    reg [15:0] signal_reg_6;
    wire [7:0] signal_const_26;
    wire signal_eq_12;
    wire signal_and_8;
    reg [15:0] signal_reg_7;
    wire [7:0] signal_const_27;
    wire signal_eq_13;
    wire signal_and_9;
    reg [15:0] signal_reg_8;
    wire [7:0] signal_const_28;
    wire signal_eq_14;
    wire signal_and_10;
    reg [15:0] signal_reg_9;
    wire [7:0] signal_const_29;
    wire signal_eq_15;
    wire signal_and_11;
    reg [15:0] signal_reg_10;
    wire [7:0] signal_const_30;
    wire signal_eq_16;
    wire signal_and_12;
    reg [15:0] signal_reg_11;
    wire [7:0] signal_const_31;
    wire signal_eq_17;
    wire signal_and_13;
    reg [15:0] signal_reg_12;
    wire [7:0] signal_const_32;
    wire signal_eq_18;
    wire signal_and_14;
    reg [15:0] signal_reg_13;
    wire [7:0] signal_const_33;
    wire signal_eq_19;
    wire signal_and_15;
    reg [15:0] signal_reg_14;
    wire signal_eq_20;
    wire signal_and_16;
    reg [15:0] signal_reg_15;
    wire [7:0] signal_const_35;
    wire signal_eq_21;
    wire signal_and_17;
    reg [15:0] signal_reg_16;
    wire [7:0] signal_const_36;
    wire signal_eq_22;
    wire signal_and_18;
    reg [15:0] signal_reg_17;
    wire [7:0] signal_const_37;
    wire signal_eq_23;
    wire signal_and_19;
    reg [15:0] signal_reg_18;
    wire [7:0] signal_const_38;
    wire signal_eq_24;
    wire signal_and_20;
    reg [15:0] signal_reg_19;
    wire [7:0] signal_const_39;
    wire signal_eq_25;
    wire signal_and_21;
    reg [15:0] signal_reg_20;
    wire [7:0] signal_const_40;
    wire signal_eq_26;
    wire signal_and_22;
    reg [15:0] signal_reg_21;
    wire [7:0] signal_const_41;
    wire signal_eq_27;
    wire signal_and_23;
    reg [15:0] signal_reg_22;
    wire [7:0] signal_const_42;
    wire signal_eq_28;
    wire signal_and_24;
    reg [15:0] signal_reg_23;
    wire [7:0] signal_const_43;
    wire signal_eq_29;
    wire signal_and_25;
    reg [15:0] signal_reg_24;
    wire [7:0] signal_const_44;
    wire signal_eq_30;
    wire signal_and_26;
    reg [15:0] signal_reg_25;
    wire [7:0] signal_const_45;
    wire signal_eq_31;
    wire signal_and_27;
    reg [15:0] signal_reg_26;
    wire [7:0] signal_const_46;
    wire signal_eq_32;
    wire signal_and_28;
    reg [15:0] signal_reg_27;
    wire [7:0] signal_const_47;
    wire signal_eq_33;
    wire signal_and_29;
    reg [15:0] signal_reg_28;
    wire [7:0] signal_const_48;
    wire signal_eq_34;
    wire signal_and_30;
    reg [15:0] signal_reg_29;
    wire [7:0] signal_const_49;
    wire signal_eq_35;
    wire signal_and_31;
    reg [15:0] signal_reg_30;
    wire [7:0] signal_const_50;
    wire signal_eq_36;
    wire signal_and_32;
    reg [15:0] signal_reg_31;
    wire signal_eq_37;
    wire signal_lt_1;
    wire signal_eq_38;
    wire signal_and_33;
    wire signal_wire_2;
    wire signal_not_3;
    wire signal_not_4;
    wire signal_eq_39;
    wire signal_and_34;
    wire signal_wire_3;
    wire signal_and_35;
    wire signal_and_36;
    wire signal_and_37;
    wire signal_and_38;
    wire signal_and_39;
    wire signal_and_40;
    wire signal_and_41;
    wire [15:0] signal_const_55;
    wire signal_not_5;
    reg [7:0] signal_cases_1;
    wire [7:0] signal_mux_15;
    wire [7:0] signal_wire_4;
    reg [7:0] signal_reg_32;
    wire [15:0] signal_cat_4;
    wire [15:0] signal_wire_5;
    reg [15:0] signal_reg_33;
    wire [4:0] signal_const_58;
    wire [4:0] signal_const_60;
    wire [4:0] signal_add;
    wire [9:0] signal_select_4;
    wire [4:0] signal_select_5;
    wire [4:0] signal_add_1;
    wire signal_eq_40;
    wire [7:0] signal_mux_16;
    wire [7:0] signal_sub;
    wire signal_eq_41;
    wire [7:0] signal_mux_17;
    wire [7:0] signal_mux_18;
    wire [7:0] signal_mux_19;
    wire [7:0] signal_mux_20;
    wire [7:0] signal_mux_21;
    wire [7:0] signal_mux_22;
    wire [7:0] signal_wire_6;
    reg [7:0] signal_reg_34;
    wire signal_eq_42;
    wire signal_not_6;
    wire signal_eq_43;
    wire signal_and_42;
    wire [2:0] signal_const_69;
    wire signal_eq_44;
    wire signal_and_43;
    wire signal_not_7;
    wire [2:0] signal_const_73;
    wire signal_eq_45;
    wire [7:0] signal_mux_23;
    wire [7:0] signal_sub_1;
    wire signal_eq_46;
    wire [7:0] signal_mux_24;
    wire [7:0] signal_mux_25;
    wire [6:0] signal_select_6;
    wire [7:0] signal_cat_5;
    wire [6:0] signal_select_7;
    wire [7:0] signal_cat_6;
    wire [7:0] signal_mux_26;
    wire [7:0] signal_mux_27;
    wire [7:0] signal_mux_28;
    wire [7:0] signal_mux_29;
    wire [7:0] signal_mux_30;
    wire [7:0] signal_mux_31;
    wire [7:0] signal_mux_32;
    wire [7:0] signal_mux_33;
    wire [7:0] signal_wire_7;
    reg [7:0] signal_reg_35;
    wire signal_eq_47;
    wire signal_not_8;
    wire signal_eq_48;
    wire signal_and_44;
    wire [2:0] signal_const_78;
    wire signal_eq_49;
    wire [2:0] signal_select_8;
    wire signal_eq_50;
    wire signal_or_1;
    wire signal_or_2;
    wire signal_or_3;
    wire signal_or_4;
    wire [4:0] signal_mux_34;
    wire [4:0] signal_add_2;
    wire [7:0] signal_select_9;
    wire signal_select_10;
    wire [7:0] signal_const_81;
    wire [7:0] signal_and_45;
    wire signal_select_11;
    wire signal_eq_51;
    wire [4:0] signal_mux_35;
    wire [4:0] signal_add_3;
    wire [4:0] signal_add_4;
    wire [4:0] signal_add_5;
    wire [4:0] signal_add_6;
    wire signal_eq_52;
    wire [4:0] signal_mux_36;
    wire signal_eq_53;
    wire [4:0] signal_mux_37;
    wire signal_eq_54;
    wire [4:0] signal_mux_38;
    wire signal_eq_55;
    wire [4:0] signal_mux_39;
    wire signal_eq_56;
    wire [4:0] signal_mux_40;
    wire signal_eq_57;
    wire [4:0] signal_mux_41;
    wire [2:0] signal_select_12;
    wire signal_eq_58;
    wire [4:0] signal_mux_42;
    wire [4:0] signal_mux_43;
    wire [4:0] signal_mux_44;
    wire [4:0] signal_wire_8;
    reg [4:0] signal_reg_36;
    reg [7:0] signal_cases_2;
    wire [7:0] signal_mux_45;
    wire [7:0] signal_wire_9;
    reg [7:0] signal_reg_37;
    wire [4:0] signal_select_13;
    wire [4:0] signal_mux_46;
    reg [15:0] signal_mux_47;
    wire [2:0] signal_select_14;
    wire signal_eq_59;
    wire signal_wire_10;
    wire signal_not_9;
    wire signal_and_46;
    wire signal_and_47;
    wire signal_and_48;
    wire signal_mux_48;
    wire signal_mux_49;
    wire signal_eq_60;
    wire signal_eq_61;
    wire signal_eq_62;
    wire [7:0] signal_wire_11;
    wire signal_not_10;
    wire signal_wire_12;
    wire [2:0] signal_add_7;
    wire signal_eq_63;
    wire [2:0] signal_mux_50;
    wire [2:0] signal_mux_51;
    wire [2:0] signal_wire_13;
    reg [2:0] signal_reg_38;
    reg [7:0] signal_cases_3;
    wire signal_and_49;
    wire [7:0] signal_mux_52;
    wire [7:0] signal_wire_14;
    reg [7:0] signal_reg_39;
    wire signal_eq_64;
    wire signal_mux_53;
    wire [7:0] signal_wire_15;
    wire signal_select_15;
    wire signal_and_50;
    wire signal_and_51;
    wire signal_wire_16;
    wire signal_not_11;
    wire signal_or_5;
    wire signal_mux_54;
    wire signal_wire_17;
    reg signal_reg_40;
    wire signal_not_12;
    wire signal_wire_18;
    wire signal_wire_19;
    wire signal_and_52;
    wire signal_and_53;
    wire signal_and_54;
    wire signal_and_55;
    wire signal_and_56;
    wire signal_mux_55;
    wire signal_wire_20;
    reg signal_reg_41;
    wire [6:0] signal_const_105;
    wire [7:0] signal_cat_7;
    wire signal_select_16;
    wire [7:0] signal_cat_8;
    assign signal_const = 8'b11111111;
    assign signal_const_1 = 8'b00000000;
    assign signal_mux = signal_or ? signal_const : signal_const_1;
    assign signal_select = signal_reg[15:8];
    assign signal_const_2 = 16'b0000000000000000;
    assign signal_const_4 = 8'b00100000;
    assign signal_lt = signal_reg_37 < signal_const_4;
    assign signal_and = signal_and_52 & signal_not_12;
    assign signal_and_1 = signal_and & signal_lt;
    assign signal_mux_1 = signal_and_1 ? signal_mux_47 : signal_const_2;
    assign signal_wire = signal_mux_1;
    assign signal_const_5 = 15'b000000000000000;
    assign signal_cat = { signal_const_5,
                          signal_select_16 };
    assign signal_cat_1 = { signal_const_1,
                            signal_reg_34 };
    assign signal_cat_2 = { signal_const_1,
                            signal_reg_35 };
    assign signal_const_8 = 11'b00000000000;
    assign signal_cat_3 = { signal_const_8,
                            signal_reg_36 };
    always @* begin
        case (signal_reg_37)
        0:
            signal_mux_2 <= signal_cat_3;
        1:
            signal_mux_2 <= signal_cat_2;
        2:
            signal_mux_2 <= signal_cat_1;
        default:
            signal_mux_2 <= signal_cat;
        endcase
    end
    assign signal_eq = signal_reg_39 == signal_const_4;
    assign signal_mux_3 = signal_eq ? signal_mux_2 : signal_const_2;
    assign signal_const_11 = 8'b00010001;
    assign signal_eq_1 = signal_reg_39 == signal_const_11;
    assign signal_mux_4 = signal_eq_1 ? signal_wire : signal_mux_3;
    always @* begin
        case (signal_reg_38)
        3'b011:
            signal_cases <= signal_mux_4;
        default:
            signal_cases <= signal_reg;
        endcase
    end
    assign signal_mux_5 = signal_and_49 ? signal_cases : signal_reg;
    assign signal_wire_1 = signal_mux_5;
    always @(posedge signal_wire_12) begin
        if (signal_not_10)
            signal_reg <= signal_const_2;
        else
            signal_reg <= signal_wire_1;
    end
    assign signal_select_1 = signal_reg[7:0];
    assign signal_const_13 = 3'b100;
    assign signal_eq_2 = signal_reg_38 == signal_const_13;
    assign signal_mux_6 = signal_eq_2 ? signal_select : signal_select_1;
    assign signal_const_15 = 3'b101;
    assign signal_eq_3 = signal_reg_38 == signal_const_15;
    assign signal_eq_4 = signal_reg_38 == signal_const_13;
    assign signal_or = signal_eq_4 | signal_eq_3;
    assign signal_mux_7 = signal_or ? signal_mux_6 : signal_const_1;
    assign signal_select_2 = signal_select_9[0:0];
    assign signal_const_17 = 3'b000;
    assign signal_eq_5 = signal_select_8 == signal_const_17;
    assign signal_mux_8 = signal_eq_5 ? signal_select_2 : signal_reg_41;
    assign signal_select_3 = signal_reg_35[0:0];
    assign signal_mux_9 = signal_eq_54 ? signal_select_3 : signal_reg_41;
    assign signal_mux_10 = signal_eq_55 ? signal_reg_41 : signal_mux_9;
    assign signal_mux_11 = signal_eq_56 ? signal_reg_41 : signal_mux_10;
    assign signal_mux_12 = signal_eq_57 ? signal_reg_41 : signal_mux_11;
    assign signal_mux_13 = signal_eq_58 ? signal_mux_8 : signal_mux_12;
    assign signal_mux_14 = signal_and_47 ? signal_mux_13 : signal_reg_41;
    assign signal_not = ~ signal_wire_3;
    assign signal_not_1 = ~ signal_wire_16;
    assign signal_const_18 = 1'b0;
    assign signal_not_2 = ~ signal_wire_19;
    assign vdd = 1'b1;
    assign gnd = 1'b0;
    assign signal_const_19 = 3'b111;
    assign signal_const_20 = 8'b00011111;
    assign signal_eq_6 = signal_reg_37 == signal_const_20;
    assign signal_and_2 = signal_and_40 & signal_eq_6;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_1 <= signal_const_55;
        else
            if (signal_and_2)
                signal_reg_1 <= signal_wire_5;
    end
    assign signal_const_21 = 8'b00011110;
    assign signal_eq_7 = signal_reg_37 == signal_const_21;
    assign signal_and_3 = signal_and_40 & signal_eq_7;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_2 <= signal_const_55;
        else
            if (signal_and_3)
                signal_reg_2 <= signal_wire_5;
    end
    assign signal_const_22 = 8'b00011101;
    assign signal_eq_8 = signal_reg_37 == signal_const_22;
    assign signal_and_4 = signal_and_40 & signal_eq_8;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_3 <= signal_const_55;
        else
            if (signal_and_4)
                signal_reg_3 <= signal_wire_5;
    end
    assign signal_const_23 = 8'b00011100;
    assign signal_eq_9 = signal_reg_37 == signal_const_23;
    assign signal_and_5 = signal_and_40 & signal_eq_9;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_4 <= signal_const_55;
        else
            if (signal_and_5)
                signal_reg_4 <= signal_wire_5;
    end
    assign signal_const_24 = 8'b00011011;
    assign signal_eq_10 = signal_reg_37 == signal_const_24;
    assign signal_and_6 = signal_and_40 & signal_eq_10;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_5 <= signal_const_55;
        else
            if (signal_and_6)
                signal_reg_5 <= signal_wire_5;
    end
    assign signal_const_25 = 8'b00011010;
    assign signal_eq_11 = signal_reg_37 == signal_const_25;
    assign signal_and_7 = signal_and_40 & signal_eq_11;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_6 <= signal_const_55;
        else
            if (signal_and_7)
                signal_reg_6 <= signal_wire_5;
    end
    assign signal_const_26 = 8'b00011001;
    assign signal_eq_12 = signal_reg_37 == signal_const_26;
    assign signal_and_8 = signal_and_40 & signal_eq_12;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_7 <= signal_const_55;
        else
            if (signal_and_8)
                signal_reg_7 <= signal_wire_5;
    end
    assign signal_const_27 = 8'b00011000;
    assign signal_eq_13 = signal_reg_37 == signal_const_27;
    assign signal_and_9 = signal_and_40 & signal_eq_13;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_8 <= signal_const_55;
        else
            if (signal_and_9)
                signal_reg_8 <= signal_wire_5;
    end
    assign signal_const_28 = 8'b00010111;
    assign signal_eq_14 = signal_reg_37 == signal_const_28;
    assign signal_and_10 = signal_and_40 & signal_eq_14;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_9 <= signal_const_55;
        else
            if (signal_and_10)
                signal_reg_9 <= signal_wire_5;
    end
    assign signal_const_29 = 8'b00010110;
    assign signal_eq_15 = signal_reg_37 == signal_const_29;
    assign signal_and_11 = signal_and_40 & signal_eq_15;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_10 <= signal_const_55;
        else
            if (signal_and_11)
                signal_reg_10 <= signal_wire_5;
    end
    assign signal_const_30 = 8'b00010101;
    assign signal_eq_16 = signal_reg_37 == signal_const_30;
    assign signal_and_12 = signal_and_40 & signal_eq_16;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_11 <= signal_const_55;
        else
            if (signal_and_12)
                signal_reg_11 <= signal_wire_5;
    end
    assign signal_const_31 = 8'b00010100;
    assign signal_eq_17 = signal_reg_37 == signal_const_31;
    assign signal_and_13 = signal_and_40 & signal_eq_17;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_12 <= signal_const_55;
        else
            if (signal_and_13)
                signal_reg_12 <= signal_wire_5;
    end
    assign signal_const_32 = 8'b00010011;
    assign signal_eq_18 = signal_reg_37 == signal_const_32;
    assign signal_and_14 = signal_and_40 & signal_eq_18;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_13 <= signal_const_55;
        else
            if (signal_and_14)
                signal_reg_13 <= signal_wire_5;
    end
    assign signal_const_33 = 8'b00010010;
    assign signal_eq_19 = signal_reg_37 == signal_const_33;
    assign signal_and_15 = signal_and_40 & signal_eq_19;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_14 <= signal_const_55;
        else
            if (signal_and_15)
                signal_reg_14 <= signal_wire_5;
    end
    assign signal_eq_20 = signal_reg_37 == signal_const_11;
    assign signal_and_16 = signal_and_40 & signal_eq_20;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_15 <= signal_const_55;
        else
            if (signal_and_16)
                signal_reg_15 <= signal_wire_5;
    end
    assign signal_const_35 = 8'b00010000;
    assign signal_eq_21 = signal_reg_37 == signal_const_35;
    assign signal_and_17 = signal_and_40 & signal_eq_21;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_16 <= signal_const_55;
        else
            if (signal_and_17)
                signal_reg_16 <= signal_wire_5;
    end
    assign signal_const_36 = 8'b00001111;
    assign signal_eq_22 = signal_reg_37 == signal_const_36;
    assign signal_and_18 = signal_and_40 & signal_eq_22;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_17 <= signal_const_55;
        else
            if (signal_and_18)
                signal_reg_17 <= signal_wire_5;
    end
    assign signal_const_37 = 8'b00001110;
    assign signal_eq_23 = signal_reg_37 == signal_const_37;
    assign signal_and_19 = signal_and_40 & signal_eq_23;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_18 <= signal_const_55;
        else
            if (signal_and_19)
                signal_reg_18 <= signal_wire_5;
    end
    assign signal_const_38 = 8'b00001101;
    assign signal_eq_24 = signal_reg_37 == signal_const_38;
    assign signal_and_20 = signal_and_40 & signal_eq_24;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_19 <= signal_const_55;
        else
            if (signal_and_20)
                signal_reg_19 <= signal_wire_5;
    end
    assign signal_const_39 = 8'b00001100;
    assign signal_eq_25 = signal_reg_37 == signal_const_39;
    assign signal_and_21 = signal_and_40 & signal_eq_25;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_20 <= signal_const_55;
        else
            if (signal_and_21)
                signal_reg_20 <= signal_wire_5;
    end
    assign signal_const_40 = 8'b00001011;
    assign signal_eq_26 = signal_reg_37 == signal_const_40;
    assign signal_and_22 = signal_and_40 & signal_eq_26;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_21 <= signal_const_55;
        else
            if (signal_and_22)
                signal_reg_21 <= signal_wire_5;
    end
    assign signal_const_41 = 8'b00001010;
    assign signal_eq_27 = signal_reg_37 == signal_const_41;
    assign signal_and_23 = signal_and_40 & signal_eq_27;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_22 <= signal_const_55;
        else
            if (signal_and_23)
                signal_reg_22 <= signal_wire_5;
    end
    assign signal_const_42 = 8'b00001001;
    assign signal_eq_28 = signal_reg_37 == signal_const_42;
    assign signal_and_24 = signal_and_40 & signal_eq_28;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_23 <= signal_const_55;
        else
            if (signal_and_24)
                signal_reg_23 <= signal_wire_5;
    end
    assign signal_const_43 = 8'b00001000;
    assign signal_eq_29 = signal_reg_37 == signal_const_43;
    assign signal_and_25 = signal_and_40 & signal_eq_29;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_24 <= signal_const_55;
        else
            if (signal_and_25)
                signal_reg_24 <= signal_wire_5;
    end
    assign signal_const_44 = 8'b00000111;
    assign signal_eq_30 = signal_reg_37 == signal_const_44;
    assign signal_and_26 = signal_and_40 & signal_eq_30;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_25 <= signal_const_55;
        else
            if (signal_and_26)
                signal_reg_25 <= signal_wire_5;
    end
    assign signal_const_45 = 8'b00000110;
    assign signal_eq_31 = signal_reg_37 == signal_const_45;
    assign signal_and_27 = signal_and_40 & signal_eq_31;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_26 <= signal_const_55;
        else
            if (signal_and_27)
                signal_reg_26 <= signal_wire_5;
    end
    assign signal_const_46 = 8'b00000101;
    assign signal_eq_32 = signal_reg_37 == signal_const_46;
    assign signal_and_28 = signal_and_40 & signal_eq_32;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_27 <= signal_const_55;
        else
            if (signal_and_28)
                signal_reg_27 <= signal_wire_5;
    end
    assign signal_const_47 = 8'b00000100;
    assign signal_eq_33 = signal_reg_37 == signal_const_47;
    assign signal_and_29 = signal_and_40 & signal_eq_33;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_28 <= signal_const_55;
        else
            if (signal_and_29)
                signal_reg_28 <= signal_wire_5;
    end
    assign signal_const_48 = 8'b00000011;
    assign signal_eq_34 = signal_reg_37 == signal_const_48;
    assign signal_and_30 = signal_and_40 & signal_eq_34;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_29 <= signal_const_55;
        else
            if (signal_and_30)
                signal_reg_29 <= signal_wire_5;
    end
    assign signal_const_49 = 8'b00000010;
    assign signal_eq_35 = signal_reg_37 == signal_const_49;
    assign signal_and_31 = signal_and_40 & signal_eq_35;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_30 <= signal_const_55;
        else
            if (signal_and_31)
                signal_reg_30 <= signal_wire_5;
    end
    assign signal_const_50 = 8'b00000001;
    assign signal_eq_36 = signal_reg_37 == signal_const_50;
    assign signal_and_32 = signal_and_40 & signal_eq_36;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_31 <= signal_const_55;
        else
            if (signal_and_32)
                signal_reg_31 <= signal_wire_5;
    end
    assign signal_eq_37 = signal_reg_37 == signal_const_1;
    assign signal_lt_1 = signal_reg_37 < signal_const_4;
    assign signal_eq_38 = signal_reg_39 == signal_const_49;
    assign signal_and_33 = signal_and_50 & signal_eq_38;
    assign signal_wire_2 = signal_and_33;
    assign signal_not_3 = ~ signal_wire_2;
    assign signal_not_4 = ~ signal_wire_16;
    assign signal_eq_39 = signal_reg_39 == signal_const_35;
    assign signal_and_34 = signal_and_50 & signal_eq_39;
    assign signal_wire_3 = signal_and_34;
    assign signal_and_35 = signal_and_52 & signal_wire_3;
    assign signal_and_36 = signal_and_35 & signal_not_4;
    assign signal_and_37 = signal_and_36 & signal_not_3;
    assign signal_and_38 = signal_wire_19 & signal_not_12;
    assign signal_and_39 = signal_and_38 & signal_and_37;
    assign signal_and_40 = signal_and_39 & signal_lt_1;
    assign signal_and_41 = signal_and_40 & signal_eq_37;
    assign signal_const_55 = 16'b1110000000000000;
    assign signal_not_5 = ~ signal_wire_19;
    always @* begin
        case (signal_reg_38)
        3'b010:
            signal_cases_1 <= signal_wire_11;
        default:
            signal_cases_1 <= signal_reg_32;
        endcase
    end
    assign signal_mux_15 = signal_and_49 ? signal_cases_1 : signal_reg_32;
    assign signal_wire_4 = signal_mux_15;
    always @(posedge signal_wire_12) begin
        if (signal_not_10)
            signal_reg_32 <= signal_const_1;
        else
            signal_reg_32 <= signal_wire_4;
    end
    assign signal_cat_4 = { signal_reg_32,
                            signal_wire_11 };
    assign signal_wire_5 = signal_cat_4;
    always @(posedge signal_wire_12) begin
        if (signal_not_5)
            signal_reg_33 <= signal_const_55;
        else
            if (signal_and_41)
                signal_reg_33 <= signal_wire_5;
    end
    assign signal_const_58 = 5'b00000;
    assign signal_const_60 = 5'b00001;
    assign signal_add = signal_reg_36 + signal_const_60;
    assign signal_select_4 = signal_mux_47[9:0];
    assign signal_select_5 = signal_select_4[4:0];
    assign signal_add_1 = signal_reg_36 + signal_const_60;
    assign signal_eq_40 = signal_select_8 == signal_const_13;
    assign signal_mux_16 = signal_eq_40 ? signal_select_9 : signal_reg_34;
    assign signal_sub = signal_reg_34 - signal_const_50;
    assign signal_eq_41 = signal_select_8 == signal_const_13;
    assign signal_mux_17 = signal_eq_41 ? signal_sub : signal_reg_34;
    assign signal_mux_18 = signal_or_4 ? signal_mux_17 : signal_reg_34;
    assign signal_mux_19 = signal_eq_57 ? signal_mux_18 : signal_reg_34;
    assign signal_mux_20 = signal_eq_58 ? signal_mux_16 : signal_mux_19;
    assign signal_mux_21 = signal_and_47 ? signal_mux_20 : signal_reg_34;
    assign signal_mux_22 = signal_and_56 ? signal_const_1 : signal_mux_21;
    assign signal_wire_6 = signal_mux_22;
    always @(posedge signal_wire_12) begin
        if (signal_not_7)
            signal_reg_34 <= signal_const_1;
        else
            signal_reg_34 <= signal_wire_6;
    end
    assign signal_eq_42 = signal_reg_34 == signal_const_1;
    assign signal_not_6 = ~ signal_eq_42;
    assign signal_eq_43 = signal_select_8 == signal_const_13;
    assign signal_and_42 = signal_eq_43 & signal_not_6;
    assign signal_const_69 = 3'b011;
    assign signal_eq_44 = signal_select_8 == signal_const_69;
    assign signal_and_43 = signal_eq_44 & signal_select_11;
    assign signal_not_7 = ~ signal_wire_19;
    assign signal_const_73 = 3'b010;
    assign signal_eq_45 = signal_select_8 == signal_const_73;
    assign signal_mux_23 = signal_eq_45 ? signal_select_9 : signal_reg_35;
    assign signal_sub_1 = signal_reg_35 - signal_const_50;
    assign signal_eq_46 = signal_select_8 == signal_const_73;
    assign signal_mux_24 = signal_eq_46 ? signal_sub_1 : signal_reg_35;
    assign signal_mux_25 = signal_or_4 ? signal_mux_24 : signal_reg_35;
    assign signal_select_6 = signal_reg_35[7:1];
    assign signal_cat_5 = { signal_select_11,
                            signal_select_6 };
    assign signal_select_7 = signal_reg_35[7:1];
    assign signal_cat_6 = { signal_const_18,
                            signal_select_7 };
    assign signal_mux_26 = signal_eq_53 ? signal_and_45 : signal_reg_35;
    assign signal_mux_27 = signal_eq_54 ? signal_cat_6 : signal_mux_26;
    assign signal_mux_28 = signal_eq_55 ? signal_cat_5 : signal_mux_27;
    assign signal_mux_29 = signal_eq_56 ? signal_reg_35 : signal_mux_28;
    assign signal_mux_30 = signal_eq_57 ? signal_mux_25 : signal_mux_29;
    assign signal_mux_31 = signal_eq_58 ? signal_mux_23 : signal_mux_30;
    assign signal_mux_32 = signal_and_47 ? signal_mux_31 : signal_reg_35;
    assign signal_mux_33 = signal_and_56 ? signal_const_1 : signal_mux_32;
    assign signal_wire_7 = signal_mux_33;
    always @(posedge signal_wire_12) begin
        if (signal_not_7)
            signal_reg_35 <= signal_const_1;
        else
            signal_reg_35 <= signal_wire_7;
    end
    assign signal_eq_47 = signal_reg_35 == signal_const_1;
    assign signal_not_8 = ~ signal_eq_47;
    assign signal_eq_48 = signal_select_8 == signal_const_73;
    assign signal_and_44 = signal_eq_48 & signal_not_8;
    assign signal_const_78 = 3'b001;
    assign signal_eq_49 = signal_select_8 == signal_const_78;
    assign signal_select_8 = signal_mux_47[12:10];
    assign signal_eq_50 = signal_select_8 == signal_const_17;
    assign signal_or_1 = signal_eq_50 | signal_eq_49;
    assign signal_or_2 = signal_or_1 | signal_and_44;
    assign signal_or_3 = signal_or_2 | signal_and_43;
    assign signal_or_4 = signal_or_3 | signal_and_42;
    assign signal_mux_34 = signal_or_4 ? signal_select_5 : signal_add_1;
    assign signal_add_2 = signal_reg_36 + signal_const_60;
    assign signal_select_9 = signal_mux_47[7:0];
    assign signal_select_10 = signal_select_9[0:0];
    assign signal_const_81 = 8'b11111101;
    assign signal_and_45 = signal_wire_15 & signal_const_81;
    assign signal_select_11 = signal_and_45[0:0];
    assign signal_eq_51 = signal_select_11 == signal_select_10;
    assign signal_mux_35 = signal_eq_51 ? signal_add_2 : signal_reg_36;
    assign signal_add_3 = signal_reg_36 + signal_const_60;
    assign signal_add_4 = signal_reg_36 + signal_const_60;
    assign signal_add_5 = signal_reg_36 + signal_const_60;
    assign signal_add_6 = signal_reg_36 + signal_const_60;
    assign signal_eq_52 = signal_select_12 == signal_const_19;
    assign signal_mux_36 = signal_eq_52 ? signal_reg_36 : signal_add_6;
    assign signal_eq_53 = signal_select_12 == signal_const_15;
    assign signal_mux_37 = signal_eq_53 ? signal_add_5 : signal_mux_36;
    assign signal_eq_54 = signal_select_12 == signal_const_69;
    assign signal_mux_38 = signal_eq_54 ? signal_add_4 : signal_mux_37;
    assign signal_eq_55 = signal_select_12 == signal_const_73;
    assign signal_mux_39 = signal_eq_55 ? signal_add_3 : signal_mux_38;
    assign signal_eq_56 = signal_select_12 == signal_const_78;
    assign signal_mux_40 = signal_eq_56 ? signal_mux_35 : signal_mux_39;
    assign signal_eq_57 = signal_select_12 == signal_const_13;
    assign signal_mux_41 = signal_eq_57 ? signal_mux_34 : signal_mux_40;
    assign signal_select_12 = signal_mux_47[15:13];
    assign signal_eq_58 = signal_select_12 == signal_const_17;
    assign signal_mux_42 = signal_eq_58 ? signal_add : signal_mux_41;
    assign signal_mux_43 = signal_and_47 ? signal_mux_42 : signal_reg_36;
    assign signal_mux_44 = signal_and_56 ? signal_const_58 : signal_mux_43;
    assign signal_wire_8 = signal_mux_44;
    always @(posedge signal_wire_12) begin
        if (signal_not_7)
            signal_reg_36 <= signal_const_58;
        else
            signal_reg_36 <= signal_wire_8;
    end
    always @* begin
        case (signal_reg_38)
        3'b001:
            signal_cases_2 <= signal_wire_11;
        default:
            signal_cases_2 <= signal_reg_37;
        endcase
    end
    assign signal_mux_45 = signal_and_49 ? signal_cases_2 : signal_reg_37;
    assign signal_wire_9 = signal_mux_45;
    always @(posedge signal_wire_12) begin
        if (signal_not_10)
            signal_reg_37 <= signal_const_1;
        else
            signal_reg_37 <= signal_wire_9;
    end
    assign signal_select_13 = signal_reg_37[4:0];
    assign signal_mux_46 = signal_reg_40 ? signal_reg_36 : signal_select_13;
    always @* begin
        case (signal_mux_46)
        0:
            signal_mux_47 <= signal_reg_33;
        1:
            signal_mux_47 <= signal_reg_31;
        2:
            signal_mux_47 <= signal_reg_30;
        3:
            signal_mux_47 <= signal_reg_29;
        4:
            signal_mux_47 <= signal_reg_28;
        5:
            signal_mux_47 <= signal_reg_27;
        6:
            signal_mux_47 <= signal_reg_26;
        7:
            signal_mux_47 <= signal_reg_25;
        8:
            signal_mux_47 <= signal_reg_24;
        9:
            signal_mux_47 <= signal_reg_23;
        10:
            signal_mux_47 <= signal_reg_22;
        11:
            signal_mux_47 <= signal_reg_21;
        12:
            signal_mux_47 <= signal_reg_20;
        13:
            signal_mux_47 <= signal_reg_19;
        14:
            signal_mux_47 <= signal_reg_18;
        15:
            signal_mux_47 <= signal_reg_17;
        16:
            signal_mux_47 <= signal_reg_16;
        17:
            signal_mux_47 <= signal_reg_15;
        18:
            signal_mux_47 <= signal_reg_14;
        19:
            signal_mux_47 <= signal_reg_13;
        20:
            signal_mux_47 <= signal_reg_12;
        21:
            signal_mux_47 <= signal_reg_11;
        22:
            signal_mux_47 <= signal_reg_10;
        23:
            signal_mux_47 <= signal_reg_9;
        24:
            signal_mux_47 <= signal_reg_8;
        25:
            signal_mux_47 <= signal_reg_7;
        26:
            signal_mux_47 <= signal_reg_6;
        27:
            signal_mux_47 <= signal_reg_5;
        28:
            signal_mux_47 <= signal_reg_4;
        29:
            signal_mux_47 <= signal_reg_3;
        30:
            signal_mux_47 <= signal_reg_2;
        default:
            signal_mux_47 <= signal_reg_1;
        endcase
    end
    assign signal_select_14 = signal_mux_47[15:13];
    assign signal_eq_59 = signal_select_14 == signal_const_19;
    assign signal_wire_10 = signal_eq_59;
    assign signal_not_9 = ~ signal_wire_16;
    assign signal_and_46 = signal_and_52 & signal_reg_40;
    assign signal_and_47 = signal_and_46 & signal_not_9;
    assign signal_and_48 = signal_and_47 & signal_wire_10;
    assign signal_mux_48 = signal_and_48 ? gnd : signal_reg_40;
    assign signal_mux_49 = signal_and_56 ? vdd : signal_mux_48;
    assign signal_eq_60 = signal_reg_39 == signal_const_50;
    assign signal_eq_61 = signal_reg_38 == signal_const_69;
    assign signal_eq_62 = signal_reg_38 == signal_const_78;
    assign signal_wire_11 = uio_in;
    assign signal_not_10 = ~ signal_wire_19;
    assign signal_wire_12 = clk;
    assign signal_add_7 = signal_reg_38 + signal_const_78;
    assign signal_eq_63 = signal_reg_38 == signal_const_15;
    assign signal_mux_50 = signal_eq_63 ? signal_const_17 : signal_add_7;
    assign signal_mux_51 = signal_and_49 ? signal_mux_50 : signal_reg_38;
    assign signal_wire_13 = signal_mux_51;
    always @(posedge signal_wire_12) begin
        if (signal_not_10)
            signal_reg_38 <= signal_const_17;
        else
            signal_reg_38 <= signal_wire_13;
    end
    always @* begin
        case (signal_reg_38)
        3'b000:
            signal_cases_3 <= signal_wire_11;
        default:
            signal_cases_3 <= signal_reg_39;
        endcase
    end
    assign signal_and_49 = signal_select_15 & signal_wire_19;
    assign signal_mux_52 = signal_and_49 ? signal_cases_3 : signal_reg_39;
    assign signal_wire_14 = signal_mux_52;
    always @(posedge signal_wire_12) begin
        if (signal_not_10)
            signal_reg_39 <= signal_const_1;
        else
            signal_reg_39 <= signal_wire_14;
    end
    assign signal_eq_64 = signal_reg_39 == signal_const_35;
    assign signal_mux_53 = signal_eq_64 ? signal_eq_61 : signal_eq_62;
    assign signal_wire_15 = ui_in;
    assign signal_select_15 = signal_wire_15[1:1];
    assign signal_and_50 = signal_select_15 & signal_mux_53;
    assign signal_and_51 = signal_and_50 & signal_eq_60;
    assign signal_wire_16 = signal_and_51;
    assign signal_not_11 = ~ signal_wire_18;
    assign signal_or_5 = signal_not_11 | signal_wire_16;
    assign signal_mux_54 = signal_or_5 ? gnd : signal_mux_49;
    assign signal_wire_17 = signal_mux_54;
    always @(posedge signal_wire_12) begin
        if (signal_not_2)
            signal_reg_40 <= signal_const_18;
        else
            signal_reg_40 <= signal_wire_17;
    end
    assign signal_not_12 = ~ signal_reg_40;
    assign signal_wire_18 = ena;
    assign signal_wire_19 = rst_n;
    assign signal_and_52 = signal_wire_19 & signal_wire_18;
    assign signal_and_53 = signal_and_52 & signal_not_12;
    assign signal_and_54 = signal_and_53 & signal_not_1;
    assign signal_and_55 = signal_and_54 & signal_wire_2;
    assign signal_and_56 = signal_and_55 & signal_not;
    assign signal_mux_55 = signal_and_56 ? vdd : signal_mux_14;
    assign signal_wire_20 = signal_mux_55;
    always @(posedge signal_wire_12) begin
        if (signal_not_7)
            signal_reg_41 <= vdd;
        else
            signal_reg_41 <= signal_wire_20;
    end
    assign signal_const_105 = 7'b0000000;
    assign signal_cat_7 = { signal_const_105,
                            signal_reg_41 };
    assign signal_select_16 = signal_cat_7[0:0];
    assign signal_cat_8 = { signal_const_105,
                            signal_select_16 };
    assign uo_out = signal_cat_8;
    assign uio_out = signal_mux_7;
    assign uio_oe = signal_mux;

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
    silverfox_host_bridge
        silverfox_host_bridge
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

