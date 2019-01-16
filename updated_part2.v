
module updated_part2
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
		  LEDR,
		  LEDG,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,   						//	VGA Blue[9:0]
		HEX0, 
		HEX1
	);

	input			CLOCK_50;				//	50 MHz
	input   [17:0]   SW;
	input   [3:0]   KEY;
	output [17:0] LEDR;
	output [7:0] LEDG;
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	
	output [6:0] HEX0, HEX1;

	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial ground
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(1'b1),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "hopefully_this_works.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	wire [6:0] datain;
	wire load_x, load_y, load_r, load_c, ld_alu_out;
	wire go, loadEn;
	
	wire [7:0]x_in = 8'b00110010;
	wire [6:0]y_in = 7'b0110010;
	
	assign left = KEY[3];
	assign right = KEY[2];
	
	
	datapath d1(SW, KEY, LEDR, LEDG, CLOCK_50, resetn, x_in, y_in, x, y, colour, data_result);

	
	wire [7:0] data_result;

	hex_decoder H0(
        .hex_digit(data_result[3:0]), 
        .segments(HEX0)
        );
        
    hex_decoder H1(
        .hex_digit(data_result[7:4]), 
        .segments(HEX1)
        );

    
endmodule

module datapath(
	 input [17:0]SW,
	 input [3:0]KEY,
	 output [17:0] LEDR,
	 output [7:0] LEDG,
    input clk,
	 input resetn,
	 input [7:0]x_in,
	 input [6:0]y_in,
    output reg [7:0] x,
	 output reg [6:0] y,
	 output reg [2:0] colour,
	 output reg [7:0] data_result
    ); 
	reg [4:0] bool;
   // input registers
   reg [7:0] x_pos;
	reg [6:0] y_pos;
	reg [7:0] dx;
	reg [6:0] dy;
	
	reg [23:0] counter;
	reg [3:0] counterx;
	reg [5:0] countery;
	reg is_rich;
	reg [7:0]score;
	// default positions for the num displays
	//reg [7:0] = intx_n1 = 8'b10011010;
	//reg [6:0] = inty_n1 = 7'b0011100;
	
	//reg [7:0] = intx_n2 = 8'b10011010;
	//reg [6:0] = inty_n2 = 7'b0101000;
	
	//reg [7:0] = intx_n3 = 8'b10011010;
	//reg [6:0] = inty_n3 = 7'b0110010;
	// we need counters for the wheat printing
	reg has_wheat;
	reg [1:0] counterx_n1;
	reg [2:0] countery_n1;
	
	// we need counters for the refined wheat printing
	reg has_refined_wheat;
	reg [1:0] counterx_n2;
	reg [2:0] countery_n2;
	
	// we need counters for the bread printing
	reg has_bread;
	reg [1:0] counterx_n3;
	reg [2:0] countery_n3;
	
	reg clearing;
	reg [1:0]dir;
	
	// for flour FSM
	reg [3:0] y_Q, Y_D;
	localparam A = 4'b0000, B = 4'b0001, C = 4'b0010, refine_time = 28'b1111111111111111111111111111;
	reg [27:0] refine_counter;
	reg done_refine;
	assign LEDG[2] = done_refine;
	
	// for oven FSM
	reg [3:0] z_Q, z_D;
	localparam bake_time = 28'b1111111111111111111111111111;
	reg [27:0] oven_counter;
	reg done_bake;
	assign LEDG[1] = done_bake;
	
	// for feild FSM
	reg [3:0] w_Q, w_D;
	localparam harvest_time = 29'b01111111111111111111111111111;
	localparam dieded_time = 29'b11111111111111111111111111110;
	reg [28:0] field_counter;
	reg crop_done;
	reg crop_dieded;
	assign LEDG[6] = crop_done;
	assign LEDG[5] = crop_dieded;
	
	
	// Wheat counter
	reg [6:0] wheatx;
	reg [3:0] wheaty;
	
	// mother of all registers
	reg is_done;

	
	always @(posedge clk) 
	begin	
		// this is our rate divider it slows stuff down a bit
			// loop till y gets to 36 lines down
			if(countery < 6'b100100)
			begin
				// increment x to 15, go to next line 
				if(counterx == 4'b1111)
				begin
					countery <= countery + 1;
					counterx <= 0;
				end
				else
				begin
				//increment x
					counterx <= counterx + 1;
				end
				
				//if clearing then fill the square with background yellow
				if(clearing)
				begin
					colour <= 3'b110;
				end
				else
				begin
				//~~~~~ DRAWING THE PAPASMURF THIS IS GONNA TAKE TIME ~~~~~~~
				case ({countery, counterx})
					10'b000000110 :  colour <= 3'b000;
					10'b000000111 :  colour <= 3'b000;
					10'b000001000 :  colour <= 3'b000;
					10'b000001001 :  colour <= 3'b000;
					10'b000001010 :  colour <= 3'b000;
					10'b000010011 :  colour <= 3'b000;
					10'b000010100 :  colour <= 3'b000;
					10'b000010101 :  colour <= 3'b000;
					10'b000010110 :  colour <= 3'b100;
					10'b000010111 :  colour <= 3'b100;
					10'b000011000 :  colour <= 3'b100;
					10'b000011001 :  colour <= 3'b100;
					10'b000011010 :  colour <= 3'b000;
					10'b000011011 :  colour <= 3'b000;
					10'b000100001 :  colour <= 3'b000;
					10'b000100010 :  colour <= 3'b000;
					10'b000100011 :  colour <= 3'b100;
					10'b000100100 :  colour <= 3'b100;
					10'b000100101 :  colour <= 3'b100;
					10'b000100110 :  colour <= 3'b100;
					10'b000100111 :  colour <= 3'b100;
					10'b000101000 :  colour <= 3'b100;
					10'b000101001 :  colour <= 3'b100;
					10'b000101010 :  colour <= 3'b100;
					10'b000101011 :  colour <= 3'b000;
					//row  4
					10'b000110000 :  colour <= 3'b000;
					10'b000110001 :  colour <= 3'b100;
					10'b000110010 :  colour <= 3'b100;
					10'b000110011 :  colour <= 3'b100;
					10'b000110100 :  colour <= 3'b100;
					10'b000110101 :  colour <= 3'b100;
					10'b000110110 :  colour <= 3'b100;
					10'b000110111 :  colour <= 3'b100;
					10'b000111000 :  colour <= 3'b100;
					10'b000111001 :  colour <= 3'b100;
					10'b000111010 :  colour <= 3'b100;
					10'b000111011 :  colour <= 3'b000;
					//row 5
					10'b0001000000 :  colour <= 3'b000;
					10'b0001000001 :  colour <= 3'b100;
					10'b0001000010 :  colour <= 3'b100;
					10'b0001000011 :  colour <= 3'b100;
					10'b0001000100 :  colour <= 3'b100;
					10'b0001000101 :  colour <= 3'b100;
					10'b0001000110 :  colour <= 3'b100;
					10'b0001000111 :  colour <= 3'b100;
					10'b0001001000 :  colour <= 3'b100;
					10'b0001001001 :  colour <= 3'b100;
					10'b0001001010 :  colour <= 3'b100;
					10'b0001001011 :  colour <= 3'b100;
					10'b0001001100 :  colour <= 3'b000;
					//row 6
					10'b0001010001 :  colour <= 3'b000;
					10'b0001010010 :  colour <= 3'b100;
					10'b0001010011 :  colour <= 3'b100;
					10'b0001010100 :  colour <= 3'b100;
					10'b0001010101 :  colour <= 3'b100;
					10'b0001010110 :  colour <= 3'b100;
					10'b0001010111 :  colour <= 3'b000;
					10'b0001011000 :  colour <= 3'b100;
					10'b0001011001 :  colour <= 3'b100;
					10'b0001011010 :  colour <= 3'b100;
					10'b0001011011 :  colour <= 3'b100;
					10'b0001011100 :  colour <= 3'b000;
					//row 7
					10'b0001100001 :  colour <= 3'b000;
					10'b0001100010 :  colour <= 3'b100;
					10'b0001100011 :  colour <= 3'b100;
					10'b0001100100 :  colour <= 3'b100;
					10'b0001100101 :  colour <= 3'b100;
					10'b0001100110 :  colour <= 3'b000;
					10'b0001100111 :  colour <= 3'b100;
					10'b0001101000 :  colour <= 3'b100;
					10'b0001101001 :  colour <= 3'b100;
					10'b0001101010 :  colour <= 3'b100;
					10'b0001101011 :  colour <= 3'b100;
					10'b0001101100 :  colour <= 3'b100;
					10'b0001101101 :  colour <= 3'b000;
					//row 8
					10'b0001110010 :  colour <= 3'b000;
					10'b0001110011 :  colour <= 3'b000;
					10'b0001110100 :  colour <= 3'b000;
					10'b0001110101 :  colour <= 3'b000;
					10'b0001110110 :  colour <= 3'b100;
					10'b0001110111 :  colour <= 3'b100;
					10'b0001111000 :  colour <= 3'b100;
					10'b0001111001 :  colour <= 3'b100;
					10'b0001111010 :  colour <= 3'b100;
					10'b0001111011 :  colour <= 3'b100;
					10'b0001111100 :  colour <= 3'b100;
					10'b0001111101 :  colour <= 3'b000;
					//row 9
					10'b0010000010 :  colour <= 3'b000;
					10'b0010000011 :  colour <= 3'b100;
					10'b0010000100 :  colour <= 3'b011;
					10'b0010000101 :  colour <= 3'b011;
					10'b0010000110 :  colour <= 3'b011;
					10'b0010000111 :  colour <= 3'b011;
					10'b0010001000 :  colour <= 3'b011;
					10'b0010001001 :  colour <= 3'b011;
					10'b0010001010 :  colour <= 3'b011;
					10'b0010001011 :  colour <= 3'b011;
					10'b0010001100 :  colour <= 3'b100;
					10'b0010001101 :  colour <= 3'b000;
					//row 10
					10'b0010010010 :  colour <= 3'b000;
					10'b0010010011 :  colour <= 3'b100;
					10'b0010010100 :  colour <= 3'b011;
					10'b0010010101 :  colour <= 3'b111;
					10'b0010010110 :  colour <= 3'b111;
					10'b0010010111 :  colour <= 3'b011;
					10'b0010011000 :  colour <= 3'b011;
					10'b0010011001 :  colour <= 3'b111;
					10'b0010011010 :  colour <= 3'b111;
					10'b0010011011 :  colour <= 3'b011;
					10'b0010011100 :  colour <= 3'b100;
					10'b0010011101 :  colour <= 3'b000;
					//row 11
					10'b0010100010 :  colour <= 3'b000;
					10'b0010100011 :  colour <= 3'b111;
					10'b0010100100 :  colour <= 3'b011;
					10'b0010100101 :  colour <= 3'b011;
					10'b0010100110 :  colour <= 3'b011;
					10'b0010100111 :  colour <= 3'b011;
					10'b0010101000 :  colour <= 3'b011;
					10'b0010101001 :  colour <= 3'b011;
					10'b0010101010 :  colour <= 3'b011;
					10'b0010101011 :  colour <= 3'b011;
					10'b0010101100 :  colour <= 3'b111;
					10'b0010101101 :  colour <= 3'b000;
					//row 12
					10'b0010110001 :  colour <= 3'b000;
					10'b0010110010 :  colour <= 3'b111;
					10'b0010110011 :  colour <= 3'b111;
					10'b0010110100 :  colour <= 3'b011;
					10'b0010110101 :  colour <= 3'b111;
					10'b0010110110 :  colour <= 3'b111;
					10'b0010110111 :  colour <= 3'b011;
					10'b0010111000 :  colour <= 3'b011;
					10'b0010111001 :  colour <= 3'b111;
					10'b0010111010 :  colour <= 3'b111;
					10'b0010111011 :  colour <= 3'b011;
					10'b0010111100 :  colour <= 3'b111;
					10'b0010111101 :  colour <= 3'b111;
					10'b0010111110 :  colour <= 3'b000;
					//row 13
					10'b0011000001 :  colour <= 3'b000;
					10'b0011000010 :  colour <= 3'b111;
					10'b0011000011 :  colour <= 3'b111;
					10'b0011000100 :  colour <= 3'b011;
					10'b0011000101 :  colour <= 3'b111;
					10'b0011000110 :  colour <= 3'b000;
					10'b0011000111 :  colour <= 3'b011;
					10'b0011001000 :  colour <= 3'b011;
					10'b0011001001 :  colour <= 3'b000;
					10'b0011001010 :  colour <= 3'b111;
					10'b0011001011 :  colour <= 3'b011;
					10'b0011001100 :  colour <= 3'b111;
					10'b0011001101 :  colour <= 3'b111;
					10'b0011001110 :  colour <= 3'b000;
					//row 14
					10'b0011010001 :  colour <= 3'b000;
					10'b0011010010 :  colour <= 3'b111;
					10'b0011010011 :  colour <= 3'b111;
					10'b0011010100 :  colour <= 3'b011;
					10'b0011010101 :  colour <= 3'b011;
					10'b0011010110 :  colour <= 3'b011;
					10'b0011010111 :  colour <= 3'b011;
					10'b0011011000 :  colour <= 3'b011;
					10'b0011011001 :  colour <= 3'b011;
					10'b0011011010 :  colour <= 3'b011;
					10'b0011011011 :  colour <= 3'b011;
					10'b0011011100 :  colour <= 3'b111;
					10'b0011011101 :  colour <= 3'b111;
					10'b0011011110 :  colour <= 3'b000;
					//row 15
					10'b0011100001 :  colour <= 3'b000;
					10'b0011100010 :  colour <= 3'b111;
					10'b0011100011 :  colour <= 3'b111;
					10'b0011100100 :  colour <= 3'b011;
					10'b0011100101 :  colour <= 3'b111;
					10'b0011100110 :  colour <= 3'b111;
					10'b0011100111 :  colour <= 3'b111;
					10'b0011101000 :  colour <= 3'b111;
					10'b0011101001 :  colour <= 3'b111;
					10'b0011101010 :  colour <= 3'b111;
					10'b0011101011 :  colour <= 3'b011;
					10'b0011101100 :  colour <= 3'b111;
					10'b0011101101 :  colour <= 3'b111;
					10'b0011101110 :  colour <= 3'b000;
					//row 16
					10'b0011110001 :  colour <= 3'b000;
					10'b0011110010 :  colour <= 3'b111;
					10'b0011110011 :  colour <= 3'b111;
					10'b0011110100 :  colour <= 3'b011;
					10'b0011110101 :  colour <= 3'b111;
					10'b0011110110 :  colour <= 3'b000;
					10'b0011110111 :  colour <= 3'b000;
					10'b0011111000 :  colour <= 3'b000;
					10'b0011111001 :  colour <= 3'b000;
					10'b0011111010 :  colour <= 3'b111;
					10'b0011111011 :  colour <= 3'b011;
					10'b0011111100 :  colour <= 3'b111;
					10'b0011111101 :  colour <= 3'b111;
					10'b0011111110 :  colour <= 3'b000;
					//row 17
					10'b0100000010 :  colour <= 3'b000;
					10'b0100000011 :  colour <= 3'b111;
					10'b0100000100 :  colour <= 3'b111;
					10'b0100000101 :  colour <= 3'b111;
					10'b0100000110 :  colour <= 3'b111;
					10'b0100000111 :  colour <= 3'b111;
					10'b0100001000 :  colour <= 3'b111;
					10'b0100001001 :  colour <= 3'b111;
					10'b0100001010 :  colour <= 3'b111;
					10'b0100001011 :  colour <= 3'b111;
					10'b0100001100 :  colour <= 3'b111;
					10'b0100001101 :  colour <= 3'b000;
					//row 18
					10'b0100010011 :  colour <= 3'b000;
					10'b0100010100 :  colour <= 3'b111;
					10'b0100010101 :  colour <= 3'b111;
					10'b0100010110 :  colour <= 3'b111;
					10'b0100010111 :  colour <= 3'b111;
					10'b0100011000 :  colour <= 3'b111;
					10'b0100011001 :  colour <= 3'b111;
					10'b0100011010 :  colour <= 3'b111;
					10'b0100011011 :  colour <= 3'b111;
					10'b0100011100 :  colour <= 3'b000;
					//row 19
					10'b0100100100 :  colour <= 3'b000;
					10'b0100100101 :  colour <= 3'b000;
					10'b0100100110 :  colour <= 3'b111;
					10'b0100100111 :  colour <= 3'b111;
					10'b0100101000 :  colour <= 3'b111;
					10'b0100101001 :  colour <= 3'b111;
					10'b0100101010 :  colour <= 3'b000;
					10'b0100101011 :  colour <= 3'b000;
					//row 20
					10'b0100110010 :  colour <= 3'b000;
					10'b0100110011 :  colour <= 3'b000;
					10'b0100110100 :  colour <= 3'b000;
					10'b0100110101 :  colour <= 3'b000;
					10'b0100110110 :  colour <= 3'b000;
					10'b0100110111 :  colour <= 3'b000;
					10'b0100111000 :  colour <= 3'b000;
					10'b0100111001 :  colour <= 3'b000;
					10'b0100111010 :  colour <= 3'b000;
					10'b0100111011 :  colour <= 3'b000;
					10'b0100111100 :  colour <= 3'b000;
					10'b0100111101 :  colour <= 3'b000;
					// ROW 21
					10'b0101000010 : colour = 3'b000;
					10'b0101000011 : colour = (is_rich) ? 3'b001 : 3'b011;
					10'b0101000100 : colour = (is_rich) ? 3'b001 : 3'b011;
					10'b0101000101 : colour = (is_rich) ? 3'b001 : 3'b011;
					10'b0101000110 : colour = (is_rich) ? 3'b111 : 3'b011;
					10'b0101000111 : colour = (is_rich) ? 3'b111 : 3'b011;
					10'b0101001000 : colour = (is_rich) ? 3'b111 : 3'b011;
					10'b0101001001 : colour = (is_rich) ? 3'b111 : 3'b011;
					10'b0101001010 : colour = (is_rich) ? 3'b001 : 3'b011;
					10'b0101001011 : colour = (is_rich) ? 3'b001 : 3'b011;
					10'b0101001100 : colour = (is_rich) ? 3'b001 : 3'b011;
					10'b0101001101 : colour = 3'b000;
					// ROW 22
					10'b0101010010 : colour <= 3'b000;
					10'b0101010011 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101010100 : colour <= 3'b000;
					10'b0101010101 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101010110 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101010111 : colour <= (is_rich) ? 3'b111 : 3'b011;
					10'b0101011000 : colour <= (is_rich) ? 3'b111 : 3'b011;
					10'b0101011001 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101011010 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101011011 : colour <= 3'b000;
					10'b0101011100 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101011101 : colour <= 3'b000;
					// ROW 23
					10'b0101100010 : colour <= 3'b000;
					10'b0101100011 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101100100 : colour <= 3'b000;
					10'b0101100101 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101100110 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101100111 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101101000 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101101001 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101101010 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101101011 : colour <= 3'b000;
					10'b0101101100 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101101101 : colour <= 3'b000;
					// ROW 24
					10'b0101110010 : colour <= 3'b000;
					10'b0101110011 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101110100 : colour <= 3'b000;
					10'b0101110101 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101110110 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101110111 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101111000 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101111001 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101111010 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101111011 : colour <= 3'b000;
					10'b0101111100 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0101111101 : colour <= 3'b000;
					// ROW 25
					10'b0110000010 : colour <= 3'b000;
					10'b0110000011 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110000100 : colour <= 3'b000;
					10'b0110000101 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110000110 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110000111 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110001000 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110001001 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110001010 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110001011 : colour <= 3'b000;
					10'b0110001100 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110001101 : colour <= 3'b000;
					// ROW 26 
					10'b0110010010 : colour <= 3'b000;
					10'b0110010011 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110010100 : colour <= 3'b000;
					10'b0110010101 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110010110 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110010111 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110011000 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110011001 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110011010 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110011011 : colour <= 3'b000;
					10'b0110011100 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110011101 : colour <= 3'b000;
					// ROW 27
					10'b0110100010 : colour <= 3'b000;
					10'b0110100011 : colour <= 3'b011;
					10'b0110100100 : colour <= 3'b000;
					10'b0110100101 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110100110 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110100111 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110101000 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110101001 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110101010 : colour <= (is_rich) ? 3'b001 : 3'b011;
					10'b0110101011 : colour <= 3'b000;
					10'b0110101100 : colour <= 3'b011;
					10'b0110101101 : colour <= 3'b000;
					// ROW 28
					10'b0110110010 : colour <= 3'b000;
					10'b0110110011 : colour <= 3'b000;
					10'b0110110100 : colour <= 3'b000;
					10'b0110110101 : colour <= 3'b111;
					10'b0110110110 : colour <= 3'b111;
					10'b0110110111 : colour <= 3'b111;
					10'b0110111000 : colour <= 3'b111;
					10'b0110111001 : colour <= 3'b111;
					10'b0110111010 : colour <= 3'b111;
					10'b0110111011 : colour <= 3'b000;
					10'b0110111100 : colour <= 3'b000;
					10'b0110111101 : colour <= 3'b000;
					// ROW 29
					10'b0111000100 : colour <= 3'b000;
					10'b0111000101 : colour <= 3'b111;
					10'b0111000110 : colour <= 3'b111;
					10'b0111000111 : colour <= 3'b111;
					10'b0111001000 : colour <= 3'b111; 
					10'b0111001001 : colour <= 3'b111;
					10'b0111001010 : colour <= 3'b111;
					10'b0111001011 : colour <= 3'b000;
					// ROW 30
					10'b0111010100 : colour <= 3'b000;
					10'b0111010101 : colour <= 3'b111;
					10'b0111010110 : colour <= 3'b111;
					10'b0111010111 : colour <= 3'b000;
					10'b0111011000 : colour <= 3'b000;
					10'b0111011001 : colour <= 3'b111;
					10'b0111011010 : colour <= 3'b111;
					10'b0111011011 : colour <= 3'b000;
					// ROW 31
					10'b0111100100 : colour <= 3'b000;
					10'b0111100101 : colour <= 3'b111;
					10'b0111100110 : colour <= 3'b111;
					10'b0111100111 : colour <= 3'b000;
					10'b0111101000 : colour <= 3'b000;
					10'b0111101001 : colour <= 3'b111;
					10'b0111101010 : colour <= 3'b111;
					10'b0111101011 : colour <= 3'b000;
					// ROW 32 
					10'b0111110100 : colour <= 3'b000;
					10'b0111110101 : colour <= 3'b111;
					10'b0111110110 : colour <= 3'b111;
					10'b0111110111 : colour <= 3'b000;
					10'b0111111000 : colour <= 3'b000;
					10'b0111111001 : colour <= 3'b111;
					10'b0111111010 : colour <= 3'b111;
					10'b0111111011 : colour <= 3'b000;
				  // ROW 33
					10'b1000000010 : colour <= 3'b000;
					10'b1000000011 : colour <= 3'b000; 
					10'b1000000100 : colour <= 3'b000;
					10'b1000000101 : colour <= 3'b111;
					10'b1000000110 : colour <= 3'b111;
					10'b1000000111 : colour <= 3'b000;
					10'b1000001000 : colour <= 3'b000;
					10'b1000001001 : colour <= 3'b111;
					10'b1000001010 : colour <= 3'b111;
					10'b1000001011 : colour <= 3'b000;
					// ROW 34
					10'b1000010010 : colour <= 3'b000;
					10'b1000010011 : colour <= 3'b111;
					10'b1000010100 : colour <= 3'b111;
					10'b1000010101 : colour <= 3'b111;
					10'b1000010110 : colour <= 3'b000;
					10'b1000010111 : colour <= 3'b111;
					10'b1000011000 : colour <= 3'b111;
					10'b1000011001 : colour <= 3'b111;
					10'b1000011010 : colour <= 3'b111;
					10'b1000011011 : colour <= 3'b000;
					// ROW 35
					10'b1000100010 : colour <= 3'b000;
					10'b1000100011 : colour <= 3'b111;
					10'b1000100100 : colour <= 3'b111;
					10'b1000100101 : colour <= 3'b111;
					10'b1000100110 : colour <= 3'b000;
					10'b1000100111 : colour <= 3'b111;
					10'b1000101000 : colour <= 3'b111;
					10'b1000101001 : colour <= 3'b111;
					10'b1000101010 : colour <= 3'b111;
					10'b1000101011 : colour <= 3'b000;
					// ROW 36
					10'b1000111011 : colour <= 3'b000;
					10'b1000111010 : colour <= 3'b000;
					10'b1000111001 : colour <= 3'b000;
					10'b1000111000 : colour <= 3'b000;
					10'b1000110111 : colour <= 3'b000;
					10'b1000110110 : colour <= 3'b000;
					10'b1000110101 : colour <= 3'b000;
					10'b1000110100 : colour <= 3'b000; 
					10'b1000110011 : colour <= 3'b000;
					10'b1000110010 : colour <= 3'b000;
				  default : colour <= 3'b110;
				endcase
				// ~~~~~~~~~~~~~~~~~~~~~~~ end of drawing smurf~~~~~~~~~~~~~~
				end
			//moves x and y
				x <= x_in + dx + counterx;
				y <= y_in + dy + countery;
			end
			//drawing is complete for smurf check if wheat needs to be updated
			else if (countery_n1 < 3'b101)
			begin 
				if(counterx_n1 == 2'b10)
				begin
					countery_n1 <= countery_n1 + 1;
					counterx_n1 <= 0;
				end
				else
				begin
					counterx_n1 <= counterx_n1 + 1;
				end
				case({has_wheat,countery_n1,counterx_n1})
					6'b000000: colour <= 3'b111;
					6'b000001: colour <= 3'b111;
					6'b000010: colour <= 3'b111;
					6'b000100: colour <= 3'b111;
					6'b000110: colour <= 3'b111;
					6'b001000: colour <= 3'b111;
					6'b001010: colour <= 3'b111;
					6'b001100: colour <= 3'b111;
					6'b001110: colour <= 3'b111;
					6'b010000: colour <= 3'b111;
					6'b010001: colour <= 3'b111;
					6'b010010: colour <= 3'b111;
					//for the 1 case
					6'b100001: colour <= 3'b111;
					6'b100101: colour <= 3'b111;
					6'b101001: colour <= 3'b111;
					6'b101101: colour <= 3'b111;
					6'b110001: colour <= 3'b111;
					default: colour <= 3'b000;
				endcase
				
				x <= 8'b10011001 + counterx_n1;
				y <= 7'b0010111 + countery_n1;
			end
			// Check if refined wheat needs to be updated
			else if (countery_n2 < 3'b101)
			begin 
				if(counterx_n2 == 2'b10)
				begin
					countery_n2 <= countery_n2 + 1;
					counterx_n2 <= 0;
				end
				else
				begin
					counterx_n2 <= counterx_n2 + 1;
				end
				case({has_refined_wheat,countery_n2,counterx_n2})
					6'b000000: colour <= 3'b111;
					6'b000001: colour <= 3'b111;
					6'b000010: colour <= 3'b111;
					6'b000100: colour <= 3'b111;
					6'b000110: colour <= 3'b111;
					6'b001000: colour <= 3'b111;
					6'b001010: colour <= 3'b111;
					6'b001100: colour <= 3'b111;
					6'b001110: colour <= 3'b111;
					6'b010000: colour <= 3'b111;
					6'b010001: colour <= 3'b111;
					6'b010010: colour <= 3'b111;
					//for the 1 case
					6'b100001: colour <= 3'b111;
					6'b100101: colour <= 3'b111;
					6'b101001: colour <= 3'b111;
					6'b101101: colour <= 3'b111;
					6'b110001: colour <= 3'b111;
					default: colour <= 3'b000;
				endcase
				
				x <= 8'b10011001 + counterx_n2;
				y <= 7'b0101010 + countery_n2;
			end
			// Check if has_bread needs to be updated
			else if (countery_n3 < 3'b101)
			begin 
				if(counterx_n3 == 2'b10)
				begin
					countery_n3 <= countery_n3 + 1;
					counterx_n3 <= 0;
				end
				else
				begin
					counterx_n3 <= counterx_n3 + 1;
				end
				
				case({has_bread,countery_n3,counterx_n3})
					6'b000000: colour <= 3'b111;
					6'b000001: colour <= 3'b111;
					6'b000010: colour <= 3'b111;
					6'b000100: colour <= 3'b111;
					6'b000110: colour <= 3'b111;
					6'b001000: colour <= 3'b111;
					6'b001010: colour <= 3'b111;
					6'b001100: colour <= 3'b111;
					6'b001110: colour <= 3'b111;
					6'b010000: colour <= 3'b111;
					6'b010001: colour <= 3'b111;
					6'b010010: colour <= 3'b111;
					//for the 1 case
					6'b100001: colour <= 3'b111;
					6'b100101: colour <= 3'b111;
					6'b101001: colour <= 3'b111;
					6'b101101: colour <= 3'b111;
					6'b110001: colour <= 3'b111;
					default: colour <= 3'b000;
				endcase
				
				x <= 8'b10011001 + counterx_n3;
				y <= 7'b0111101 + countery_n3;
			end
			else if(wheaty < 4'b1010)
			begin
				if(wheatx == 7'b1001111)
				begin
					wheaty <= wheaty + 1;
					wheatx <= 0;
				end
				else
				begin
					wheatx <= wheatx + 1;
				end
				
				if(crop_dieded)
				begin	
					colour <= 3'b000;
				end
				else if(crop_done)
				begin
					colour <= 3'b110;
				end
				else
				begin
					colour <= 3'b010;
				end
				
				x <= 8'b0101000 + wheatx;
				y <= wheaty;
			end
			else
			begin
				// rate divider for movement of charactor
				if (counter == 24'b00010101011110000100000)
				begin
					if(clearing == 1)
					begin
						clearing = 0;
						counterx <= 7'b0;
						countery <= 8'b0;
						counter <= 24'b0;
						//change the direction
						case (dir)
						// NOTE: Change the number to increase movement speed
							2'b00: dy <= dy - 1;
							2'b01: dy <= dy + 1;
							2'b10: dx <= dx - 1;
							2'b11: dx <= dx + 1;
						endcase
					end
					else if(SW[3])
					begin
						if(y > 7'b0001100)
						begin
					   //if SW[3] move charactor up
						counterx <= 7'b0;
						countery <= 8'b0;
						clearing = 1;
						dir<= 2'b00;
						end
					end
					else if(SW[2])
					begin
					   if(y < 7'b1001000)
						begin
						//if SW[2] move charactor down
						counterx <= 7'b0;
						countery <= 8'b0;
						clearing = 1;
						dir<= 2'b01;
						end
					end
					else if(SW[1])
					begin
						//if SW[1] move charactor left
						if(x > 8'b00001100)
						begin
						counterx <= 7'b0;
						countery <= 8'b0;
						clearing = 1;
						dir<= 2'b10;
						end
					end
					else if(SW[0])
					begin
						if(x < 8'b10000101)
						begin
						//if SW[0] move charactor right
						counterx <= 7'b0;
						countery <= 8'b0;
						clearing = 1;
						dir<= 2'b11;
						end
					end
					else if(SW[9])
					begin
						if (y < 7'b1101101 && y > 7'b1000011 && x > 8'b10000010 && x < 8'b10010101 && has_bread == 1)
						begin
							has_bread <= 0;
							countery_n3 <= 0;
							counterx_n3 <= 0;
							data_result[7:0] <= data_result[7:0] + 4'b0001;
							score <= data_result;
							if (score > 3)
							begin
								is_rich <= 1;
							end
							else
							begin
								is_rich <= 0;
							end
						end
					end
					else if(SW[8])
					begin
						counterx_n1 <= 0;
						countery_n1 <= 0;
						has_wheat <= 0;
						
						counterx_n2 <= 0;
						countery_n2 <= 0;
						has_refined_wheat <= 0;
						
						counterx_n3 <= 0;
						countery_n3 <= 0;
						has_bread <= 0;
					end
					
				//move x and y back to inital points
				end
				else
				begin
					counter <= counter+1;
				end
				x <= x_in + dx;
				y <= y_in + dy;
			end
		begin: field_state_table
		  case (w_Q)
				A: begin
						if(field_counter != 29'b01111111111111111111111111111)
						begin
							field_counter <= field_counter + 1;
						end
						else
						begin
							// its ready to be collected
							crop_done <= 1;
							field_counter <= 0;
							wheatx <= 0;
							wheaty <= 0;
							w_D <= B;
						end
					end
				B: begin
						// this is collecting state
						if(field_counter == 29'b11111111111111111111111111110)
						begin
							w_D <= C;
							crop_dieded <= 1;
							crop_done <= 0;
							wheatx <= 0;
							wheaty <= 0;
						end
						else
						begin
							if(SW[9] && y > 4'b1010 && y < 4'b1111 && x > 6'b10100 && x < 7'b1111000)
							begin
								counterx_n1 <= 0;
								countery_n1 <= 0;
								has_wheat <= 1;
								crop_done <= 0;
								wheatx <= 0;
								wheaty <= 0;
								w_D <= A;
							end
							field_counter <= field_counter+1;
						end
					end
				C: begin 
						if(SW[9] && y > 4'b1010 && y < 4'b1111 && x > 6'b10100 && x < 7'b1111000)
							begin
								w_D <= A;
								crop_done <= 0;
								crop_dieded <= 0;
								field_counter <= 0;
								wheatx <= 0;
								wheaty <= 0;
							end
					end
				default: w_D = A;
		  endcase
		end // field_state_table
		
		// FSM FOR THE WHEAT REFINING MACHINE
		begin: state_table
		  case (y_Q)
				A: begin
						// this is an idle state we are waiting for SW[9] to be on
						if(SW[9] && y > 7'b0100010 && y < 7'b1101101 && x < 8'b00010010 && has_wheat == 1)
						begin 
							counterx_n1 <= 0;
							countery_n1 <= 0;
							has_wheat <= 0;
							refine_counter <= refine_time;
							Y_D <= B;
						end
					end
				B: begin
						// this is processing state
						// if timer is not 0 yet, keep decreasing it
						if(refine_counter != 0)
						begin
							refine_counter <= refine_counter-1;
						end
						else
						begin
							done_refine = 1;
							Y_D <= C; 
						end
					end
				C: begin 
						// this is an idle state we are waiting for SW[9] to be on
						if(SW[9] && y > 7'b0100010 && y < 7'b1101101 && x < 8'b00010010)
						begin 
							counterx_n2 <= 0;
							countery_n2 <= 0;
							has_refined_wheat <= 1;
							done_refine = 0;
							Y_D <= A;
						end
					end
				default: Y_D = A;
		  endcase
		end // state_table
		
		// FSM FOR THE OVEN
		begin: oven_state_table
		  case (z_Q)
				A: begin
						// this is an idle state we are waiting for SW[9] to be on
						if(SW[9] && y < 7'b1101101 &&  y > 7'b1000011 && x > 6'b101000 && x < 8'b01011111 && has_refined_wheat == 1)
						begin 
							counterx_n2 <= 0;
							countery_n2 <= 0;
							has_refined_wheat <= 0;
							oven_counter <= bake_time;
							z_D <= B;
						end
					end
				B: begin
						// this is processing state
						// if timer is not 0 yet, keep decreasing it
						if(oven_counter != 0)
						begin
							oven_counter <= oven_counter-1;
						end
						else
						begin
							done_bake = 1;
							z_D <= C; 
						end
					end
				C: begin 
						// this is an idle state we are waiting for SW[9] to be on
						if(SW[9] && y < 7'b1101101 &&  y > 7'b1000011 && x > 6'b101000 && x < 8'b01011111)
						begin 
							counterx_n3 <= 0;
							countery_n3 <= 0;
							has_bread <= 1;
							done_bake = 0;
							z_D <= A;
						end
					end
				default: z_D = A;
		  endcase
		end // oven_state_table
		
		 // State Registers/ resetting states
		begin: state_FFs
		  if(resetn == 1'b0)
				begin
				y_Q <= A; // Should set reset state to state A
				z_Q <= A;
				w_Q <= A;
				end
		  else
				begin
				y_Q <= Y_D;
				z_Q <= z_D;
				w_Q <= w_D;
				end
		  end // state_FFS
	end

endmodule


// endmodule

// hex display for score
module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule

