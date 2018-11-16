local Mods = { HT, DT, HR, EZ, HD, FL }

local DoGraphs = true;

local Output = io.open( "stuff.csv", "w" );
function WriteCSV( ... )	
	Output:write( table.concat({...},",").."\n" );
end

local ObjectTypes = {
	Circle = 0;
	Slider = 1;
	Spinner = 3;
};

local Vector2D = require( 'Vector2D' );

function ObjectTypeFromMask( Mask )
	Mask = tonumber( Mask );
	if( Mask > 4 and Mask < 8 ) then Mask = Mask -4 end
	return math.log(Mask%8)/math.log(2);
end

local _iter = function(a, i)
	i = i + 1
	local v = a[i]
	if v then
		return i, v
	end
end   

local Weighting = {
	Generic = {
		Smoothing = 6; -- values from either side to smooth in
		SmoothingPower = 2; -- uses to weight the moving average
		ConfidencePower = 2; -- Used to determien how many objects are used to calculate the variance
		ConfidenceScale = 15; -- ditto
		ConfidenceCap = 1.5; -- used to determine the largest confidence variance value allowed
		ConfidenceVariancePower = 4; 
	};
	Aim = {
		Circles = {
			Scale = 10000;
			TimingPower = 3;
			PrecisionPower = 1.5;
			Aggregate = 0.3;
			};
		Spinners = {
			KEKSpinnersLUL = 0;
			};
		};
	Focus = {
		NoteDensity = 1;
		};
	Strain = {
		ScalePower = 3;
		RatioPower = 0.5;
		ReductionPower = 3;
		};
	RhythmComplexity = {
		Length = 1000;
		BPMScaler = 600;
		};
	Reading = {
		
		};
	Acc = {
	
		};
	};

