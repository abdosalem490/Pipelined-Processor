`include "../utils/mem.v"

/*this is the memory stage which includes anything related to the data memory like SP, store load also anything related to PORTs(I/O)*/
module MEM(Rdst2_val_out, Rdst2_out, reghigh_write_out, reglow_write_out, Rdst1_out, Rdst1_val_out, Data_out, memToReg_out, POP_PC_addr_out, POP_PC_sgn_out,
			POP_flags_val_out, POP_flags_sgn_out, stall_out, PC_in, SP_src_in, port_write_in, port_read_in, Rdst1_val_in, Rdst1_in, mem_write_in, mem_read_in, reglow_write_in,
			reghigh_write_in, Rdst2_in, mem_type_in, memToReg_in, Rdst2_val_in, PORT_in, Rsrc_in, Rsrc_val_in, mem_data_src_in, mem_addr_src_in, Rdst_val_in,
			INT_in, PC_push_pop_in, flags_push_pop_in, reset, clk);


/*this is the address of PC when POP PC*/
output wire [31:0] POP_PC_addr_out;

/*this is the signal that tells PC to change its value to the popped value*/
output wire POP_PC_sgn_out;

/*this is the flags popped out when there is POP flags*/
output wire [2:0] POP_flags_val_out;

/*this is the signal to pop the flags and change the value of flags*/
output wire POP_flags_sgn_out;

/*stalling the previous stages if there is POP PC or PUSH PC*/
output wire stall_out; 

/*this is the reset signal that zero out the content of data memory, port and so on..*/
input wire reset;

/*this is the clk that derives the registers*/
input wire clk;

/**************************************************************
	value read from the EX_MEM buffer
	(refer to EX_MEM.v to know what each symbol means) 
	(don't forget to have a look at the design files)
**************************************************************/
input wire [15:0] Rdst1_val_in;
input wire [15:0] Rdst2_val_in;
input wire [31:0] PC_in;
input wire [1:0] SP_src_in;
input wire port_write_in;
input wire port_read_in;
input wire [2:0] Rdst1_in;
input wire mem_write_in; 
input wire mem_read_in;
input wire reglow_write_in;
input wire reghigh_write_in;
input wire [2:0] Rdst2_in;
input wire mem_type_in;
input wire memToReg_in;
input wire [3:0] PORT_in;
input wire [2:0] Rsrc_in;
input wire [15:0] Rsrc_val_in;
input wire mem_data_src_in;
input wire mem_addr_src_in;
input wire [15:0] Rdst_val_in;
input wire INT_in;
input wire PC_push_pop_in;
input wire flags_push_pop_in;

/**************************************************************
	value bypassed from the EX_MEM buffer
	(refer to EX_MEM.v to know what each symbol means) 
	(don't forget to have a look at the design files)
**************************************************************/
output wire [15:0] Rdst2_val_out;
output wire [2:0] Rdst2_out;
output wire reghigh_write_out;
output wire reglow_write_out;
output wire [2:0] Rdst1_out;
output wire [15:0] Rdst1_val_out;
output wire [15:0] Data_out;
output wire memToReg_out;

/**************************************************************
	intermediate wires for cleaner code
**************************************************************/

/*wires for the stack pointer*/
wire [31:0] SP_in;
wire [31:0] SP_out;
wire [31:0] SP_selectedVal;
wire [1:0] SP_selector;

/*wires for the data memory*/
wire [15:0] data_mem_out;
wire [15:0] data_mem_in;
wire [31:0] data_mem_addr;

/*wires for the port read memory*/
wire [15:0] port_read_data;

/*wires for the port write memory*/ 
wire [15:0] port_read_data_dummy;

/*wires needed for the temp reg*/
wire [15:0] tempReg_out;

/*wires needed for the state reg that's used to wait for 2 cycles*/
wire stateReg_in;
wire stateReg_out;

/*this is actually the stack pointer register*/
reg [31:0] SP;

/**************************************************************
	important assigns for intermediate wires
**************************************************************/
assign SP_in = (reset) ? 32'd2047 : SP_selectedVal;
assign SP_selector = (INT_in) ? 2'd1 : SP_src_in;
assign SP_out = SP;

assign SP_selectedVal = 	(SP_selector == 2'd0)	?	SP_out		:
							(SP_selector == 2'd1)	?	SP_out-1	:
							(SP_selector == 2'd2)	?	SP_out+1	:							
														SP_out		;

assign data_mem_addr = (mem_addr_src_in) ?	SP_out	:	{{16{1'b0}}, Rsrc_val_in};		// TO BE EDITED
assign data_mem_in = (!mem_data_src_in)	 ?	Rdst_val_in	:
					 (stall_out)	?	PC_in[15:0]	: PC_in[31:16];						// TO BE EDITED	
														
														

/**************************************************************
	creating needed modules
**************************************************************/
memory #(4096) data_memort(.data_out(data_mem_out), .reset(reset), .address(data_mem_addr), .data_in(data_mem_in), .mem_read(mem_read_in), .mem_write(mem_write_in), .clk(clk));
memory #(16) port_out_memory(.data_out(port_read_data), .reset(reset), .address({{28{1'b0}}, PORT_in}), .data_in(16'd0), .mem_read(port_read_in), .mem_write(1'b0), .clk(clk));
memory #(16) port_in_memory(.data_out(port_read_data_dummy), .reset(reset), .address({{28{1'b0}}, PORT_in}), .data_in(Rdst_val_in), .mem_read(1'b0), .mem_write(port_write_in), .clk(clk));
	
Reg #(16) tempReg(.out_data(tempReg_out), .reset(reset), .set(1'b0), .clk(stall_out), .in_data(data_mem_out));	
Reg #(1) stateReg(.out_data(stateReg_out), .reset(reset), .set(1'b0), .clk(clk), .in_data(stateReg_in));	

/**************************************************************
	actual logic of SP
**************************************************************/
always @(posedge clk)
begin
	SP = SP_in;
end

/**************************************************************
	the logic of stalling for 1 cycle for commands pop,push PC
**************************************************************/
assign stateReg_in = PC_push_pop_in & (!stateReg_out);


/**************************************************************
	assigning values to the output
**************************************************************/
assign stall_out = PC_push_pop_in & stateReg_out;
assign POP_PC_sgn_out = mem_read_in & PC_push_pop_in & (!stateReg_out);
assign Data_out = (mem_type_in) ? data_mem_out : port_read_data;
assign POP_flags_sgn_out = stall_out & flags_push_pop_in;
assign POP_flags_val_out = data_mem_out[15:12];
assign Rdst2_val_out = Rdst2_val_in;
assign Rdst2_out = Rdst2_in;
assign reghigh_write_out = reghigh_write_in;
assign reglow_write_out = reglow_write_in;
assign Rdst1_out = Rdst1_in;
assign Rdst1_val_out = Rdst1_val_in;
assign memToReg_out = memToReg_in;
assign POP_PC_addr_out = {tempReg_out, data_mem_out};


endmodule