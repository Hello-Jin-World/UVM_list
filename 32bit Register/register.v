`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.12.2024 11:39:05
// Design Name: 
// Module Name: register
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


module register (
    input         clk,
    input         resetn,
    input         en,
    input  [31:0] d,
    output [31:0] q
);

    reg [31:0] q_reg;
    assign q = q_reg;

    always @(posedge clk, negedge resetn) begin
        if (!resetn) begin
            q_reg <= 0;
        end else begin
            if (en) begin
                q_reg <= d;
            end
        end
    end
endmodule
