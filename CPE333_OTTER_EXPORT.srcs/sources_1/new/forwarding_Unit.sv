`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/07/2023 01:22:26 PM
// Design Name: 
// Module Name: forwarding_Unit
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


module forwarding_Unit(
    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] ex_mem_regRd,
    input [4:0] mem_wb_regRd,
    input mem_wb_regWrite,
    input ex_mem_regWrite,
    output logic [1:0] forwardA,
    output logic [1:0] forwardB
    );
    
// FORWARD A LOGIC
    always_comb begin
    // MEM Hazard - Forward A
    if (mem_wb_regWrite 
        && (mem_wb_regRd != 0) 
        && ~(ex_mem_regWrite && (ex_mem_regRd != 0) 
        && (ex_mem_regRd == rs1))
        && (mem_wb_regRd == rs1))
            begin
                forwardA = 2'b01;
            end
     // EX Hazard - Forward A
     else if (ex_mem_regWrite
        && (ex_mem_regRd != 0)
        && (ex_mem_regRd == rs1))
                begin
            forwardA = 2'b10;
                end
     // No Hazard - Forward A
     else
        begin
            forwardA = 2'b00;
        end
     end

// FORWARD B LOGIC
    always_comb begin
    // MEM Hazard - Forward B
    if (mem_wb_regWrite
        && (mem_wb_regRd != 0)
        && ~(ex_mem_regWrite && (ex_mem_regRd != 0)
        && (ex_mem_regRd == rs2))
        && (mem_wb_regRd == rs2))
            begin
                forwardB = 2'b01;
            end
    // EX Hazard - Forward B        
    else if (ex_mem_regWrite
        && (ex_mem_regRd != 0)
        && (ex_mem_regRd == rs2))
            begin
                forwardB = 2'b10;
            end
     // No Hazard - Forward B
     else
        begin
            forwardB = 2'b00;
        end
     end
    
endmodule
