module PID(
	input clk,
	input rst_n,
	input [12:0] error,
	input not_pedaling,
	output [11:0] drv_mag
);

	reg [17:0] error_ext;
	reg [17:0] error_accum;
	reg [17:0] integrator;
	reg [17:0] error_pos; //ensure value is pos mux
	reg [17:0] error_no_ovfl;
	reg [17:0] error_timed;
	reg [19:0] timer;
	reg [17:0] q1;
	reg [17:0] q2;
	reg done;
	wire pos_ov;

	parameter FAST_SIM = 0;
	
	wire decimator_full;

	generate
		if (FAST_SIM)
			assign decimator_full = &timer[14:0]; // only lower 15 bits
		else
			assign decimator_full = &timer;       // all 20 bits
	endgenerate


	///P AND I LOGIC ///

	// fixed: sign extend error to 18 bits
	//assign error_ext = $signed(error);
	//change to not using signed operater 
	assign error_ext = {error[12], error}; // sign extend to 18 bits

	// feedback adder 
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			error_accum <= 18'h00000;
		end
		else begin
			error_accum <= error_ext + integrator;
		end
	end
	
	// mux controlled by MSB of error_accum
	assign error_pos = error_accum[17] ? (18'b00000) : (error_accum[17:0]);
	
	//positive overflow detection logic
	//of both bit 17 and 16 are high then pos ovfl has occured and set val to 18'h1FFFF
	assign pos_ov = ~error_accum[17] & integrator[16];
	assign error_no_ovfl = pos_ov ? (18'h1FFFF):(error_pos[17:0]);
	

	//timer logic for 1/48 sec decimation
	always_ff @ (posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			timer <= 20'h0; // fixed: use 20-bit zero
			done <= 1'b0;
		end
		else if (decimator_full) begin			//else if (timer == '1) begin
			timer <= 20'h0; // fixed: use 20-bit zero
			done <= 1'b1;
		end
		else begin
			timer <= timer + 1; // increment timer
			done <= 1'b0;        // fixed: clear done after asserting
		end
	end

	// mux to determine output with timer
	assign error_timed = done ? (error_no_ovfl):(integrator);

	// not pedaling logic - if high set to 0
	assign q1 = not_pedaling ? (18'h00000):(error_timed);

	// flop value 
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			q2 <= 18'h00000;
		end
		else begin
			q2 <= q1;
		end
	end
	
	assign integrator = q2;

	/// DECIMATOR ///

	// D-term shift register
	reg [12:0] D_1, D_2, D_3;
	wire signed [12:0] D_diff;
	
	always_ff @(posedge clk or negedge rst_n) begin 
		if (!rst_n) begin
			D_1 <= 13'sd0;
			D_2 <= 13'sd0;
			D_3 <= 13'sd0;
		end
		else if (done) begin
			D_1 <= error;
			D_2 <= D_1;
			D_3 <= D_2;
		end
	end 

	assign D_diff = $signed(error) - $signed(D_3);
	/*
	// Saturate to 9 bits
	wire signed [9:0] D_diff_ext = D_diff;
	*/
	wire signed [8:0] D_saturated;

	//assign D_saturated = (D_diff > 9'sd255)  ? 9'sd255 :(D_diff < -9'sd256) ? -9'sd256 : D_diff[8:0];
	assign D_saturated = (D_diff[10] | D_diff[9] | D_diff[11]) ? (9'sd255) : (D_diff[12] & (~D_diff[11] | ~D_diff[10] | ~D_diff[9])) ? (-9'sd256) : (D_diff[8:0]); 
	//multiply by 2 (shift by 2)
	wire signed [9:0] D_term = D_saturated <<< 1;
	
	//slide 3 (putting it together)
	//establish p term
	wire signed [13:0] P_term = {error[12], error};

	//pipeline flops perchance
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			P_term_pipe <= 14'h0000;
			integrator_pipe <= 18'h00000;
			D_term_pipe <= 13'sd0;
		end
		else begin
			P_term_pipe <= P_term;
			integrator_pipe <= integrator;
			D_term_pipe <= D_term;
		end
	end
	//compute PID sum
	wire signed [13:0] PID = P_term_pipe + integrator_pipe[16:3] + D_term_pipe; // scale I_term down

	//add a pipeline register here to help with timing - after addition hold value
	//value in PID is passed to PID_pipe 
	//this adds another pipeline stage to the design
	reg [13:0] PID_pipe;
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			PID_pipe <= 14'h0000;
		end
		else begin
			PID_pipe <= PID;
		end
	end

	//saturate to unsigned 12 bit
	//wire [11:0] PID_sat_2 = (PID_pipe > 14'sd4095) ? 12'hFFF : (PID < 0) ? 12'h000 : PID[11:0];
	wire [11:0] PID_sat_1 = PID [12] ? (12'hFFF) : (PID[11:0]);
	wire [11:0] PID_sat_2 = PID[13] ? (12'h000) : (PID_sat_1[11:0]);


	//pipeline logic to help meet timing
	reg [11:0] PID_sat_2_pipe;
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			PID_sat_2_pipe <= 12'h000;
		end
		else begin
			PID_sat_2_pipe <= PID_sat_2;
		end
	end

	//asign to drv_mag
	assign drv_mag = PID_sat_2_pipe;


endmodule
