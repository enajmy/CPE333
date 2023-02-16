`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:  J. Callenes
// 
// Create Date: 01/04/2019 04:32:12 PM
// Design Name: 
// Module Name: PIPELINED_OTTER_CPU
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

typedef enum logic [6:0] {
            LUI      = 7'b0110111,
            AUIPC    = 7'b0010111,
            JAL      = 7'b1101111,
            JALR     = 7'b1100111,
            BRANCH   = 7'b1100011,
            LOAD     = 7'b0000011,
            STORE    = 7'b0100011,
            OP_IMM   = 7'b0010011,
            OP       = 7'b0110011,
            SYSTEM   = 7'b1110011,
            NOP      = 7'b0000000
} opcode_t;
        
typedef enum logic [2:0] {
            Func3_CSRRW  = 3'b001,
            Func3_CSRRS  = 3'b010,
            Func3_CSRRC  = 3'b011,
            Func3_CSRRWI = 3'b101,
            Func3_CSRRSI = 3'b110,
            Func3_CSRRCI = 3'b111,
            Func3_PRIV   = 3'b000       //mret
} funct3_system_t;        
        
typedef struct packed{
            opcode_t opcode;
            logic [4:0] rs1_addr;
            logic [4:0] rs2_addr;
            logic [4:0] rd_addr;
            logic rs1_used;
            logic rs2_used;
            logic rd_used;
            logic [3:0] alu_fun;
            logic memWrite;
            logic memRead2;
            logic regWrite;
            logic [1:0] rf_wr_sel;
            logic [2:0] mem_type;  //sign, size
            logic [31:0] pc;
            logic [6:0] func7;
            logic [31:0] ir;
} instr_t;

module OTTER_MCU(input CLK,
                input INTR,
                input RESET,
                input [31:0] IOBUS_IN,
                output [31:0] IOBUS_OUT,
                output [31:0] IOBUS_ADDR,
                output logic IOBUS_WR 
);           
    wire [6:0] opcode;
    wire [31:0] pc, pc_value, next_pc, jalr_pc, branch_pc, jump_pc, int_pc, A, B,
        I_immed, S_immed, U_immed, aluBin, aluAin, aluResult, rfIn, csr_reg, mem_data;
    
    wire [31:0] IR;
    wire memRead2;
    
    wire regWrite,memWrite, op1_sel,mem_op,IorD,pcWriteCond,memRead;
    wire [1:0] opB_sel, rf_sel, wb_sel, mSize;
    wire opA_sel;
    
    logic [1:0] pc_sel;
    logic br_lt,br_eq,br_ltu;
    logic loadUse = 0;
              
//==== Instruction Fetch ===========================================
    logic [31:0] if_de_pc;
    assign next_pc = pc + 4;
    assign de_inst.pc = if_de_pc;
    
    // Hazard Detection - holding fetch instructions
    logic pcWrite;
    logic memRead1;
    always_comb begin
        if (~loadUse)
            begin
                pcWrite = 1'b1;
                memRead1 = 1'b1;
            end
        else
            begin
                pcWrite = 1'b0;
                memRead1 = 1'b0;
            end
    end
        
    // PC Data Select Mux
    Mult4to1 PCdatasrc (next_pc, 
                        jalr_pc, 
                        branch_pc, 
                        jump_pc, 
                        pc_sel, 
                        pc_value);
     
    // PC Module
    ProgCount PC (.PC_CLK(CLK), 
                  .PC_RST(RESET), 
                  .PC_LD(pcWrite),
                  .PC_DIN(pc_value), 
                  .PC_COUNT(pc)); 

//==== Instruction Decode ===========================================
    instr_t de_ex_inst, de_inst;
    logic [31:0] de_ex_opA;
    logic [31:0] de_ex_opB;
    logic [31:0] de_ex_rs2;
    logic [31:0] de_ex_I_immed;
    
    assign opcode = IR[6:0];
    opcode_t OPCODE;
    assign OPCODE = opcode_t'(opcode);
    
    assign de_inst.ir = IR;
    assign de_inst.rs1_addr = IR[19:15];
    assign de_inst.rs2_addr = IR[24:20];
    assign de_inst.rd_addr = IR[11:7];
    assign de_inst.mem_type = IR[14:12];
    assign de_inst.func7 = IR[31:25];
    assign de_inst.opcode = OPCODE;
    
    assign de_inst.rs1_used = de_inst.rs1_addr != 0
                              && de_inst.opcode != LUI
                              && de_inst.opcode != AUIPC
                              && de_inst.opcode != JAL;
                                
    assign de_inst.regWrite = (~loadUse && ((de_inst.opcode != STORE) && (de_inst.opcode != BRANCH)));
    assign de_inst.memWrite = (~loadUse && (de_inst.opcode == STORE));
    assign de_inst.memRead2 = (~loadUse && (de_inst.opcode == LOAD));
    
    // Immediate Generator
    assign S_immed = {{20{de_inst.ir[31]}},de_inst.ir[31:25],de_inst.ir[11:7]};
    assign I_immed = {{20{de_inst.ir[31]}},de_inst.ir[31:20]};
    assign U_immed = {de_inst.ir[31:12],{12{1'b0}}};
    
    // Register Module
    OTTER_registerFile RF (de_inst.rs1_addr, 
                           de_inst.rs2_addr, 
                           mem_wb_inst.rd_addr, 
                           rfIn, 
                           mem_wb_inst.regWrite, 
                           A, 
                           B, 
                           CLK);
    
    // Reg --> ALU B Mux
    Mult4to1 ALUBinput (B, 
                        I_immed, 
                        S_immed, 
                        de_inst.pc, 
                        opB_sel, 
                        aluBin);
    
    // Reg --> ALU A Mux
    Mult2to1 ALUAinput (A, 
                        U_immed, 
                        opA_sel, 
                        aluAin);
	
	// Decoder Module
    OTTER_CU_Decoder CU_DECODER(.CU_OPCODE(de_inst.opcode), 
                                .CU_FUNC3(de_inst.mem_type),
                                .CU_FUNC7(de_inst.func7), 
                                .CU_BR_EQ(br_eq),
                                .CU_BR_LT(br_lt),
                                .CU_BR_LTU(br_ltu),
                                .CU_ALU_SRCA(opA_sel),
                                .CU_ALU_SRCB(opB_sel),
                                .CU_ALU_FUN(de_inst.alu_fun),
                                .CU_RF_WR_SEL(de_inst.rf_wr_sel),
                                .intTaken(intTaken));
    
    // Hazard Detection
    logic [1:0] count = 0;
    
    // Branch/Jump Hazards
    always_ff @ (posedge CLK) begin
        if (((pc_sel != 0) && (count < 2)) || (count == 1))
            begin
                de_inst.opcode = NOP;
                count++;
            end
        if ((pc_sel == 0) && (count > 0))
            begin
                count = 0;
            end
    end
        
    logic countLD = 0;    
    always_comb begin
        // Load-Use Hazards
        if (de_ex_inst.memRead2 &&
           ((de_ex_inst.rd_addr == de_inst.rs1_addr) ||
           (de_ex_inst.rd_addr == de_inst.rs2_addr)))
                begin
                    // stall the pipeline
                    loadUse = 1;
                    countLD = 1;
                end
//            else
//                begin
//                    loadUse = 0;
//                end
    end
    
    always_ff @ (posedge CLK) begin
    if ((loadUse == 1) && (countLD != 0)) begin
        loadUse = 0;
        countLD = 0;
        end
    end
               
//==== Execute ======================================================
    instr_t ex_mem_inst;
    logic [31:0] ex_mem_rs2;
    logic [31:0] ex_mem_aluRes;
    logic [31:0] opA_forwarded;
    logic [31:0] opB_forwarded;
    logic [3:0] temp_alu_fun;
    logic [1:0] forwardA;
    logic [1:0] forwardB;
    logic [31:0] forwardAin;
    logic [31:0] forwardBin;
     
    // ALU Module
    OTTER_ALU ALU (de_ex_inst.alu_fun, 
                   forwardAin,
                   forwardBin, 
                   aluResult);
                   
    assign de_inst.alu_fun = temp_alu_fun;
    
    // Forwarding Muxes       
    Mult3to1 ForwardInputA (rfIn, ex_mem_aluRes, de_ex_opA, forwardA, forwardAin);
    Mult3to1 ForwardInputB (rfIn, ex_mem_aluRes, de_ex_opB, forwardB, forwardBin);

    
    // Target Generator
    assign jalr_pc = de_ex_I_immed + forwardAin;
    assign branch_pc = de_ex_inst.pc + {{20{de_ex_inst.ir[31]}},de_ex_inst.ir[7],de_ex_inst.ir[30:25],de_ex_inst.ir[11:8],1'b0};   //byte aligned addresses
    assign jump_pc = de_ex_inst.pc + {{12{de_ex_inst.ir[31]}}, de_ex_inst.ir[19:12], de_ex_inst.ir[20],de_ex_inst.ir[30:21],1'b0};
    assign int_pc = 0;

    //Branch Condition Generator
    always_comb
        begin
            br_lt=0; br_eq=0; br_ltu=0;
            if($signed(forwardAin) < $signed(forwardBin)) br_lt=1;
            if(forwardAin==forwardBin) br_eq=1;
            if(forwardAin<forwardBin) br_ltu=1;
        end
    
    always_comb
        case(de_ex_inst.opcode)
            OP_IMM: temp_alu_fun = (de_ex_inst.mem_type==3'b101)?{de_ex_inst.func7[5],de_ex_inst.mem_type}:{1'b0,de_ex_inst.mem_type};
            LUI,SYSTEM: temp_alu_fun = 4'b1001;
            OP: temp_alu_fun = {de_ex_inst.func7[5],de_ex_inst.mem_type};
            default: temp_alu_fun = 4'b0;
        endcase
            
    logic brn_cond;     
    always_comb
        case(de_ex_inst.mem_type)
            3'b000: brn_cond = br_eq;     //BEQ 
            3'b001: brn_cond = ~br_eq;    //BNE
            3'b100: brn_cond = br_lt;     //BLT
            3'b101: brn_cond = ~br_lt;    //BGE
            3'b110: brn_cond = br_ltu;    //BLTU
            3'b111: brn_cond = ~br_ltu;   //BGEU
            default: brn_cond =0;
        endcase

    always_comb 
        begin
            case(de_ex_inst.opcode)
                JAL: pc_sel =3'b011;
                JALR: pc_sel=3'b001;
                BRANCH: pc_sel=(brn_cond)?3'b010:2'b000;
                SYSTEM: pc_sel = (de_ex_inst.mem_type==Func3_PRIV)? 3'b101:3'b000;
                default: pc_sel=3'b000; 
            endcase 
        end

//==== Memory ======================================================
    instr_t mem_wb_inst;
    logic [31:0] mem_wb_aluRes;
    logic [31:0] mem_wb_rs2;
    assign IOBUS_ADDR = ex_mem_aluRes;
    assign IOBUS_OUT = ex_mem_rs2;
    
    // Memory Module
    OTTER_mem_byte #(14) memory (.MEM_CLK(CLK),
                                 .MEM_ADDR1(pc),
                                 .MEM_ADDR2(ex_mem_aluRes),
                                 .MEM_DIN2(ex_mem_rs2),
                                 .MEM_WRITE2(ex_mem_inst.memWrite),
                                 .MEM_READ1(memRead1),
                                 .MEM_READ2(ex_mem_inst.memRead2),
                                 .ERR(),
                                 .MEM_DOUT1(IR),
                                 .MEM_DOUT2(mem_data),
                                 .IO_IN(IOBUS_IN),
                                 .IO_WR(IOBUS_WR),
                                 .MEM_SIZE(ex_mem_inst.mem_type[1:0]),
                                 .MEM_SIGN(ex_mem_inst.mem_type[2])); 
                                 
    // Handle Forwarding
    forwarding_Unit FU(
        .rs1(de_ex_inst.rs1_addr),
        .rs2(de_ex_inst.rs2_addr),
        .ex_mem_regWrite(ex_mem_inst.regWrite),
        .mem_wb_regWrite(mem_wb_inst.regWrite),
        .ex_mem_regRd(ex_mem_inst.rd_addr),
        .mem_wb_regRd(mem_wb_inst.rd_addr),
        .forwardA(forwardA),
        .forwardB(forwardB)
        );

     
//==== Write Back ==================================================
    // Register Data Select Mux
    Mult4to1 regWriteback (mem_wb_inst.pc + 4,
                           csr_reg,
                           mem_data,
                           mem_wb_aluRes,
                           mem_wb_inst.rf_wr_sel,
                           rfIn);

//==== Pipelines ====================================================                           
    always_ff @ (posedge CLK) 
        begin
            // Fetch --> Decode
            if (~loadUse) 
                begin
                    if_de_pc <= pc;
                end
        
            // Decode -> Execute
            if (~loadUse)
                begin
                    de_ex_inst <= de_inst;
                    de_ex_rs2 <= B;
                    de_ex_opB <= aluBin;
                    de_ex_opA <= aluAin;
                    de_ex_I_immed <= I_immed;
                end
                
            // Execute -> Memory
            ex_mem_inst <= de_ex_inst;
            ex_mem_aluRes <= aluResult;
            ex_mem_rs2 <= de_ex_rs2;
            
            // Memory -> Writeback
            mem_wb_inst <= ex_mem_inst;
            mem_wb_rs2 <= ex_mem_rs2;
            mem_wb_aluRes <= ex_mem_aluRes;
        end  
endmodule