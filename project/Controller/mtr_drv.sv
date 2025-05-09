// mtr_drv.sv
// Generates high-side and low-side gate drive signals for each phase of a 
// brushless DC motor (green, yellow, blue) using decoded drive mode selectors 
// and a shared PWM signal.
//
// Each phase receives a pair of 2-bit selectors (from `brushless.sv`) which 
// determine the drive mode: High-Z, forward current, reverse current, or 
// regenerative braking. This module:
//
// - Instantiates a `PWM` module to generate synchronized PWM pulses.
// - Decodes each selector into high-side and low-side signals using two 
//   registers per phase (double-flop logic).
// - Uses `nonoverlap` modules to ensure that high-side and low-side FETs 
//   are never on at the same time (dead-time insertion).
//
// The module outputs `PWM_synch` (1-cycle pulse) once per PWM cycle to 
// synchronize other modules like `brushless.sv` with PWM timing.
//
// Team VeriLeBron (Dustin, Shane, Quinn, Eeshana)

module mtr_drv(
	input logic clk,
	input logic rst_n,
	input logic [10:0] duty,
	input logic [1:0] selGrn,
	input logic [1:0] selYlw,
	input logic [1:0] selBlu,
	output logic PWM_synch,
	output logic highGrn,
	output logic lowGrn,
	output logic highYlw,
	output logic lowYlw,
	output logic highBlu,
	output logic lowBlu 

);
	wire PWM_sig;
    	

	reg q1Grn,q2Grn;
	reg q1Ylw, q2Ylw;
	reg q1Blu, q2Blu;

	//first call PWM module to take duty and output PWM_synch and PWM_sig
	PWM PWM (
		.clk(clk),
		.rst_n(rst_n),
		.duty(duty),
		.PWM_sig(PWM_sig), //output help in wires 
		.PWM_synch(PWM_synch)	//output held in wire 
	);

	// GREEN LOGIC
	//1st flopper mux for Grn
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
		//reset logic
			q1Grn <= 1'b0;	//set to 0 on a reset
		end
		else begin
			case(selGrn) //evaluate selGrn value
				2'b00: begin	//when 00 q1Grn is 0
					q1Grn <= 1'b0;
				end
				2'b01: begin	//when 01 q1Grn is the inverse of PWM_sig
					q1Grn <= ~(PWM_sig);
				end
				2'b10: begin	//when 10 q1Grn is PWM_sig 
					q1Grn <= PWM_sig;
				end
				2'b11: begin	//when 11 q1Grn is 0
					q1Grn <= 1'b0;
				end

			endcase
		end
	end	

	//2nd flopper for green repeat this process for Yellow and Blue and well be flying
	always_ff @ (posedge clk or negedge rst_n) begin
		if(!rst_n) begin
		//reset logic
			q2Grn <= 1'b0;
		end
		else begin
			case(selGrn) 
				2'b00: begin
					q2Grn <= 1'b0;
				end

				2'b01: begin
					q2Grn <= PWM_sig;
				end	

				2'b10: begin
					q2Grn <= ~(PWM_sig);
				end

				2'b11: begin
					q2Grn <= PWM_sig;
				end
		

			endcase
		end
	end


	//YELLOW LOGIC
	//1st flopper mux for Grn
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
		//reset logic
			q1Ylw <= 1'b0;
		end
		else begin
	
			case(selYlw) 
				2'b00: begin
					q1Ylw <= 1'b0;
				end

				2'b01: begin
					q1Ylw <= ~(PWM_sig);
				end

				2'b10: begin
					q1Ylw <= PWM_sig;
				end

				2'b11: begin
					q1Ylw <= 1'b0;
				end

			endcase
		end
	end

	//2nd flopper for green repeat this process for Yellow and Blue and well be flying
	always_ff @ (posedge clk or negedge rst_n) begin
		if(!rst_n) begin
		//reset logic
			q2Ylw <= 1'b0;
		end
		else begin
			case(selYlw) 
				2'b00: begin
					q2Ylw <= 1'b0;
				end

				2'b01: begin
					q2Ylw <= PWM_sig;
				end

				2'b10: begin
					q2Ylw <= ~(PWM_sig);
				end

				2'b11: begin
					q2Ylw <= PWM_sig;
				end

			endcase
		end
	end

	//BLUE LOGIC
	//1st flopper mux for Grn
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			q1Blu <= 1'b0;
		end
		else begin
			case(selBlu) 
				2'b00: begin
					q1Blu <= 1'b0;
				end

				2'b01: begin
					q1Blu <= ~(PWM_sig);
				end

				2'b10: begin
					q1Blu <= PWM_sig;
				end

				2'b11: begin
					q1Blu <= 1'b0;
				end

			endcase
		end
	end

	//2nd flopper for green repeat this process for Yellow and Blue and well be flying
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
		//reset logic
			q2Blu <= 1'b0;
		end
		else begin
			case(selBlu) 
				2'b00: begin
					q2Blu <= 1'b0;
				end

				2'b01: begin
					q2Blu <= PWM_sig;
				end

				2'b10: begin
					q2Blu <= ~(PWM_sig);
				end

				2'b11: begin
					q2Blu <= PWM_sig;
				end

			endcase
		end
	end
	
	//3 non overlap modules at the end as per diagram provided 
	nonoverlap NO_OVERLAP_GRN (
		.clk(clk),
		.rst_n(rst_n),
		.highIn(q1Grn),
		.lowIn(q2Grn),
		.highOut(highGrn),
		.lowOut(lowGrn)
	);

	nonoverlap NO_OVERLAP_YLW (
		.clk(clk),
		.rst_n(rst_n),
		.highIn(q1Ylw),
		.lowIn(q2Ylw),
		.highOut(highYlw),
		.lowOut(lowYlw)
	);

	nonoverlap NO_OVERLAP_BLU (
		.clk(clk),
		.rst_n(rst_n),
		.highIn(q1Blu),
		.lowIn(q2Blu),
		.highOut(highBlu),
		.lowOut(lowBlu)
	);
	

endmodule

