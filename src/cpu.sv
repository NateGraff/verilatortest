
`define PC_DIN_OP  1'b0
`define PC_DIN_RAM 1'b1

`define RAM_ADDR_PC  2'b00
`define RAM_ADDR_SP  2'b01
`define RAM_ADDR_RF  2'b10
`define RAM_ADDR_ROM 2'b11

`define RAM_DIN_RF  2'b00
`define RAM_DIN_PC  2'b01
`define RAM_DIN_ROM 2'b10
`define RAM_DIN_SP  2'b11

`define RF_DIN_B    3'b000
`define RF_DIN_ALU  3'b001
`define RF_DIN_LOW  3'b010
`define RF_DIN_HIGH 3'b011
`define RF_DIN_RAM  3'b100
`define RF_DIN_IN   3'b101
`define RF_DIN_SP   3'b110
`define RF_DIN_ZERO 3'b111

`define SP_DIN_OP  1'b0
`define SP_DIN_RF 1'b1

module cpu(
	input wire clk,
	input wire rst_n,
	input wire [15:0] in_port,
	output reg [15:0] out_port,
	output reg output_valid);

	wire [15:0] ram_dout;
	wire flag_c;
	wire flag_z;

	wire [2:0] alu_op;
	wire alu_c;
	wire alu_z;
	wire [15:0] alu_out;

	wire flags_load;

	wire pc_inc;
	wire pc_load;
	wire pc_sel;
	wire [9:0] pc_din;
	wire [9:0] pc_dout;

	wire [9:0] rom_addr;
	wire [15:0] rom_dout;

	wire [1:0] ram_addr_sel;
	wire [9:0] ram_addr;
	wire ram_write;
	wire [1:0] ram_din_sel;
	wire [15:0] ram_din;

	wire [2:0] rf_din_sel;
	wire [15:0] rf_din;
	wire rf_write;
	wire [15:0] rf_a;
	wire [15:0] rf_b;

	wire sp_load;
	wire sp_inc;
	wire sp_dec;
	wire sp_sel;
	wire [9:0] sp_din;
	wire [9:0] sp_dout;

	control_unit control_unit_i(
		.clk(clk),
		.rst_n(rst_n),
		.ram_dout(ram_dout),
		.flag_c(flag_c),
		.flag_z(flag_z),
		.alu_op(alu_op),
		.flags_load(flags_load),
		.pc_load(pc_load),
		.pc_sel(pc_sel),
		.pc_inc(pc_inc),
		.rom_addr(rom_addr),
		.ram_addr_sel(ram_addr_sel),
		.ram_din_sel(ram_din_sel),
		.ram_write(ram_write),
		.rf_din_sel(rf_din_sel),
		.rf_write(rf_write),
		.sp_load(sp_load),
		.sp_inc(sp_inc),
		.sp_dec(sp_dec),
		.sp_sel(sp_sel),
		.output_valid(output_valid));

	flags flags_i(
		.clk(clk),
		.rst_n(rst_n),
		.load(flags_load),
		.carry_in(alu_c),
		.zero_in(alu_z),
		.carry_out(flag_c),
		.zero_out(flag_z));

	alu alu_i(
		.op(alu_op),
		.arg_a(rf_a),
		.arg_b(rf_b),
		.out(alu_out),
		.carry(alu_c),
		.zero(alu_z));

	wire [9:0] opcode_addr;
	assign opcode_addr = opcode[10:1];

	always_comb begin
		case(pc_sel)
			`PC_DIN_OP:  pc_din = opcode_addr;
			`PC_DIN_RAM: pc_din = ram_dout[9:0];
		endcase
	end

	pc pc_i(
		.clk(clk),
		.rst_n(rst_n),
		.din(pc_din),
		.load(pc_load),
		.inc(pc_inc),
		.dout(pc_dout));

	rom rom_i(
		.addr(rom_addr),
		.dout(rom_dout));

	wire [7:0] opcode_offset_8;
	wire [4:0] opcode_offset_5;
	assign opcode_offset_8 = opcode[7:0];
	assign opcode_offset_5 = opcode[4:0];

	always_comb begin
		case(ram_addr_sel)
			`RAM_ADDR_PC:  ram_addr = pc_dout;
			`RAM_ADDR_SP:  ram_addr = sp_dout + {2'b0, opcode_offset_8};
			`RAM_ADDR_RF:  ram_addr = rf_b[9:0] + {5'b0, opcode_offset_5};
			`RAM_ADDR_ROM: ram_addr = rom_addr;
		endcase
	end

	always_comb begin
		case(ram_din_sel)
			`RAM_DIN_RF:  ram_din = rf_a;
			`RAM_DIN_PC:  ram_din = {6'b0, pc_dout};
			`RAM_DIN_ROM: ram_din = rom_dout;
			`RAM_DIN_SP:  ram_din = {6'b0, sp_dout};
		endcase
	end

	reg [15:0] opcode;
	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			opcode <= 0;
		end else begin
			opcode <= ram_dout;
		end
	end

	ram ram_i(
		.clk(clk),
		.rst_n(rst_n),
		.addr(ram_addr),
		.write(ram_write),
		.din(ram_din),
		.dout(ram_dout));

	wire [7:0] opcode_immed;
	wire [2:0] opcode_a;
	wire [2:0] opcode_b;
	assign opcode_immed = opcode[7:0];
	assign opcode_a     = opcode[10:8];
	assign opcode_b     = opcode[7:5];

	always_comb begin
		case(rf_din_sel)
			`RF_DIN_B:    rf_din = rf_b;
			`RF_DIN_ALU:  rf_din = alu_out;
			`RF_DIN_LOW:  rf_din = {8'h00, opcode_immed};
			`RF_DIN_HIGH: rf_din = {opcode_immed, 8'h00};
			`RF_DIN_RAM:  rf_din = ram_dout;
			`RF_DIN_IN:   rf_din = in_port;
			`RF_DIN_SP:   rf_din = {6'b0, sp_dout};
			`RF_DIN_ZERO: rf_din = 0;
		endcase
	end

	rf rf_i(
		.clk(clk),
		.rst_n(rst_n),
		.addr_a(opcode_a),
		.addr_b(opcode_b),
		.din(rf_din),
		.write(rf_write),
		.dout_a(rf_a),
		.dout_b(rf_b));

	always_comb begin
		case(sp_sel)
			`SP_DIN_OP: sp_din = opcode_addr;
			`SP_DIN_RF: sp_din = rf_a[9:0];
		endcase
	end

	sp sp_i(
		.clk(clk),
		.rst_n(rst_n),
		.din(sp_din),
		.load(sp_load),
		.inc(sp_inc),
		.dec(sp_dec),
		.dout(sp_dout));

endmodule