`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/07/2023 02:20:15 PM
// Design Name: 
// Module Name: hazard_detection_Unit
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


module hazard_detection_Unit(
    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] de_ex_regRd,
    input de_ex_memRead,
    output logic de_write,
    output logic PC_write,
    output logic loadUse
    );
    
    always_comb begin
    if (de_ex_memRead
        && (de_ex_regRd == rs1)
        || (de_ex_regRd == rs2))
            loadUse = 1;
    else
        loadUse = 0;
            
    end
    
endmodule
