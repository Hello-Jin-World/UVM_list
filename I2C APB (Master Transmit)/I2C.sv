`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/19 20:15:08
// Design Name: 
// Module Name: I2C
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


module I2C_Master (
    input  logic        PCLK,
    input  logic        PRESET,
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    inout  wire         SDA,
    output logic        SCL
);

    logic       start_bit;
    logic       Fast1_Standard0;
    logic [8:0] ccr;
    logic [7:0] wData;
    logic [7:0] addr;
    logic [7:0] rData;

    APB_Intf_i2c U_APB_Intf_i2c (
        .pclk           (PCLK),
        .preset         (PRESET),
        .paddr          (PADDR),
        .pwrite         (PWRITE),
        .psel           (PSEL),
        .penable        (PENABLE),
        .pwdata         (PWDATA),
        .prdata         (PRDATA),
        .pready         (PREADY),
        .start_bit      (start_bit),
        .Fast1_Standard0(Fast1_Standard0),
        .addr           (addr),
        .ccr            (ccr),
        .rData          (rData),
        .wData          (wData)
    );

    MASTER_ip U_MASTER_ip (
        .clk            (PCLK),
        .reset          (PRESET),
        .Fast1_Standard0(Fast1_Standard0),
        .ccr            (ccr),
        .wData          (wData),
        .addrwe         (addr),
        .start          (start_bit),
        .rData          (rData),
        .SDA            (SDA),
        .SCL            (SCL)
    );
endmodule

module APB_Intf_i2c (
    input logic       pclk,
    input logic       preset,
    input logic [3:0] paddr,
    input logic       pwrite,
    input logic       psel,
    input logic       penable,

    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,

    output logic       start_bit,
    output logic       Fast1_Standard0,
    output logic [7:0] addr,
    output logic [8:0] ccr,
    input  logic [7:0] rData,
    output logic [7:0] wData
);

    logic [31:0] STATUS, IDR, ODR, ADDR;

    assign Fast1_Standard0 = STATUS[0];
    assign ccr = STATUS[9:1];
    // assign start_bit = (paddr[3:2] == 2'b00) ? STATUS[10] : 0;
    assign start_bit = STATUS[10];
    assign IDR = {24'b0, rData};  //  When seleted READ mode, read data 8bit 
    assign wData = ODR[7:0];  //  When seleted WRITE mode, write data 8bit
    assign addr = ADDR[7:0];

    always_ff @(posedge pclk, posedge preset) begin
        if (preset) begin
            STATUS <= 0;
            ODR <= 0;
            ADDR <= 0;
        end else begin
            if (psel && pwrite && penable) begin
                case (paddr[3:2])
                    2'b00: STATUS <= pwdata;
                    2'b10: ODR <= pwdata;
                    2'b11: ADDR <= pwdata;
                    default: begin
                        STATUS <= STATUS;
                        ODR <= ODR;
                        ADDR <= ADDR;
                    end
                endcase
            end
        end
    end

    always_ff @(posedge pclk, posedge preset) begin
        if (preset) begin
            prdata <= 0;
        end else begin
            if (psel && ~pwrite && penable) begin
                case (paddr[3:2])
                    2'b00:   prdata <= STATUS;
                    2'b01:   prdata <= IDR;
                    2'b10:   prdata <= ODR;
                    2'b11:   prdata <= ADDR;
                    default: prdata <= 32'b0;
                endcase
            end
        end
    end

    //APB Ready Process
    always_ff @(posedge pclk, posedge preset) begin
        if (preset) begin
            pready <= 0;
        end else begin
            if (psel && penable) begin
                pready <= 1;
            end else begin
                pready <= 0;
            end
        end
    end

endmodule



module MASTER_ip (
    input  logic       clk,
    input  logic       reset,
    input  logic       Fast1_Standard0,
    input  logic [8:0] ccr,
    input  logic [7:0] wData,
    input  logic [7:0] addrwe,
    input  logic       start,
    output logic [7:0] rData,
    inout  wire        SDA,
    output logic       SCL
);
    logic SDA_in, SDA_out;
    logic [ 7:0] rData_reg;
    logic [11:0] half_freq;
    logic [3 : 0] state_reg, state_next;
    logic [3:0] i_reg, i_next;
    logic [10:0] counter_reg, counter_next;
    logic [$clog2(500) - 1 : 0] counter;
    logic manual_clk;
    logic SDA_out_reg, SDA_out_next;
    logic SCL_reg, SCL_next;
    logic write_reg, write_next;

    assign SDA_out = SDA_out_reg;
    assign SCL = SCL_reg;
    assign half_freq = (Fast1_Standard0) ? ccr * 5 : 500;
    assign rData = rData_reg;

    /////////////////       inout mode       ///////////////////
    assign SDA = write_reg ? SDA_out : 1'bz;

    always @(*) begin  // Read Data (INPUT MODE)
        if (!write_reg) begin
            SDA_in <= SDA;
        end
    end
    ///////////////////////////////////////////////////////////

    localparam LOW = 0, HIGH = 1, ACK = 0;
    localparam READ = 0, WRITE = 1;
    localparam 
    IDLE   = 0,
    STAY_4us = 1,
    ADDR_RW0 = 2,
    ADDR_RW1 = 3,
    SLAVE_ACK = 4,
    WRITE_DATA0 = 5,
    WRITE_DATA1 = 6,
    MASTER_ACK = 7,
    READ_DATA0 = 8,
    READ_DATA1 = 9,
    WAIT = 10
    ;

    ///////////////////      clock generator      ////////////////////
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            manual_clk <= 0;
            counter    <= 0;
        end else begin
            if (counter == half_freq - 1) begin
                manual_clk <= 1;
                counter    <= 0;
            end else begin
                manual_clk <= 0;
                counter <= counter + 1;
            end
        end
    end
    /////////////////////////////////////////////////////////////////


    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state_reg   <= 0;
            counter_reg <= 0;
            SDA_out_reg <= HIGH;
            SCL_reg     <= HIGH;
            i_reg       <= 0;
            write_reg   <= WRITE;
            rData_reg   <= 0;
        end else begin
            state_reg   <= state_next;
            counter_reg <= counter_next;
            SDA_out_reg <= SDA_out_next;
            SCL_reg     <= SCL_next;
            i_reg       <= i_next;
            write_reg   <= write_next;
        end
    end

    always_comb begin
        state_next   = state_reg;
        SDA_out_next = SDA_out_reg;
        SCL_next     = SCL_reg;
        i_next       = i_reg;
        counter_next = counter_reg;
        write_next   = write_reg;
        case (state_reg)
    /////////////////////////////////////////////////////////////////
            IDLE: begin
                if (counter == half_freq / 2 - 1) begin
                    SDA_out_next = HIGH;
                    SCL_next = HIGH;
                end
                if (counter == half_freq / 2 - 1 && start) begin
                    state_next   = STAY_4us;
                    counter_next = 0;
                    SDA_out_next = LOW;
                end
            end
            STAY_4us: begin
                //stay SDA_out LOW for 4us
                if (counter_reg == 500 - 1) begin
                    state_next   = ADDR_RW0;
                    counter_next = 0;
                    SCL_next     = LOW;
                end else begin
                    counter_next = counter_reg + 1;
                end
            end
            ADDR_RW0: begin
                // SCL = LOW
                if (counter == half_freq / 2 - 1) begin
                    SCL_next = ~SCL_reg;
                    i_next   = i_reg + 1;
                end
                if (manual_clk) begin
                    if (i_reg == 8) begin
                        state_next = SLAVE_ACK;
                        write_next = READ;
                        i_next     = 0;
                    end else begin
                        state_next   = ADDR_RW1;
                        SDA_out_next = addrwe[7-i_reg];
                    end
                end
            end
            ADDR_RW1: begin
                // SCL = HIGH
                if (counter == half_freq / 2 - 1) begin
                    SCL_next = ~SCL_reg;
                end
                if (manual_clk) begin
                    state_next = ADDR_RW0;
                end
            end
            SLAVE_ACK: begin
                // wait SLAVE ACK
                if (counter == half_freq / 2 - 1) begin
                    SCL_next = ~SCL_reg;
                end
                if (SCL_reg == 1 && SCL_next == 0) begin
                    if (SDA_in == ACK) begin
                        if (addrwe[0] == WRITE) begin
                            state_next = WRITE_DATA0;
                            write_next = WRITE;
                        end else begin
                            state_next = READ_DATA0;
                            write_next = READ;
                        end
                    end else begin
                        state_next = IDLE;
                        write_next = WRITE;
                    end
                end
            end
            WRITE_DATA0: begin
                // SCL = LOW
                if (counter == half_freq / 2 - 1) begin
                    SCL_next = ~SCL_reg;
                    i_next   = i_reg + 1;
                end
                if (manual_clk) begin
                    if (i_reg == 8) begin
                        SDA_out_next = LOW;
                        state_next   = MASTER_ACK;
                        i_next       = 0;
                    end else begin
                        state_next   = WRITE_DATA1;
                        SDA_out_next = wData[7-i_reg];
                    end
                end
            end
            WRITE_DATA1: begin
                // SCL = HIGH
                if (counter == half_freq / 2 - 1) begin
                    SCL_next = ~SCL_reg;
                end
                if (manual_clk) begin
                    state_next = WRITE_DATA0;
                end
            end
            READ_DATA0: begin
                if (counter == half_freq / 2 - 1) begin
                    SCL_next = ~SCL_reg;
                    i_next   = i_reg + 1;
                end
                if (manual_clk) begin
                    if (i_reg == 8) begin
                        i_next     = 0;
                        state_next = MASTER_ACK;
                    end else begin
                        state_next         = READ_DATA1;
                        rData_reg[7-i_reg] = SDA_in;
                    end
                end
            end
            READ_DATA1: begin
                if (counter == half_freq / 2 - 1) begin
                    SCL_next = ~SCL_reg;
                end
                if (manual_clk) begin
                    state_next = READ_DATA0;
                end
            end
            MASTER_ACK: begin
                SDA_out_next = LOW;
                if (counter == half_freq / 2 - 1) begin
                    SCL_next = ~SCL_reg;
                end
                if (manual_clk) begin
                    state_next = WAIT;
                end
            end
            WAIT: begin
                SDA_out_next = HIGH;
                SCL_next = HIGH;
                if (manual_clk) begin
                    state_next = IDLE;
                end
            end
        endcase
    end
endmodule

module edge_detector (
    input  logic clk,
    input  logic reset,
    input  logic manual_clk,
    output logic pEdge,
    output logic nEdge
);
    reg ff_cur, ff_past;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            ff_cur  <= 0;
            ff_past <= 0;
        end else begin
            ff_cur  <= manual_clk;
            ff_past <= ff_cur;
        end
    end

    assign pEdge = (ff_cur == 1 && ff_past == 0) ? 1 : 0;  // detect rising edge
    assign nEdge = (ff_cur == 0 && ff_past == 1) ? 1 : 0; // detect falling edge
endmodule

module manual_clk (
    input  logic clk,
    input  logic reset,
    output logic manual_clk
);

    reg [$clog2(100_000_000) - 1 : 0] counter;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            manual_clk <= 0;
            counter    <= 0;
        end else begin
            if (counter == 100_000_000 - 1) begin
                manual_clk <= 1;
                counter    <= 0;
            end else begin
                manual_clk <= 0;
                counter <= counter + 1;
            end
        end
    end

endmodule
