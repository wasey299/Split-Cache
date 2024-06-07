//------------------------------------------------------------------------------------------------//
//                                  ECE 585 Project Code                                          //
//                                         Team 5                                                 //
//             Team Members: Fardeen Wasey, Aalap Khanolkar, Adeel Ahmed, Yunus Syed              // 
//------------------------------------------------------------------------------------------------//

//--Main Module------------------------------------------------------------------------------------------------//

module cache #(
	parameter Address_bits_size  	             = 32,
    parameter Associativity_instruction_cache    = 2,
   	parameter Associativity_data_cache     	     = 4,
    parameter K                                  = 2**10, 	
   	parameter Sets      		                 = 16*K,
	parameter Line_size 		                 = 64,
	parameter Tracefile		                     ="trace_punit"
);

//--Parameters and Variables------------------------------------------------------------------------------------------------//

bit	[$clog2(Associativity_data_cache)-1:0] Associativity_data_cache_store;
bit	[$clog2(Associativity_instruction_cache)-1:0] Associativity_instruction_cache_store;
bit	[$clog2(Associativity_data_cache)-1:0] Current_way_data_cache;
bit	[$clog2(Associativity_instruction_cache)-1:0] Current_way_instruction_cache;

parameter Index_bits 		= $clog2(Sets);
parameter Byte_offset_bits 	= $clog2(Line_size);
parameter Tag_bits 			= (Address_bits_size)-(Index_bits-Byte_offset_bits);

logic 	[1:0]Current_way;
logic 	[Address_bits_size-1:0] Address;
logic 	[3:0] Command;
logic 	[Index_bits-1:0] Index;
logic 	[Tag_bits -1:0] Tag;
logic 	[Byte_offset_bits - 1:0] Byte;
logic   Found;
logic 	Result;

parameter READ_L1_DATA_CACHE  			= 4'd0;
parameter WRITE_L1_DATA_CACHE      	    = 4'd1;
parameter READ_L1_INSTRUCTION_CACHE 	= 4'd2;
parameter INVALIDATE_COMMAND_L2 	    = 4'd3;
parameter DATA_REQUEST_L2 		        = 4'd4;
parameter RESET            		        = 4'd8;
parameter PRINT			 	            = 4'd9; 

typedef enum bit[1:0]{      
 Invalid 	= 2'b00,
 Shared 	= 2'b01, 
 Modified 	= 2'b10, 
 Exclusive 	= 2'b11} MESI_state;

 MESI_state CurrentState;

integer trace; 
integer display_temp;
 
//--Cache Structure------------------------------------------------------------------------------------------------//

typedef struct packed
    {
        MESI_state MESI_bits; bit [$clog2(Associativity_data_cache)-1:0]LRU_bits; bit [Tag_bits-1:0] Tag_bits;
    } Cache_line_data_cache;

Cache_line_data_cache [Sets-1:0][Associativity_data_cache-1:0] Data_cache; 

typedef struct packed
    {
        MESI_state MESI_bits; bit [$clog2(Associativity_instruction_cache)-1:0]LRU_bits; bit [Tag_bits-1:0] Tag_bits;    
    } Cache_line_instruction_cache;

Cache_line_instruction_cache [Sets-1:0][Associativity_instruction_cache-1:0]Instruction_cache; 

//--Tasks to update LRU Bits------------------------------------------------------------------------------------------------//

task automatic Update_LRU_bits_data_cache(logic [Index_bits-1:0]iIndex, ref bit [$clog2(Associativity_data_cache)-1:0] Associativity_data_cache_store ,ref bit [$clog2(Associativity_data_cache)-1:0] Current_way_data_cache );
	bit [$clog2(Associativity_data_cache)-1:0]temp;
	temp = Data_cache[iIndex][Current_way_data_cache].LRU_bits;
	
	for (int j = 0; j < Associativity_data_cache; j++)
	begin
		
		if(Data_cache[iIndex][j].LRU_bits < temp) 
		begin
			Data_cache[iIndex][j].LRU_bits = Data_cache[iIndex][j].LRU_bits + 1'b1;
		end

	end
	Data_cache[iIndex][Current_way_data_cache].LRU_bits = '0;
endtask : Update_LRU_bits_data_cache


task automatic Update_LRU_bits_instruction_cache(logic [Index_bits-1:0]iIndex, ref bit [$clog2(Associativity_instruction_cache)-1:0] Associativity_instruction_cache_store,ref bit [$clog2(Associativity_instruction_cache)-1:0] Current_way_instruction_cache );
	bit [$clog2(Associativity_instruction_cache)-1:0]temp;
	temp = Instruction_cache[iIndex][Current_way_instruction_cache].LRU_bits;
	
	for (int j = 0; j < Associativity_instruction_cache; j++)
	begin
		
		if(Instruction_cache[iIndex][j].LRU_bits < temp) 
		begin
			Instruction_cache[iIndex][j].LRU_bits = Instruction_cache[iIndex][j].LRU_bits + 1'b1;
		
		end
	end
	
	Instruction_cache[iIndex][Current_way_instruction_cache].LRU_bits = '0;
endtask : Update_LRU_bits_instruction_cache

endmodule

//--Counters----------------------------------------------------------------------------------------------//

int unsigned Hit_counter_data_cache = 0;
int unsigned Miss_counter_data_cache = 0;
int unsigned Read_counter_data_cache = 0;
int unsigned Write_counter_data_cache = 0;
real Hit_counter_instruction_cache = 0;
real Miss_counter_instruction_cache= 0;
int unsigned Read_counter_instruction_cache = 0;
real Hit_ratio_data_cache;
real Hit_ratio_instruction_cache; 
longint unsigned Cache_iterations = 0;


task Increment_cache_hit_counter_data_cache(); // Hit Counter for data Cache
	Hit_counter_data_cache = Hit_counter_data_cache + 1;
		`ifdef mode2
			$display ("CacheHitCounter of Data Cache= %d \n",Hit_counter_data_cache);
		`endif
endtask


task Increment_cache_miss_counter_data_cache(); // Miss Counter for data cache
	Miss_counter_data_cache = Miss_counter_data_cache + 1;
		`ifdef mode2		
			$display ("CacheMissCounter of Data Cache = %d \n",Miss_counter_data_cache);
		`endif
endtask


task Increment_cache_read_counter_data_cache(); // Read counter for data cache
	Read_counter_data_cache = Read_counter_data_cache + 1;
		`ifdef mode2
			$display ("CacheReadCounter of Data Cache= %d \n",Read_counter_data_cache);
		`endif
endtask 


task Increment_cache_write_counter_data_cache();
	Write_counter_data_cache = Write_counter_data_cache + 1; // Write counter for data cache
		`ifdef mode2
			$display ("CacheWriteCounter of Data Cache = %d \n",Write_counter_data_cache);
		`endif
endtask


task Increment_cache_hit_counter_instruction_cache(); // Hit Counter for Instruction cache
	Hit_counter_instruction_cache = Hit_counter_instruction_cache + 1;
		`ifdef mode2
			$display ("CacheHitCounter of Instruction Cache= %d \n",Hit_counter_instruction_cache);
		`endif
endtask


task Increment_cache_miss_counter_instruction_cache(); // Miss Counter for instruction cache
	Miss_counter_instruction_cache = Miss_counter_instruction_cache + 1;
		`ifdef mode2		
			$display ("CacheMissCounter of Instruction Cache = %d \n",Miss_counter_instruction_cache);
		`endif
endtask


task Increment_cache_read_counter_instruction_cache(); // Read counter for Instruction cache
	Read_counter_instruction_cache = Read_counter_instruction_cache + 1;
		`ifdef mode2
			$display ("CacheReadCounter of Instruction Cache = %d \n",Read_counter_instruction_cache);
		`endif
endtask 


task Hit_ratio_update_data_cache(); // Ht ratio for data cache

	Hit_ratio_data_cache = (real'(Hit_counter_data_cache)/(real'(Hit_counter_data_cache) + real'(Miss_counter_data_cache))) * 100.00;
	`ifdef mode2
	
		$display("CacheHitRatio for Data Cache= %f \n" ,Hit_ratio_data_cache);
	
	`endif
endtask


task Hit_ratio_update_instruction_cache(); // Hit ratio for Instruction cache
		Hit_ratio_instruction_cache = (real'(Hit_counter_instruction_cache)/(real'(Hit_counter_instruction_cache) + real'(Miss_counter_instruction_cache))) * 100.00;
        `ifdef mode2
			$display("CacheHitRatio for Instruction cache = %f \n" ,Hit_ratio_instruction_cache );
		`endif
endtask

task Increment_cache_iterations(); // Increments after every cache access
	Cache_iterations = Cache_iterations + 1;
		`ifdef mode2
			$display ("Cache_iterations= %d \n",Cache_iterations);
		`endif
endtask


//--Functions------------------------------------------------------------------------------------------------//

//---0 Read data from L1 Data Cache--------------------------------------------------------------------------//

task function0 ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index); 
	
	Increment_cache_iterations();
	Increment_cache_read_counter_data_cache();
	
	Valid_Address_Data_cache (Index, Tag, Associativity_data_cache_store, Result, Current_way_data_cache, CurrentState);
	if (Result == 1)
	begin
		Increment_cache_hit_counter_data_cache();
		Update_LRU_bits_data_cache(Index, Associativity_data_cache_store, Current_way_data_cache );
		Data_cache[Index][Current_way_data_cache].MESI_bits = Data_cache[Index][Current_way_data_cache].MESI_bits;
	end
	
	else
	begin
		Increment_cache_miss_counter_data_cache();
		
		`ifdef mode2
			$display ("CacheMiss...., iTag=%0h, iIndex=%0h, Ways_store=%0h, CurrentState=%s ",Tag, Index, Associativity_data_cache_store,Data_cache[Index][Associativity_data_cache].MESI_bits);
		`endif
		
		Found = 0;
		Find_invalind_line_data_cache(Index , Associativity_data_cache_store , Found , Current_way_data_cache, CurrentState );
		
		if (Found)
		begin
			Allocate_line_data_cache(Index,Tag, Current_way_data_cache);
			
			`ifdef mode2
				$display("Read from L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif
			
			`ifdef mode1
				$display("Read from L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif

			Update_LRU_bits_data_cache(Index, Associativity_data_cache_store, Current_way_data_cache );
			Data_cache[Index][Current_way_data_cache].MESI_bits = Shared;
		end

		else
		begin
			Eviction_data_cache(Index, Current_way_data_cache);
			Allocate_line_data_cache(Index, Tag, Current_way_data_cache);
			
			`ifdef mode2
				$display("Read from L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif

			`ifdef mode1
				$display("Read from L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif
			
			Update_LRU_bits_data_cache(Index, Associativity_data_cache_store, Current_way_data_cache );
		end
	
	end
	`ifdef mode2
	for (int i =0; i< Associativity_data_cache; i++)
	begin
		
		$display("Tag= %h ,Way number = %d , LRU bits = %d , MESI_STATE = %s", Data_cache[Index][i].Tag_bits, i ,Data_cache[Index][i].LRU_bits, Data_cache[Index][i].MESI_bits );
	end
	`endif

endtask

//--1 Write data to L1 Data Cache------------------------------------------------------------------------//
task function1 ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index);
	
	Increment_cache_iterations();
	Increment_cache_write_counter_data_cache();
	
	Valid_Address_Data_cache (Index, Tag, Associativity_data_cache_store, Result, Current_way_data_cache, CurrentState);
	
	if (Result == 1)
	begin
		Increment_cache_hit_counter_data_cache();
		
		Update_LRU_bits_data_cache(Index, Associativity_data_cache_store, Current_way_data_cache );
		
		if ((Data_cache[Index][Current_way_data_cache].MESI_bits == Exclusive) | (Data_cache[Index][Current_way_data_cache].MESI_bits == Modified) )
		begin
			Data_cache[Index][Current_way_data_cache].MESI_bits = Modified;
		end
		
		else if (Data_cache[Index][Current_way_data_cache].MESI_bits == Shared)
		begin
			Data_cache[Index][Current_way_data_cache].MESI_bits = Exclusive;
			
			`ifdef mode2
				$display("Write to L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}}); 
			`endif

			`ifdef mode1
				$display("Write to L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}}); 
			`endif
		end
	end
	
	else
	begin
		Increment_cache_miss_counter_data_cache();
		Find_invalind_line_data_cache(Index , Associativity_data_cache_store , Found , Current_way_data_cache, CurrentState );
	
		if (Found)
		begin
			Allocate_line_data_cache(Index,Tag, Current_way_data_cache);
			
			`ifdef mode2
				$display("Read for ownership from L2 %h ", Address);
				$display("Write to L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}}); 
			`endif

			`ifdef mode1
				$display("Read for ownership from L2 %h ", Address);
				$display("Write to L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}}); 
			`endif

			Update_LRU_bits_data_cache(Index, Associativity_data_cache_store, Current_way_data_cache );
			Data_cache[Index][Current_way_data_cache].MESI_bits = Exclusive;
		end

		else
		begin
			Eviction_data_cache(Index, Current_way_data_cache);
			Allocate_line_data_cache(Index, Tag, Current_way_data_cache);
			
			`ifdef mode2
				$display("Read for ownership from L2 %h ", Address);
				$display("Write to L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}}); 
			`endif

			`ifdef mode1
				$display("Read for ownership from L2 %h ", Address);
				$display("Write to L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}}); 
			`endif
			
			Update_LRU_bits_data_cache(Index, Associativity_data_cache_store, Current_way_data_cache );
			Data_cache[Index][Current_way_data_cache].MESI_bits = Exclusive;
		end
	
	end
	
	`ifdef mode2
		for (int i =0; i< Associativity_data_cache; i++)
		begin
			$display("Tag= %h ,Way number = %d , LRU bits = %d , MESI_STATE = %s", Data_cache[Index][i].Tag_bits, i ,Data_cache[Index][i].LRU_bits, Data_cache[Index][i].MESI_bits );
		end
	`endif

endtask

//--2 Instruction Fetch------------------------------------------------------------------------//
task function2 ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index); 
	Increment_cache_iterations();
	Increment_cache_read_counter_instruction_cache();
	
	Valid_Address_Instruction_cache (Index, Tag, Associativity_instruction_cache_store, Result, Current_way_instruction_cache, CurrentState);
	
	if (Result == 1)
	begin
		Increment_cache_hit_counter_instruction_cache();
		Update_LRU_bits_instruction_cache(Index, Associativity_instruction_cache_store, Current_way_instruction_cache );
		Instruction_cache[Index][Current_way_instruction_cache].MESI_bits = Shared;
	end
	
	else
	begin
		Increment_cache_miss_counter_instruction_cache();
		
		`ifdef mode2
			$display ("CacheMiss...., Tag=%0h, Index=%0h, Ways_store=%0h, CurrentState=%s ",Tag, Index, Associativity_instruction_cache_store,Instruction_cache[Index][Associativity_instruction_cache].MESI_bits);
		`endif
		
		Find_invalind_line_ins(Index , Associativity_instruction_cache_store , Found , Current_way_instruction_cache, CurrentState );
		
		if (Found)
		begin
			Allocate_line_instruction_cache(Index,Tag, Current_way_instruction_cache);
			
			`ifdef mode2
				$display("Read from L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif

			`ifdef mode1
				$display("Read from L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif
			
			Update_LRU_bits_instruction_cache(Index, Associativity_instruction_cache_store, Current_way_instruction_cache );
			Instruction_cache[Index][Current_way_instruction_cache].MESI_bits = Shared;
		end

		else
		begin
			Eviction_instruction_cache(Index, Current_way_instruction_cache);
			Allocate_line_instruction_cache(Index, Tag, Current_way_instruction_cache);
			
			`ifdef mode2
				$display("Read from L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif

			`ifdef mode1
				$display("Read from L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif
			
			Update_LRU_bits_instruction_cache(Index, Associativity_instruction_cache_store, Current_way_instruction_cache );

		end
	end
	
	`ifdef mode2
		for (int i =0; i< Associativity_instruction_cache; i++)
		begin
			$display("Tag= %h ,Way number = %d , LRU bits = %d , MESI_State = %s",Instruction_cache[Index][i].Tag_bits, i ,Instruction_cache[Index][i].LRU_bits, Instruction_cache[Index][i].MESI_bits );	
		end
	`endif

endtask

//--3 Send Invalidate command from L2 cache------------------------------------------------------------------------//
task function3 ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index);
	Increment_cache_iterations();
	
	Valid_Address_Data_cache (Index, Tag, Associativity_data_cache_store, Result, Current_way_data_cache, CurrentState);
	if (Result == 1)
	begin
	 	if ((Data_cache[Index][Current_way_data_cache].MESI_bits == Modified) | (Data_cache[Index][Current_way_data_cache].MESI_bits == Exclusive))
		begin
			`ifdef mode2
				$display("WARNING!!!  The data is in %s state in L1", Data_cache[Index][Current_way_data_cache].MESI_bits);
			`endif		
		end

		else if ((Data_cache[Index][Current_way_data_cache].MESI_bits == Shared))
		begin
			Data_cache[Index][Current_way_data_cache].MESI_bits = Invalid;
		end
	end

	`ifdef mode2
		for (int i =0; i< Associativity_data_cache; i++)
		begin
				$display("Tag= %h ,Way number = %d , LRU bits = %d , MESI_State = %s",Data_cache[Index][i].Tag_bits, i ,Data_cache[Index][i].LRU_bits, Data_cache[Index][i].MESI_bits );	
		end
	`endif

endtask

//--4 Data Request from L2 Cache------------------------------------------------------------------------//
task function4 ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index); 
	Increment_cache_iterations();
	
	Valid_Address_Data_cache (Index, Tag, Associativity_data_cache_store, Result, Current_way_data_cache, CurrentState);
	if (Result == 1)
	 begin
	 	if (Data_cache[Index][Current_way_data_cache].MESI_bits == Exclusive)
		begin
			Data_cache[Index][Current_way_data_cache].MESI_bits = Shared;
		end

		else if (Data_cache[Index][Current_way_data_cache].MESI_bits == Modified)
		begin
			`ifdef mode1	
				$display("Return data to L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif

			`ifdef mode2	
				$display("Return data to L2 address %h" , {Tag,Index, {Byte_offset_bits{1'b0}}});
			`endif
			Data_cache[Index][Current_way_data_cache].MESI_bits = Shared;
		end

		else if (Data_cache[Index][Current_way_data_cache].MESI_bits == Shared)
		begin
			`ifdef mode2
				$display("WARNING!!! Data already present in L2 Address");
			`endif		
		end
	
	end

	`ifdef mode2
		for (int i =0; i< Associativity_data_cache; i++)
		begin
			$display("Tag= %h ,Way number = %d , LRU bits = %d , MESI_State = %s",Data_cache[Index][i].Tag_bits, i ,Data_cache[Index][i].LRU_bits, Data_cache[Index][i].MESI_bits );
		end
	`endif
endtask


//--Clear and Reset------------------------------------------------------------------------------------------------------//

task ClearCache();
	Increment_cache_iterations();
	
	for(int i=0; i< Sets; i++) 
	begin

		for(int j=0; j< Associativity_data_cache; j++) 
		begin
			Data_cache[i][j].Tag_bits 	= '0;
			Data_cache[i][j].LRU_bits 	= {$clog2(Associativity_data_cache){1'b1}};
			Data_cache[i][j].MESI_bits 	= Invalid;
		end
	
	end

	for(int i=0; i< Sets; i++) 
	begin
		
		for(int j=0; j< Associativity_instruction_cache; j++) 
		begin	
			Instruction_cache[i][j].Tag_bits 	= '0;
			Instruction_cache[i][j].LRU_bits 	= {$clog2(Associativity_instruction_cache){1'b1}};
			Instruction_cache[i][j].MESI_bits 	= Invalid;
		end
	
	end

endtask:ClearCache

//--Print all the contents with Valid Bits------------------------------------------------------------------------------------//
task PRINT_CONTENTS();
	bit already;
	
	$display("*********************\nStart of Data Cache");
	for(int i=0; i< Sets; i++)
	begin
		for(int j=0; j< Associativity_data_cache; j++) 
		begin
			if(Data_cache[i][j].MESI_bits != Invalid)
			begin
				if(!already)
				begin
				$display("*********************\nIndex = %h", i);
				already = 1;
				end
				$display("--------------------------------");
				$display(" Way = %d \n Tag = %h \n MESI = %s \n LRU = %b", j, Data_cache[i][j].Tag_bits, Data_cache[i][j].MESI_bits, Data_cache[i][j].LRU_bits);
			end
		end
		already = 0;
	end
	$display("********************\nEnd of Data cache.\n********************\n\n");
	
	
	$display("*********************\nStart of Instruction Cache");
	for(int i=0; i< Sets; i++)
	begin
		for(int j=0; j< Associativity_instruction_cache; j++) 
		begin
			if(Instruction_cache[i][j].MESI_bits != Invalid)
			begin
				if(!already)
				begin
				$display("*********************\nIndex = %h", i);
				already = 1;
				end
				$display("--------------------------------");
				$display(" Way = %d \n Tag = %h \n MESI = %s \n LRU = %b", j, Instruction_cache[i][j].Tag_bits, Instruction_cache[i][j].MESI_bits, Instruction_cache[i][j].LRU_bits);
			end
		end
		already = 0;
	end
	$display("********************\nEnd of Instruction cache.\n********************");

endtask


//--Checking the INVALID MESI States and Tag bits--------------------------------------------------------------//

task automatic Valid_Address_Data_cache (logic [Index_bits-1 :0] iIndex, logic [Tag_bits -1 :0] iTag, ref bit [$clog2(Associativity_data_cache)-1:0] Associativity_data_cache_store, output logic Result , ref bit [$clog2(Associativity_data_cache)-1:0] Current_way_data_cache , output MESI_state CurrentState );
	Result = 0;

	for (int j = 0;  j < Associativity_data_cache; j++)
	begin

		if (Data_cache[iIndex][j].MESI_bits != Invalid) 
		begin	
			
			if (Data_cache[iIndex][j].Tag_bits == iTag)
			begin 
			
				Current_way_data_cache = j;
				Result = 1; 
				`ifdef mode2
					$display ("CacheHit...., Tag=%0h, Index=%0h, Way_data =%d, CurrentState=%s ",iTag, iIndex,Current_way_data_cache,Data_cache[iIndex][Current_way_data_cache].MESI_bits);
				`endif
				return;
			end
				
		end
	end		

endtask

task automatic Valid_Address_Instruction_cache (logic [Index_bits-1 :0] iIndex, logic [Tag_bits -1 :0] iTag, ref bit [$clog2(Associativity_instruction_cache)-1:0] Associativity_instruction_cache_store, output logic Result , ref bit [$clog2(Associativity_instruction_cache)-1:0] Current_way_instruction_cache , output MESI_state CurrentState );
	Result = 0;

	for (int j = 0;  j < Associativity_instruction_cache; j++)
	begin
		if (Instruction_cache[iIndex][j].MESI_bits != Invalid) 
		begin`ifdef mode2	
				$display("Return data to L2 address %h" , {iTag,iIndex, {Byte_offset_bits{1'b0}}});
			`endif
			
			if (Instruction_cache[iIndex][j].Tag_bits == iTag)
			begin 
			
				Current_way_instruction_cache = j;
				Result = 1; 
				
				`ifdef mode2
					$display ("CacheHit...., Tag=%0h, Index=%0h, Way_ins =%d, CurrentState=%s ",iTag, iIndex,Current_way_instruction_cache, Instruction_cache[iIndex][Current_way_instruction_cache].MESI_bits);
				 `endif
				
				return;
			end
				
		end
		
	end		

endtask

//--Finding Invalid line----------------------------------------------------------------------------------------------------//

task automatic Find_invalind_line_data_cache (logic [Index_bits-1:0] iIndex, ref bit [$clog2(Associativity_data_cache)-1:0] Associativity_data_cache_store, output logic Found, ref bit [$clog2(Associativity_data_cache)-1:0] Current_way_data_cache, output MESI_state CurrentState);
	Found =  0;
	
	for (int i =0; i< Associativity_data_cache; i++ )
	begin
		
		if (Data_cache[iIndex][i].MESI_bits == Invalid)
		begin
			Current_way_data_cache = i;
			Found = 1;
			return;
		end
	end`ifdef mode2	
				$display("Return data to L2 address %h" , {iTag,iIndex, {Byte_offset_bits{1'b0}});
			`endif

endtask

task automatic Find_invalind_line_ins (logic [Index_bits - 1:0] iIndex, ref bit [$clog2(Associativity_instruction_cache)-1:0] Associativity_instruction_cache_store, output logic Found, ref bit [$clog2(Associativity_instruction_cache)-1:0] Current_way_instruction_cache, output MESI_state CurrentState);
	Found =  0;
	
	for (int i =0; i< Associativity_instruction_cache; i++ )
	begin
		
		if (Instruction_cache[iIndex][i].MESI_bits == Invalid)
		begin
			Current_way_instruction_cache = i;
			Found = 1;
			return;
		end
	end

endtask

//--Line Allocation------------------------------------------------------------------------------------------//

task automatic Allocate_line_data_cache (logic [Index_bits -1:0] iIndex, logic [Tag_bits -1 :0] iTag, ref bit [$clog2(Associativity_data_cache)-1:0] Current_way_data_cache);

	Data_cache[iIndex][Current_way_data_cache].Tag_bits = iTag;
	Update_LRU_bits_data_cache(iIndex, Associativity_data_cache_store , Current_way_data_cache);
	Data_cache[iIndex][Current_way_data_cache].MESI_bits = Shared;

endtask

task automatic Allocate_line_instruction_cache (logic [Index_bits -1 :0] iIndex, logic [Tag_bits -1 :0] iTag, ref bit [$clog2(Associativity_instruction_cache)-1:0] Current_way_instruction_cache);

	Instruction_cache[iIndex][Current_way_instruction_cache].Tag_bits = iTag;
	Update_LRU_bits_instruction_cache(iIndex, Associativity_instruction_cache_store , Current_way_instruction_cache);
	Instruction_cache[iIndex][Current_way_instruction_cache].MESI_bits = Shared;

endtask

//--Eviction----------------------------------------------------------------------------------------//


task automatic Eviction_data_cache(logic [Index_bits -1:0] iIndex, ref bit [$clog2(Associativity_data_cache)-1:0] Current_way_data_cache);

	for (int i =0; i< Associativity_data_cache; i++ )
	begin
		if (Data_cache[iIndex][i].LRU_bits ==  {($clog2(Associativity_data_cache)){1'b1}})
		begin
			if (Data_cache[iIndex][i].MESI_bits == Modified)
			begin
				`ifdef mode2
					$display("Write to L2 Address %h ", {Data_cache[iIndex][i].Tag_bits,iIndex,{ Byte_offset_bits{1'b0}}} );
				`endif

				`ifdef mode1
					$display("Write to L2 Address %h ", {Data_cache[iIndex][i].Tag_bits,iIndex,{ Byte_offset_bits{1'b0}}} );
				`endif
				
				Current_way_data_cache = i;
			end

			else
			begin
				Current_way_data_cache = i;
			end

		end

	end

endtask

task automatic Eviction_instruction_cache(logic [Index_bits - 1:0] iIndex, ref bit [$clog2(Associativity_instruction_cache)-1:0] Current_way_instruction_cache);

	for (int i =0; i< Associativity_instruction_cache; i++ )
	begin
		if (Instruction_cache[iIndex][i].LRU_bits ==  {$clog2(Associativity_instruction_cache){1'b1}})
		begin
			if (Instruction_cache[iIndex][i].MESI_bits == Modified)
			begin
				`ifdef mode2
					$display("Write to L2 Address %h ", {Instruction_cache[iIndex][i].Tag_bits,iIndex,{ Byte_offset_bits{1'b0}}} );
				`endif

				`ifdef mode1
					$display("Write to L2 Address %h ", {Instruction_cache[iIndex][i].Tag_bits,iIndex,{ Byte_offset_bits{1'b0}}} );
				`endif				
				Current_way_instruction_cache = i;
			end

			else
			begin
				Current_way_instruction_cache = i;
			end

		end

	end

endtask


//--Reading the trace files---------------------------------------------------
initial 
begin
	ClearCache();
    trace = $fopen(Tracefile , "r");
	while (!$feof(trace))
	begin
        display_temp = $fscanf(trace, "%h %h\n",Command,Address);
        {Tag,Index,Byte} = Address;
    
		case (Command)

			READ_L1_DATA_CACHE:   
			begin
				`ifdef mode2
					$display (" Op = %d, Address = %h, Set = %h, Tag = %h,", Command,Address, Index, Tag); 
				`endif
				function0(Tag, Index);
			end   
			
			WRITE_L1_DATA_CACHE:
			begin
				`ifdef mode2
					$display (" Op = %d, Address = %h, Set = %h, Tag = %h,", Command,Address, Index, Tag);
				`endif
				function1(Tag,Index);
			end

			READ_L1_INSTRUCTION_CACHE:   
			begin
				`ifdef mode2
					$display (" Op = %d, Address = %h, Set = %h, Tag = %h", Command,Address, Index, Tag); 
				`endif
				function2(Tag, Index);
			end

			INVALIDATE_COMMAND_L2:
			begin
				`ifdef mode2
					$display (" Op = %d, Address = %f, Set = %h, Tag = %h", Command,Address, Index, Tag);
				`endif
				function3(Tag,Index);
			end       
			
			DATA_REQUEST_L2:
			begin
				`ifdef mode2
					$display (" Op = %d, Address = %h, Set = %h, Tag = %h", Command,Address, Index, Tag);
				`endif
				function4(Tag,Index);
			end
		
			RESET:
			begin
				ClearCache();
			end

			PRINT:
			begin
				PRINT_CONTENTS();
			end

		endcase
	
	end

	Hit_ratio_update_data_cache();
	Hit_ratio_update_instruction_cache();

	`ifdef mode0
		$display(" CacheIteration \t \t = %d \n \n CacheRead of Data  \t \t = %d \n CacheMISS of Data \t \t = %d \n CacheHit of Data \t \t = %d \n CacheWrite of Data \t \t = %d \n CacheHITratio of Data \t = \t %f \n \n CacheRead of Instruction \t = %d \n CacheMISS of Instruction \t = %d \n CacheHit of Instruction \t = %d \n CacheHitRatio of Instruction  = \t %f \n", Cache_iterations , Read_counter_data_cache, Miss_counter_data_cache, Hit_counter_data_cache, Write_counter_data_cache, Hit_ratio_data_cache, Read_counter_instruction_cache, Miss_counter_instruction_cache, Hit_counter_instruction_cache, Hit_ratio_instruction_cache);
	`endif

	`ifdef mode1
		$display(" CacheIteration \t \t = %d \n \n CacheRead of Data  \t \t = %d \n CacheMISS of Data \t \t = %d \n CacheHit of Data \t \t = %d \n CacheWrite of Data \t \t = %d \n CacheHITratio of Data \t = \t %f \n \n CacheRead of Instruction \t = %d \n CacheMISS of Instruction \t = %d \n CacheHit of Instruction \t = %d \n CacheHitRatio of Instruction  = \t %f \n", Cache_iterations , Read_counter_data_cache, Miss_counter_data_cache, Hit_counter_data_cache, Write_counter_data_cache, Hit_ratio_data_cache, Read_counter_instruction_cache, Miss_counter_instruction_cache, Hit_counter_instruction_cache, Hit_ratio_instruction_cache);
	`endif

	`ifdef mode2
		$display(" CacheIteration \t \t = %d \n \n CacheRead of Data  \t \t = %d \n CacheMISS of Data \t \t = %d \n CacheHit of Data \t \t = %d \n CacheWrite of Data \t \t = %d \n CacheHITratio of Data \t = \t %f \n \n CacheRead of Instruction \t = %d \n CacheMISS of Instruction \t = %d \n CacheHit of Instruction \t = %d \n CacheHitRatio of Instruction  = \t %f \n", Cache_iterations , Read_counter_data_cache, Miss_counter_data_cache, Hit_counter_data_cache, Write_counter_data_cache, Hit_ratio_data_cache, Read_counter_instruction_cache, Miss_counter_instruction_cache, Hit_counter_instruction_cache, Hit_ratio_instruction_cache);
	`endif
	
	`ifdef mode2
		$display("End of line was detected.");
	`endif

	$finish;															
end




//---------------------------------------------------------------------------End of CODE------------------------------------------------------------------------------------------------------------------------//


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////