`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/02 15:46:10
// Design Name: 
// Module Name: SCCB_final
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SCCB_final (
    input  logic clk,
    input  logic reset,
    output logic scl,
    inout  wire  sda
);

    logic start, done, ack_error;
    logic [7:0] reg_addr, data;

    SCCB_intf U_SCCB (
        .clk(clk),
        .reset(reset),
        .start(start),
        .reg_addr(reg_addr),
        .data(data),
        .scl(scl),
        .sda(sda),
        .done(done),
        .ack_error(ack_error)
    );

    SCCB_ControlUnit U_SCCB_CONTROLUNIT (
        .clk(clk),
        .reset(reset),
        .start(start),
        .reg_addr(reg_addr),
        .data(data),
        .done(done),
        .Mux_sel(),
        .ack_error(ack_error)
    );

endmodule

module SCCB_intf (
    input  logic       clk,
    input  logic       reset,
    input  logic       start,
    input  logic [7:0] reg_addr,
    input  logic [7:0] data,
    output logic       scl,
    inout  wire        sda,
    output logic       done,
    output logic       ack_error
);

    // 상태 정의
    logic [3:0] bit_cnt_reg, bit_cnt_next;
    logic [9:0] clk_cnt_reg, clk_cnt_next;
    logic sda_out_reg, sda_out_next;
    logic sda_en_reg, sda_en_next;
    logic [7:0] shift_reg_reg, shift_reg_next;
    logic
        scl_mode_reg,
        scl_mode_next,
        ack_error_reg,
        ack_error_next,
        ack_error_out_reg,
        ack_error_out_next,
        done_reg,
        done_next;
    logic [8:0] clk_div;
    logic clk_100k;

    // SDA 제어
    assign sda = (sda_en_reg) ? sda_out_reg : 1'bz;
    assign scl = (scl_mode_reg) ? clk_100k : 1'b1;
    assign ack_error = ack_error_out_reg;
    assign done = done_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            clk_div  <= 0;
            clk_100k <= 0;
        end else begin
            clk_div <= clk_div + 1;
            if (clk_div == 500 - 1) begin
                clk_div  <= 0;
                clk_100k <= ~clk_100k;
            end
        end
    end

    typedef enum {
        IDLE,
        START_1,
        START_1_1,
        START_2,
        TRANSFER_ID,
        WAIT_HIGH_1,
        WAIT_FINAL_1_1,
        WAIT_FINAL_1_2,
        WAIT_ACK_1,
        TRANSFER_REG,
        WAIT_HIGH_2,
        WAIT_FINAL_2_1,
        WAIT_FINAL_2_2,
        WAIT_ACK_2,
        TRANSFER_DATA,
        WAIT_HIGH_3,
        WAIT_FINAL_3_1,
        WAIT_FINAL_3_2,
        WAIT_ACK_3,
        STOP_1,
        STOP_2,
        DONE
    } state_s;
    state_s state, state_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state             <= IDLE;
            bit_cnt_reg       <= 7;
            clk_cnt_reg       <= 0;
            sda_out_reg       <= 1;
            sda_en_reg        <= 0;
            shift_reg_reg     <= 8'h42;
            scl_mode_reg      <= 0;
            ack_error_reg     <= 0;
            ack_error_out_reg <= 0;
            done_reg          <= 0;
        end else begin
            state             <= state_next;
            bit_cnt_reg       <= bit_cnt_next;
            clk_cnt_reg       <= clk_cnt_next;
            sda_out_reg       <= sda_out_next;
            sda_en_reg        <= sda_en_next;
            shift_reg_reg     <= shift_reg_next;
            scl_mode_reg      <= scl_mode_next;
            ack_error_reg     <= ack_error_next;
            ack_error_out_reg <= ack_error_out_next;
            done_reg          <= done_next;
        end
    end

    always_comb begin
        state_next         = state;
        bit_cnt_next       = bit_cnt_reg;
        clk_cnt_next       = clk_cnt_reg;
        sda_out_next       = sda_out_reg;
        sda_en_next        = sda_en_reg;
        shift_reg_next     = shift_reg_reg;
        scl_mode_next      = scl_mode_reg;
        ack_error_next     = ack_error_reg;
        ack_error_out_next = ack_error_out_reg;
        done_next          = done_reg;
        case (state)
            IDLE: begin
                bit_cnt_next       = 7;
                clk_cnt_next       = 0;
                sda_out_next       = 1;
                scl_mode_next      = 0;
                sda_en_next        = 0;
                shift_reg_next     = 8'h42;
                scl_mode_next      = 0;
                ack_error_next     = 0;
                done_next          = 0;
                ack_error_out_next = 0;
                if (start) begin
                    sda_en_next  = 1'b1;
                    sda_out_next = 1'b1;
                    state_next   = START_1;
                end
            end
            START_1: begin
                if (clk_cnt_reg == 5) begin
                    clk_cnt_next = 0;
                    sda_out_next = 1'b0;
                    state_next   = START_1_1;
                end else begin
                    clk_cnt_next = clk_cnt_reg + 1;
                end
            end
            START_1_1: begin
                if (clk_100k == 1'b1) begin
                    scl_mode_next = 1;
                    state_next = START_2;
                end
            end
            START_2: begin
                if (clk_100k == 1'b0) begin
                    scl_mode_next = 1;
                    state_next = TRANSFER_ID;
                end
            end
            TRANSFER_ID: begin
                if (clk_100k == 1'b0) begin
                    if (clk_cnt_reg == 250) begin
                        clk_cnt_next = 0;
                        sda_out_next = shift_reg_reg[bit_cnt_reg];
                        if (bit_cnt_reg == 0) begin
                            state_next = WAIT_FINAL_1_1;
                        end else begin
                            bit_cnt_next = bit_cnt_reg - 1;
                            state_next   = WAIT_HIGH_1;
                        end
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end
                end
            end
            WAIT_HIGH_1: begin
                if (clk_100k == 1'b1) state_next = TRANSFER_ID;
            end
            WAIT_FINAL_1_1: begin
                if (clk_100k == 1'b1) begin
                    state_next = WAIT_FINAL_1_2;
                end
            end
            WAIT_FINAL_1_2: begin
                if (clk_100k == 1'b0) begin
                    if (clk_cnt_reg == 250) begin
                        clk_cnt_next = 0;
                        sda_en_next  = 0;
                        state_next   = WAIT_ACK_1;
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end
                end
            end
            WAIT_ACK_1: begin
                if (clk_100k == 1'b1) begin
                    state_next = TRANSFER_REG;
                    if (sda == 1) ack_error_next = 1'b1;
                end
                bit_cnt_next   = 7;
                clk_cnt_next   = 0;
                sda_out_next   = 0;
                shift_reg_next = reg_addr;
            end
            TRANSFER_REG: begin
                if (clk_100k == 1'b0) begin
                    if (clk_cnt_reg == 250) begin
                        sda_en_next  = 1;
                        clk_cnt_next = 0;
                        sda_out_next = shift_reg_reg[bit_cnt_reg];
                        if (bit_cnt_reg == 0) begin
                            state_next = WAIT_FINAL_2_1;
                        end else begin
                            bit_cnt_next = bit_cnt_reg - 1;
                            state_next   = WAIT_HIGH_2;
                        end
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end
                end
            end
            WAIT_HIGH_2: begin
                if (clk_100k == 1'b1) state_next = TRANSFER_REG;
            end
            WAIT_FINAL_2_1: begin
                if (clk_100k == 1'b1) begin
                    state_next = WAIT_FINAL_2_2;
                end
            end
            WAIT_FINAL_2_2: begin
                if (clk_100k == 1'b0) begin
                    if (clk_cnt_reg == 250) begin
                        clk_cnt_next = 0;
                        sda_en_next  = 0;
                        state_next   = WAIT_ACK_2;
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end
                end
            end
            WAIT_ACK_2: begin
                if (clk_100k == 1'b1) begin
                    state_next = TRANSFER_DATA;
                    if (sda == 1) ack_error_next = 1'b1;
                end
                bit_cnt_next   = 7;
                clk_cnt_next   = 0;
                sda_out_next   = 0;
                shift_reg_next = data;
            end
            TRANSFER_DATA: begin
                if (clk_100k == 1'b0) begin
                    if (clk_cnt_reg == 250) begin
                        sda_en_next  = 1;
                        clk_cnt_next = 0;
                        sda_out_next = shift_reg_reg[bit_cnt_reg];
                        if (bit_cnt_reg == 0) begin
                            state_next = WAIT_FINAL_3_1;
                        end else begin
                            bit_cnt_next = bit_cnt_reg - 1;
                            state_next   = WAIT_HIGH_3;
                        end
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end
                end
            end
            WAIT_HIGH_3: begin
                if (clk_100k == 1'b1) state_next = TRANSFER_DATA;
            end
            WAIT_FINAL_3_1: begin
                if (clk_100k == 1'b1) begin
                    state_next = WAIT_FINAL_3_2;
                end
            end
            WAIT_FINAL_3_2: begin
                if (clk_100k == 1'b0) begin
                    if (clk_cnt_reg == 250) begin
                        clk_cnt_next = 0;
                        sda_en_next  = 0;
                        state_next   = WAIT_ACK_3;
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end
                end
            end
            WAIT_ACK_3: begin
                if (clk_100k == 1'b1) begin
                    state_next = STOP_1;
                    if (sda == 1) ack_error_next = 1'b1;
                end
            end
            STOP_1: begin
                if (clk_100k == 1'b0) begin
                    if (clk_cnt_reg == 250) begin
                        clk_cnt_next = 0;
                        sda_en_next  = 1;
                        sda_out_next = 0;
                        state_next   = STOP_2;
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end
                end
            end
            STOP_2: begin
                if (clk_100k == 1'b1) begin
                    if (clk_cnt_reg == 250) begin
                        clk_cnt_next = 0;
                        sda_out_next = 1'b1;
                        scl_mode_next = 0;
                        state_next = DONE;
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end

                end
            end
            DONE: begin
                if (clk_100k == 1'b0) begin
                    if (clk_cnt_reg == 10) begin
                        if (ack_error_reg == 1) begin
                            clk_cnt_next = 0;
                            done_next = 1'b0;
                            ack_error_out_next = 1'b1;
                            state_next = IDLE;
                        end else begin
                            clk_cnt_next = 0;
                            done_next = 1'b1;
                            state_next = IDLE;
                        end
                    end else begin
                        clk_cnt_next = clk_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module SCCB_ControlUnit (
    input  logic       clk,
    input  logic       reset,
    output logic       start,
    output logic [7:0] reg_addr,
    output logic [7:0] data,
    input  logic       done,
    output logic [1:0] Mux_sel,
    input  logic       ack_error
);

    localparam RESET = 0, WAIT = 1, RUN = 2, DATA = 3;

    logic [1:0] Mux_sel_reg, Mux_sel_next;
    logic [2:0] state, state_next;
    logic [7:0] reg_addr_reg, reg_addr_next;
    logic [7:0] data_reg, data_next;
    logic start_reg, start_next;
    logic [7:0] bit_cnt_reg, bit_cnt_next;

    logic [15:0] addr_dat[0:75];

    initial begin

        addr_dat[0] = 16'h12_80;  // COM7 Reset all registers to default values 
        addr_dat[1] = 16'hFF_F0;  // DELAY
        addr_dat[2] = 16'h12_14;  // COM7 QVGA Selection, RGB Select
        addr_dat[3] = 16'h11_80;  // CLK Internal Clk = inputCLK / 1 [5:0] = 0
        addr_dat[4] = 16'h0C_00;  // COM3 Default
        addr_dat[5] = 16'h3E_00;  // COM14 Default
        addr_dat[6] = 16'h04_00;  // COM1 Default
        addr_dat[7] = 16'h40_d0;  // COM15 Output Range [00] to [FF], RGB 565
        addr_dat[8]  = 16'h3a_04; // TSLB Normal Image, Use normal UV output, YUYV TSLB[3] : 0 , COM13[0] : 0 YUYV 
        addr_dat[9] = 16'h14_18;  // COM9  Gain 4x
        addr_dat[10] = 16'h4F_B3;  // MATRIX 1 Default
        addr_dat[11] = 16'h50_B3;  // MATRIX 2 Default
        addr_dat[12] = 16'h51_00;  // MATRIX 3 Default
        addr_dat[13] = 16'h52_3d;  // MATRIX 4 Default
        addr_dat[14] = 16'h53_A7;  // MATRIX 5 Default 
        addr_dat[15] = 16'h54_E4;  // MATRIX 6 Default 
        addr_dat[16] = 16'h58_9E; // MTXS AUTO CONTRAS-CENTER [11110] 0 PLUS, 1 MINUS
        addr_dat[17] = 16'h3D_C0;  // COM13 Gamma Enable, UV auto Adjestment, 0
        addr_dat[18] = 16'h17_15; // HSTART Horizontal Frame (HREF column) START HIGH 8bit : 0001_0101 : 0x14 : 168
        addr_dat[19] = 16'h18_03; // HSTOP Horizontal Frame (HREF column) END HIGH 8-bit : 0000_0010 : 02 : 24
        addr_dat[20] = 16'h32_91; // HREF Control , HREF Edge Offset : 10 , HSTOP:001, HSTART LSB 3bit : 000
        addr_dat[21] = 16'h19_03; // VSTART Vertical Frame (row) START HIGH 8-bit : 0000_0011   : 12
        addr_dat[22] = 16'h1A_7B; // VSTOP Vertical Frame (row) END HIGH 8-bit : 0111_1011  : 492
        addr_dat[23] = 16'h03_00; // VREF AGC[9:8] = 00, 11VSTART : 00, VSTOP LOW 2-bit : 10
        addr_dat[24] = 16'h0F_41; // COM6 Disable HREF at optical black, NO reset timing when format changes 
        addr_dat[25] = 16'h1E_00; // MVFP NORMAL Imange, BLACK sun disenable        
        addr_dat[26] = 16'h33_8f; // CHLF ARRY CUrrent Control 1000_1111 높일경우 픽셀 응답성 개선 but 전력소비와 노이즈 증가가
        addr_dat[27] = 16'h3C_78;  // COM12 NO HREF when VSYNC is low
        addr_dat[28] = 16'h69_00; // GFIX DEFAULT                                           
        addr_dat[29] = 16'h74_00;  // REG74 DEFAULT
        addr_dat[30] = 16'hB0_84; // RSVD DEFAULT                                           
        addr_dat[31] = 16'hB1_0c; // ABLC1 ENABLE ABLC                                              
        addr_dat[32] = 16'hB2_0e; // RSVD DEFUALT                                           
        addr_dat[33] = 16'hB3_80; // THL_ST ABLC Target Default                                     
        addr_dat[34] = 16'h70_3a; // SCALING_XSC Default                                            
        addr_dat[35] = 16'h71_35; // SCALING_YSC Defualt                                            
        addr_dat[36] = 16'h72_11; // SCALING_DCWCTR Default                                             
        addr_dat[37] = 16'h73_f0; // SCALING PCLK_DIV7  Default                                         
        addr_dat[38] = 16'ha2_02; // SCALING_PCLK_DELAY Default                                 
        addr_dat[39] = 16'h7a_20; // SLOP 0x100 - GAM15[7:0] x 4/3 = 298(10진수)                                              
        addr_dat[40] = 16'h7b_10; // GAM1. 해당 입력 끝 지점에 대해 설정된 출력 값 16                                           
        addr_dat[41] = 16'h7c_1e; // GAM2. 10진수 30                              
        addr_dat[42] = 16'h7d_35; // GAM3.                                          
        addr_dat[43] = 16'h7e_5a;  // GAM4. 
        addr_dat[44] = 16'h7f_69; // GAM5                                           
        addr_dat[45] = 16'h80_76; // GAM6                                           
        addr_dat[46] = 16'h81_80; // GAM7                                           
        addr_dat[47] = 16'h82_88; // GAM8                                           
        addr_dat[48] = 16'h83_8f; // GAM9                                           
        addr_dat[49] = 16'h84_96; // GAM10                                          
        addr_dat[50] = 16'h85_a3; // GAM11                                          
        addr_dat[51] = 16'h86_af;  // GAM12                          
        addr_dat[52] = 16'h87_c4;  // GAM13 
        addr_dat[53] = 16'h88_d7;  // GAM14  
        addr_dat[54] = 16'h89_e8;  // GAM15              
        addr_dat[55] = 16'h13_e0; // COM8 (Fast AGC/AEC 알고리즘 활성화, AEC/AGC, AWB 비활성화)
        addr_dat[56] = 16'h00_00; // GAIN. 자동 이득 조정(AGC) = 0(최소값)
        addr_dat[57] = 16'h10_60;  // AECH. exposure value(노출값)
        addr_dat[58] = 16'h0d_40;  // COM4. Average option = 1/2 window
        addr_dat[59] = 16'h14_18; // COM9. AGC 최대값은 4x, AGC/AEC는 비활성화
        addr_dat[60] = 16'ha5_05;  // BD50MAX. 50Hz Banding Step Limit = 5
        addr_dat[61] = 16'hab_07;  // BD60MAX. 60Hz Banding Step Limit = 7
        addr_dat[62] = 16'h24_95; // AEW. AGC/AEC의 안정적인 동작 영역의 상한선 = 0x95
        addr_dat[63] = 16'h25_33; // AEB. AGC/AEC의 안정적인 동작 영역의 하한선 = 0x33
        addr_dat[64] = 16'h26_e3; // VPT. AGC/AEC Fast Mode Operating Region의 상한선은 0xE로 설정되고, 하한선은 0x3
        addr_dat[65] = 16'h9f_78; // HAECC1. Histogram-based AEC/AGC control 1 활성화
        addr_dat[66] = 16'ha0_68; // HAECC2. Histogram-based AEC/AGC control 2 활성화
        addr_dat[67] = 16'ha1_03;  // RSVD Default
        addr_dat[68] = 16'ha6_d8; // HAECC3. Histogram-based AEC/AGC control 3 활성화
        addr_dat[69] = 16'ha7_d8; // HAECC4. Histogram-based AEC/AGC control 4 활성화
        addr_dat[70] = 16'ha8_f0; // HAECC5. Histogram-based AEC/AGC control 5 활성화
        addr_dat[71] = 16'ha9_90; // HAECC6. Histogram-based AEC/AGC control 6 활성화
        addr_dat[72] = 16'haa_94; // HAECC7. Histogram-based AEC 알고리즘 활성화
        addr_dat[73] = 16'h6f_9f; // HAECC7. Histogram-based AEC 알고리즘 활성화
        addr_dat[74] = 16'h13_e7; // COM8. Fast AGC/AEC 알고리즘 활성화, AEC step size 무제한, AGC 활성화, AWB 비활성화, AEC 활성화, banding filter OFF
        //addr_dat[73] = 16'h9B_80; // BRIGHT 0x20 만큼 증가가
        addr_dat[75] = 16'hFF_FF;  //

        // addr_dat[76] = 16'h40_10; // COM15 Burst Mode
        // addr_dat[77] = 16'h12_00; // VGA Mode (640x480)
        // addr_dat[82] = 16'h33_80; // 노이즈 필터 설정
        // addr_dat[83] = 16'h13_90; // 화이트 밸런스 활성화
        // addr_dat[84] = 16'h26_e3; // 빠른 픽셀 응답성 설정
        // addr_dat[85] = 16'h4f_80; // 색상 보정 행렬 1
        // addr_dat[86] = 16'h50_90; // 색상 보정 행렬 2
    end


    assign Mux_sel  = Mux_sel_reg;
    assign reg_addr = reg_addr_reg;
    assign data     = data_reg;
    assign start    = start_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= RESET;
            start_reg    <= 0;
            Mux_sel_reg  <= 0;
            reg_addr_reg <= 8'h12;
            data_reg     <= 8'h80;
            bit_cnt_reg  <= 0;
        end else begin
            state        <= state_next;
            start_reg    <= start_next;
            Mux_sel_reg  <= Mux_sel_next;
            reg_addr_reg <= reg_addr_next;
            data_reg     <= data_next;
            bit_cnt_reg  <= bit_cnt_next;
        end
    end

    always_comb begin
        state_next    = state;
        start_next    = start_reg;
        Mux_sel_next  = Mux_sel_reg;
        reg_addr_next = reg_addr_reg;
        data_next     = data_reg;
        bit_cnt_next  = bit_cnt_reg;
        case (state)
            RESET: begin
                Mux_sel_next = 2'b00;
                start_next = 1'b1;
                reg_addr_next = 8'h12;
                data_next = 8'h80;
                state_next = WAIT;
            end
            WAIT: begin
                start_next = 1'b0;
                if (done == 1) state_next = DATA;
                else if (ack_error == 1) begin
                    bit_cnt_next = bit_cnt_reg - 1;
                    state_next   = DATA;
                end
            end
            DATA: begin
                {reg_addr_next, data_next} = addr_dat[bit_cnt_reg];
                if (bit_cnt_reg == 75) begin
                    start_next = 1'b1;
                    state_next = RUN;
                end else begin
                    start_next   = 1'b1;
                    state_next   = WAIT;
                    bit_cnt_next = bit_cnt_reg + 1;
                end

            end
            RUN: begin
                start_next = 1'b0;
                if (done == 1) Mux_sel_next = 2'b01;
                else if (ack_error == 1) begin
                    bit_cnt_next = bit_cnt_reg - 1;
                    state_next   = DATA;
                end

            end
        endcase
    end
endmodule