local Calculations = {
	NoteDensity = function( map, GraphData )
			local objects = map.Objects;
			local AR = map.ApproachTime;
			local Total = 0;
			local Count = 0;
			-- gets the average note density on screen per note
			for i, v in ipairs( objects ) do
				if( not v.SliderTick )then
					Count = Count + 1;
					local m = AR + v.Time;
					local n = 0;
					for j, k in _iter, objects, i do
						if k.Time > m then
							n = j - i;
							break;
						end
					end
					v.NoteDensity = n * Weighting.Focus.NoteDensity;
					Total = Total + n;
				end
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {};end
					table.insert( GraphData[i], v.NoteDensity or 0 );
				end		
			end
			return (Total / Count) * Weighting.Focus.NoteDensity;
		end;
	RhythmComplexity = function( map, GraphData )
			local objects = map.Objects;
			local AR = Weighting.RhythmComplexity.Length;
			local Total = 0;
			local Count = 0;
			-- gets the average rhythm complexity in (arbitrary length) per note
				
			for i, v in ipairs( objects ) do
				if( not v.SliderTick )then
					
					local m = AR + v.Time;
					local n = 0;
					local n2 = 0;
					local lt = v.Time;
					local C = 0;
					for j, k in _iter, objects, i do
						if k.Time < m then
							local x = ( Weighting.RhythmComplexity.BPMScaler/(( k.Time - lt )) );
							--print( x );
							n = n + x;
							n2 = n2 + (x^2);
							lt = k.Time;
						else C = j - i;break;
						end
					end

					if( C ~= 0 ) then
						local A = (n / C)^2;
						local X = n2 / C;
						local V = X - A;
						Count = Count + C;
						Total = Total + V;					
						v.RhythmComplex = V;
						--print( v.Time .. " : " .. n .. " : " .. A .. " : " .. X .. " : " .. V .. " : " .. C );
					end
					--print( Total .. " : " .. Total2 );
				end
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {};end
					table.insert( GraphData[i], v.RhythmComplex or 0 );
				end				
			end
			local Average = (Total / Count);
			-- get variance
			--local Variance = (Total2/Count) - (Average^2);
			return Average;--math.abs(Variance);
		end;
	AimAngle = function( map, GraphData )
			local LastCircle = nil;
			local Circles = map.Objects;
			local AngleDiff = 0;
			for i, v in ipairs( Circles ) do
				if LastCircle then
					local Distance = 0;
					local ApproachAngle = math.pi;
					
					local TDiff = ( v.Time - LastCircle.Time );
					if TDiff == 0 then	
						TDiff = 1;
					end
					Distance = v.Position:magnitude( LastCircle.Position );
					--v.AverageVelocity = v.Position:velocity( LastCircle.Position, TDiff );
					local RawAngle = math.atan2( map.CircleRadius, Distance );
					--ApproachAngle = math.log( 1 / RawAngle ) / math.log( Weighting.Aim.Circles.AngleLog ) / TDiff;
					--print( v.Time .. " : " .. ApproachAngle .. " : " .. Distance .. " : ( "..v.Position.x .. ", " .. v.Position.y .. " ) " .. " : " .. AngleDiff / i );
					--v.AimAngle = ApproachAngle * Weighting.Aim.Circles.Angle ;	
					v.AimAngle = RawAngle;
					--AngleDiff = AngleDiff + ( ApproachAngle ^ Weighting.Aim.Circles.AnglePower );
				else	
					v.AimAngle = math.pi;--(math.log( .5 ) / math.log( Weighting.Aim.Circles.AngleLog )) * Weighting.Aim.Circles.Angle;
				end
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {};end
					table.insert( GraphData[i], v.AimAngle );
				end				
				LastCircle = v;							
			end
			return "sorry"; --Weighting.Aim.Circles.AngleScale * math.log( Weighting.Aim.Circles.Angle * AngleDiff / #Circles ) / math.log( Weighting.Aim.Circles.TotalLog );				
		end;			
	AimAggregate = function ( map, GraphData )
			local Circles = map.Objects;
			local Total = 0;
			local lt;
			for i, v in ipairs( Circles ) do
				if( lt )then
					
					local ExTiming = v.ExitTime or (map.MaxHitTime / 2);
					local EnTiming = ( v.EnterTime );
					
					local Timing = ExTiming + EnTiming;
					
					local Weight = Weighting.Aim.Circles.Scale / ( (Timing^Weighting.Aim.Circles.TimingPower) * (v.AimAngle ^ Weighting.Aim.Circles.PrecisionPower) )
					--(Weighting.Aim.Circles.AngleSpike * Weighting.Aim.Circles.AngleScale * v.AimAngle / math.log( Weighting.Aim.Circles.TotalLog );				
					--print( Weight .. " : " .. v.AimAngle );
					--print( (v.ExitTime or v.EnterTime) .. " : ".. (v.EnterTime or v.ExitTime) .. " : " .. i );			
					
					--print( Weight .. " : " .. Timing .. " : " .. v.AimAngle );
					
					local TDiff = v.Time - lt.Time;
					Weight = Weight / TDiff;
					
					Weight = Weight ^ Weighting.Aim.Circles.Aggregate;
					v.AimAggregate = Weight;
					Total = Total + Weight;
					--print( Total / i );
				else
					v.AimAggregate = 0;
				end
				lt = v;				
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {}; end
					table.insert( GraphData[i], v.AimAggregate or 0 );
				end		
			end
			return Total / #Circles;
		end;
	Total = function( map, GraphData )
			local Circles = map.Objects;
			local Total = 0;
			for i, v in ipairs( Circles ) do
				local Value = v.AimAggregate * ( v.Strain ^ Weighting.Strain.RatioPower );
				v.InitialValue = Value;
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {}; end
					table.insert( GraphData[i], Value );
				end		
			end
			-- smooth
			for i, v in ipairs( Circles ) do
				local Value = 0;
				for j = i - Weighting.Generic.Smoothing, i + Weighting.Generic.Smoothing do
					if( Circles[j] )then
						Value = Value + Circles[j].InitialValue;
					end
				end
				Value = Value / ( 1 + Weighting.Generic.Smoothing * 2 );
				v.SmoothValue = Value;
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {}; end
					table.insert( GraphData[i], Value );
				end		
			end
			-- moving average
			local LastCircle;
			for i, v in ipairs( Circles ) do				
				if( LastCircle )then
					local n = v.SmoothValue + 1;
					local V = LastCircle.WeightedValue - ( LastCircle.WeightedValue / n^Weighting.Generic.SmoothingPower) + n;
					v.WeightedValue = V;
				else	
					-- treated as if the last value was 0
					v.WeightedValue = v.SmoothValue + 1;
				end
				Total = Total + (v.WeightedValue^2);
				v.CalculatedWeight = (v.WeightedValue^(1/(Weighting.Generic.SmoothingPower+1) ))-1;
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {}; end
					table.insert( GraphData[i], v.CalculatedWeight );
				end		
				LastCircle = v;
			end
			local MovingAverageValue = ( Total / #Circles )^(1/(Weighting.Generic.SmoothingPower+1)) - 1;
			-- confidence
			Total = 0;
			for i, v in ipairs( Circles ) do
				local ActualWeight = v.CalculatedWeight;
				local RequiredCount = math.ceil( Weighting.Generic.ConfidenceScale * (ActualWeight ^ Weighting.Generic.ConfidencePower) );
				local X = 0;
				local X2 = 0;
				local Count = 0;
				for j = i - RequiredCount, i + RequiredCount do
					if( Circles[j] )then
						Count = Count + 1;
						X = X + Circles[j].WeightedValue;
						X2 = X2 + (Circles[j].WeightedValue^2);
					end
				end
				
				local X2C = (X2/Count);
				local Average = (X/Count);
				local Variance = ( X2C - (Average^2) )^(1/Weighting.Generic.ConfidenceVariancePower);
				v.Confidence = Variance;
		
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {}; end
					table.insert( GraphData[i], v.Confidence );
				end		
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {}; end
					table.insert( GraphData[i], Count );
				end		
				Total = Total + Variance;
			end
			
			local ConfidenceCap = Weighting.Generic.ConfidenceCap * Total / #Circles;
			-- quick run through to get the best value
			local Value = 0;
			for i, v in pairs( Circles ) do
				if( v.Confidence < ConfidenceCap and v.CalculatedWeight > Value )then
					Value = v.CalculatedWeight;
				end
				if( GraphData )then
					if( not GraphData[i] ) then GraphData[i] = {}; end
					table.insert( GraphData[i], v.Confidence < ConfidenceCap and v.CalculatedWeight or 0 );
				end		

			end
			print( "Confidence Cap: " .. ConfidenceCap );
			return Value;
		end;
	Strain = function( map, GraphData )
		local LastCircle;
		local Total = 0;
		local Count = 0;
		for i, v in ipairs( map.Objects ) do
			if( LastCircle )then
				if( v.SliderTick )then
					v.Strain = 0;
				else	
					local TDiff = v.Time - LastCircle.Time;
					if( TDiff == 0 )then
						--print( "fuck off 2b cunt" );
						TDiff = 1;
					end
					if( TDiff > 1000 )then
						v.Strain = 0;
					else
						local TPS = 1000 / TDiff;
						v.Strain = LastCircle.Strain - ( LastCircle.Strain / (TPS^(1/Weighting.Strain.ReductionPower)) ) + ( TPS );
					end
					Total = Total + v.Strain;
					Count = Count + 1;
				end
			else	
				v.Strain = 0;
				Count = Count + 1;
			end
			if( GraphData )then
				if( not GraphData[i] ) then GraphData[i] = {}; end
				table.insert( GraphData[i], v.Strain or 0 );
			end		
			LastCircle = not v.SliderTick and v or not LastCircle and v or LastCircle;
		end
		return Total / Count;
	end;
	AimTiming = function( map, GraphData )
			local LastCircle = nil;
			local Circles = map.Objects;
			local Total = 0;
			
			local function TimeOverNote( InitialSpeed, Acceleration, Rad )
				local t = .5 * Rad / ( InitialSpeed + math.sqrt( (InitialSpeed^2) + 2*Acceleration*Rad ) )
				return t;
			end
			
			for i, v in ipairs( Circles ) do
				local NextCircle = Circles[i + 1];
				if LastCircle then
					local Distance = v.Position:magnitude( LastCircle.Position );
					if( Distance == 0 ) then 
						v.Velocity = Vector2D.new();
						v.EnterTime = v.Time - LastCircle.Time;
						LastCircle.ExitTime = v.EnterTime;
					else
						local TDiff = ( v.Time - LastCircle.Time );
						if TDiff == 0 then	
							TDiff = 1;
						end
						local AverageVelocity = v.Position:velocity( LastCircle.Position, TDiff );				
						--local AverageVelocity = Distance / TDiff;					
						--local RequiredAcceleration = AverageVelocity - LastCircle.Velocity;
						local MaintainedVelocity;
						if( NextCircle ) then
							local NTDiff = ( NextCircle.Time - v.Time );
							if NTDiff == 0 then	
								NTDiff = 1;
							end
							local AverageExitVelocity = NextCircle.Position:velocity( v.Position, NTDiff );
							local AngleBetween = v.Position:anglebetween( LastCircle.Position, NextCircle.Position ); 
							local Mult = -math.cos( AngleBetween );
							--v.AngleToNext = 
							if( Mult > 0 )then
								MaintainedVelocity = AverageVelocity * Mult;	
								--print( MaintainedVelocity );
							else 
								MaintainedVelocity = Vector2D.new();
							end;
						else
							MaintainedVelocity = AverageVelocity;
						end
						local RequiredDeltaV = ( MaintainedVelocity - AverageVelocity );						
						local RequiredDeltaV2 = ( AverageVelocity - LastCircle.Velocity );
						local RDVMag = RequiredDeltaV:magnitude()
						local RDV2Mag = RequiredDeltaV2:magnitude();
						
						local Ratio = RDV2Mag / ( RDV2Mag + RDVMag );
						local Rad = map.CircleRadius;
						
						local ExitTim = TimeOverNote( LastCircle.Velocity:magnitude(), Ratio == 0 and 0 or RequiredDeltaV2:velocity( Vector2D.new(), Ratio * TDiff ):magnitude(), map.CircleRadius );
						local EnterTim = TimeOverNote( MaintainedVelocity:magnitude(), Ratio == 1 and 0 or RequiredDeltaV:velocity( Vector2D.new(), ( 1- Ratio) * TDiff ):magnitude(), map.CircleRadius );
							
						LastCircle.ExitTime = ExitTim;
						
						v.EnterTime = EnterTim;
						v.Velocity = MaintainedVelocity;
						--print( MaintainedVelocity );
						--print( v.Time .. " : " .. Total .. " : " .. EnterTim .. " : " .. ExitTim .. " : " .. RDVMag .. " : " .. RDV2Mag .. " : " .. LastCircle.Velocity:magnitude() .. " : " .. MaintainedVelocity:magnitude() .. " : " .. RequiredDeltaV2:magnitude() .. " : " .. RequiredDeltaV:magnitude());
						Total = Total + ExitTim + EnterTim;
					end
				else
					v.Velocity = Vector2D.new();
				end
				if( GraphData )then
					local Timing = (( (LastCircle or {}).ExitTime or 0 ) + ( v.EnterTime or 0 ));
					--print(tostring(LastCircle.ExitTime ).. " : " ..tostring(v.EnterTime ) )
					if( not GraphData[i] ) then GraphData[i] = {};end
					--table.insert( GraphData[i], v.Velocity and v.Velocity:magnitude() or 0 );
					table.insert( GraphData[i],  Timing );
				end			
				LastCircle = v;						
			end
			return "also sorry"; --Total / #Circles;
		end;
	}

-- peppster why
function GetApproachTimeFromRate( Rate )
	if( Rate < 5 )then
		return 1800 - ( Rate * 120 );
	else		
		return 1950 - ( Rate * 150 );
	end
end

function GetMaxHitTimeFromOD( OD )
	return 2 * ( 199.5 - ( 10 * OD ) );
end
	
function ReadMap( Path, Mods )
	local Map = io.open( Path );
	assert( Map );
	local Result = {};
	local MapText = Map:read("*all");
	local ObjectsChunk = MapText:match( "%[HitObjects%](.*)" );
	local TimingChunk = MapText:match( "%[TimingPoints%](.*)%[.-%]" );
	local Objects = {}
	local RawObjects = {}
	local Timing = {}
	-- read map


	Result.ApproachRate = tonumber(MapText:match( "ApproachRate:.-([%d.]+)"));
	Result.CircleSize = tonumber(MapText:match( "CircleSize:.-([%d.]+)"));
	Result.OverallDifficulty = tonumber(MapText:match( "OverallDifficulty:.-([%d.]+)")); 
	Result.SliderMultiplier = tonumber(MapText:match( "SliderMultiplier:.-([%d.]+)"));
	Result.SliderTickRate = tonumber(MapText:match( "SliderTickRate:.-([%d.]+)"));
	Result.SongName = MapText:match( "Title:([^\n]+)");
	Result.DiffName = MapText:match( "Version:([^\n]+)");

	local Graph = DoGraphs and io.open( "graphs/" .. Result.SongName ..  "-"   ..Result.DiffName .. ".csv", "w");

	Result.Objects = Objects;
	for x, y, time, type, hitsound, extras in ObjectsChunk:gmatch(("(%d+),"):rep(5).."(%S+)") do
		table.insert( RawObjects, 
			{
			Position = Vector2D.new( tonumber(x), tonumber(y) );
			Time = tonumber(time);
			Type = ObjectTypeFromMask(type);
			Extras = extras;
			})
	end
	
	for i, v in pairs(RawObjects) do
		if( v.Type < 2 )then -- circle/slider
			table.insert( Objects, v );
		end
	end
		
	Result.Timing = Timing;
	for time, sv in TimingChunk:gmatch("([%d.]+),(%S-),%S+" ) do
		table.insert( Timing, {
			time = tonumber( time );
			sv = tonumber( sv );
			})
	end
	
	-- do some quick calculations and sorting
	local function sort_f( a, b )
		return (a.Time < b.Time) ;
	end
	
	print( "Name: " .. Result.SongName );
	print( "Diff: " .. Result.DiffName );
	table.sort( Objects, sort_f );
	
	print( "Circle Count: " .. #Objects );
	local Length = Objects[#Objects].Time - Objects[1].Time;	
	print( "Length: " .. Length );
	Result.Length = Length;

	Result.ApproachTime = GetApproachTimeFromRate( Result.ApproachRate );
	Result.CircleRadius = 100 - ( Result.CircleSize * 9 );
	Result.MaxHitTime = GetMaxHitTimeFromOD( Result.OverallDifficulty );
	
	-- get base values
	
	local BaseValues = {};
	Result.BaseValues = BaseValues;
	local GraphData = {};
	BaseValues.NoteDensity = Calculations.NoteDensity( Result, GraphData );
	BaseValues.RhythmComplexity = Calculations.RhythmComplexity( Result, GraphData );
	BaseValues.AimAngle = Calculations.AimAngle( Result, GraphData );
	BaseValues.AimTiming = Calculations.AimTiming( Result, GraphData );
	BaseValues.AimAggregate = Calculations.AimAggregate( Result, GraphData );
	BaseValues.Strain = Calculations.Strain( Result, GraphData );
	BaseValues.TotalWeight = Calculations.Total( Result, GraphData );
	
	if( Graph ) then
		Graph:write( "Time, Note Density,Rhythm Complexity,Aim Angle,Aim Timing,Aim Aggregate,Strain,Individual Value,Smoothed Value,Value,Cheese,X\n" );
		for i, v in ipairs( GraphData ) do
			Graph:write( Objects[i].Time .. "," .. table.concat( v, "," ) .. "\n" );
		end
	end

	print( "Note Density: " .. BaseValues.NoteDensity );
	print( "Rhythm Complexity: " .. BaseValues.RhythmComplexity );
	print( "Aim Angle(Precision): " .. BaseValues.AimAngle );
	print( "Aim Timing(Flow?): " .. BaseValues.AimTiming );
	print( "Aim Aggregate: " .. BaseValues.AimAggregate );
	WriteCSV( Result.SongName, Result.DiffName, #Objects, Length, #Objects/Length * 1000, Result.ApproachRate, Result.CircleSize, BaseValues.NoteDensity, BaseValues.RhythmComplexity, BaseValues.AimAngle, BaseValues.AimTiming, BaseValues.AimAggregate, BaseValues.Strain, BaseValues.TotalWeight );

	if( Graph and Graph:close()) then end
	return Result;
end

--local FilePath = 
--local FilePath = 
--local FilePath = ;
--local FilePath = ;
local Paths = {
--[[]]
"316050 DragonForce - Cry Thunder\\DragonForce - Cry Thunder (Jenny) [Legend].osu";
"352570 beatMARIO - Night of Knights\\beatMARIO - Night of Knights (alacat) [The World].osu"; 
"798007 Will Stetson - Despacito ft R3 Music Box\\Will Stetson - Despacito ft. R3 Music Box (Sotarks) [Insane].osu"; 
"Infected Mushroom - The Rat [HD] (192  kbps)\\Infected Mushroom - The Rat (icecream-chan) [Marathon].osu";

"153887 Akiyama Uni - Odoru Mizushibuki\\Akiyama Uni - Odoru Mizushibuki (Hollow Wings) [Death Dance].osu";
"518737 Kanae Asaba - Endless Starlight ~Inochi no Kirameki~ (OP ver)\\Kanae Asaba - Endless Starlight ~Inochi no Kirameki~ (OP ver.) (Monstrata) [Master].osu";
"669232 EGOIST - Lovely Icecream Princess Sweetie\\EGOIST - Lovely Icecream Princess Sweetie (Deramok) [Addiction].osu";
--

"414667 Suara - Amakakeru Hoshi TV ver\\Suara - Amakakeru Hoshi TV ver. (Taeyang) [Masquerade].osu";

"357466 ARCIEN - Future Son\\ARCIEN - Future Son (Mishima Yurara) [N A S Y A'S OK DAD].osu"; 
"Karthy+-+Despacito+III\\Karthy - Despacito III (dt is bad) [no].osu";
"158023 UNDEAD CORPORATION - Everything will freeze\\UNDEAD CORPORATION - Everything will freeze (Ekoro) [Time Freeze].osu";
"383094 Franz Liszt - La Campanella (8 Bit Remix)\\Franz Liszt - La Campanella (8 Bit Remix) (Louis Cyphre) [Grande Etude].osu";
--]]
"586121 GYZE - HONESTY\\GYZE - HONESTY (Bibbity Bill) [DISHONEST].osu"; 


}

WriteCSV( "Song Name,Diff Name,Circle Count,Length,Unweighted density,Approach Rate,Circle Size,Note Density,Rhythm Complexity (and sort of speed aswell?),Average Aim Angle,Average Aim Timing,Average Aim,Tap Strain,Total Weight" );
for i, FilePath in ipairs( Paths ) do
	
	print( "----------------------------------" );

	local Map = ReadMap( "O:\\OsuInstall\\Songs\\"..FilePath );
end