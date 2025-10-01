   typedef logic [3:0][3:0][31:0] operand_t;
   typedef logic        bool_t;
   typedef logic [3:0][3:0][31:0] input_t;
   typedef logic [15:0] vinstr_t;
   
   // --------------
   // TensorCore
   
   module tensorcore #(
       parameter int unsigned DataWidth		= 32,
       parameter int unsigned MatrixLength   = 4, // The TensorCore can compute a MatrixLength x MatrixLength matrix's FMA
       parameter int unsigned INTeger = 0,
       parameter int unsigned mix_precision= 1,
       parameter int unsigned fp_32 = 2
   ) 
   (
       input logic      reset,
       input logic      clk,
       input vinstr_t   vecop,
       input input_t    matrix_a,
       input input_t    matrix_b,
       input input_t    matrix_c,
       output operand_t out
   );
   logic [DataWidth-1:0] temp;
   logic [MatrixLength-1:0][MatrixLength-1:0][MatrixLength-1:0][DataWidth-1:0] temp_multi;
   logic [MatrixLength-1:0][MatrixLength-2:0][MatrixLength-1:0][DataWidth-1:0] temp_add;
   logic [MatrixLength-1:0][MatrixLength-1:0][DataWidth-1:0] temp_out_fp_32;
   logic [MatrixLength-1:0][MatrixLength-1:0][MatrixLength-1:0][DataWidth-1:0] temp_multi_mix;
   logic [MatrixLength-1:0][MatrixLength-2:0][MatrixLength-1:0][DataWidth-1:0] temp_add_mix;
   logic [MatrixLength-1:0][MatrixLength-1:0][DataWidth-1:0] temp_out_fp_mix;

   genvar i;
   genvar j;
   genvar k;
   generate
   for(i = 0; i < MatrixLength; i++) begin
        for(j = 0; j < MatrixLength; j++) begin
            for(k = 0;k < MatrixLength; k++) begin
            multiplier m(.a(matrix_a[i][k]),
            .b(matrix_b[k][j]),
            .o(temp_multi[i][k][j]));
            
            multiplier #(.DataWidth(16), .exp_len(5), .mid(20)) m_16(
                .a(matrix_a[i][k][15:0]),
            .b(matrix_b[k][j][15:0]),
            .o(temp_multi_mix[i][k][j]));
            end
        end
   end
   endgenerate
   
   generate
   for(i = 0; i < MatrixLength; i++) begin:add_1
        for(j = 0; j < MatrixLength; j++) begin:add_2
            for(k = 0;k < MatrixLength; k++) begin:add_3
            if (k == 0) begin
                adder a(.a(temp_multi[i][k][j]),
                .b(temp_multi[i][k+1][j]),
                .o(temp_add[i][k][j]));
                
                adder a_16(.a(temp_multi_mix[i][k][j]),
                .b(temp_multi_mix[i][k+1][j]),
                .o(temp_add_mix[i][k][j]));
            end
            else if (k == MatrixLength - 1)begin
                adder a(.a(temp_add[i][k-1][j]),
                .b(matrix_c[i][j]),
                .o(temp_out_fp_32[i][j]));
                
                adder a_16(.a(temp_add_mix[i][k - 1][j]),
                .b(matrix_c[i][j]),
                .o(temp_out_fp_mix[i][j]));
            end
            else begin
                adder a(.a(temp_add[i][k-1][j]),
                .b(temp_multi[i][k+1][j]),
                .o(temp_add[i][k][j]));
                
                adder a_16(.a(temp_add_mix[i][k-1][j]),
                .b(temp_multi_mix[i][k+1][j]),
                .o(temp_add_mix[i][k][j]));
            end
            end
        end
   end
   endgenerate
   
   always @(posedge clk or posedge reset) begin
      if (reset) begin
         out <= 0; // each element of output matrix is 0.
      end else begin
         if (vecop[1:0] == INTeger) begin
            for (int i = 0; i < MatrixLength; i++) begin
               for (int j = 0; j < MatrixLength; j++) begin
                  temp = matrix_c[i][j];
                  for (int k = 0; k < MatrixLength; k++) begin
                        temp = temp + matrix_a[i][k] * matrix_b[k][j];
                   end
                   out[i][j] <= temp;
                  end
               end
            end
         else if (vecop[1:0] == fp_32) begin
            out <= temp_out_fp_32;
         end
         else if (vecop[1:0] == mix_precision) begin
            out <= temp_out_fp_mix;
         end
        end
      end

   endmodule