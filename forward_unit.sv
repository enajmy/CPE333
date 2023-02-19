`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/07/2023 01:10:14 PM
// Design Name: 
// Module Name: forward_unit
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


module Forwarding_Unit(
    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] ex_mem_regRd,
    input [4:0] mem_wb_regRd,
    input ex_mem_regWrite,
    input mem_wb_regWrite,
    output logic [1:0] forwardA,
    output logic [1:0] forwardB
    );
    
    
    
    always_comb begin
        
    // Forward A logic
        // EX hazard - Forward A
        if (ex_mem_regWrite
            && (ex_mem_regRd != 0)
            && (ex_mem_regRd == rs1))
        begin
            forwardA = 2'b10;
        end
        
        // MEM hazard - Forward A
        else if (mem_wb_regWrite
            && (mem_wb_regRd != 0) 
            && ~(ex_mem_regWrite && (ex_mem_regRd != 0) 
            && (ex_mem_regRd == rs1)) 
            && (mem_wb_regRd == rs1))
        begin
            forwardA = 2'b01;
        end
        
        else begin
            forwardA = 2'b00;
        end
        
        
    // Forward B logic
        // EX hazard - Forward B
        if (ex_mem_regWrite
            && (ex_mem_regRd != 0)
            && (ex_mem_regRd == rs2))
        begin
            forwardB = 2'b10;
        end
        
        // MEM hazard - Forward B
        else if (mem_wb_regWrite 
            && (mem_wb_regRd != 0) 
            && ~(ex_mem_regWrite && (ex_mem_regRd != 0) 
            && (ex_mem_regRd == rs2)) 
            && (mem_wb_regRd == rs2))
        begin
            forwardB = 2'b01;
        end
        
        else begin
            forwardB = 2'b00;
        end 
         
    end
    
endmodule
