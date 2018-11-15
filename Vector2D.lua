local Vector2D;Vector2D = {
	new = function(x,y) return setmetatable({x=x or 0;y=y or 0},Vector2D.mt); end;
	magnitude = function( p1, p2 ) if( not p2) then p2 = {x=0;y=0} end return math.sqrt(((p1.x-p2.x)^2) + ((p1.y-p2.y)^2)) end;	
	velocity = function( p1, p2, time )			
			return Vector2D.new( ( p1.x - p2.x ) / time, ( p1.y - p2.y ) / time ) 
		end;
	scale = function( v, m )
		return Vector2D.new( v.x * m, v.y * m );
	end;
	angle = function( p1, p2 )
		return ( math.atan2( p2.y, p2.x ) - math.atan2( p1.y, p1.x ) + math.pi ) % 360;
	end;
	anglebetween = function( p2, p1, p3 )
		local p12 = p2:magnitude( p1 );
		local p23 = p2:magnitude( p3 );
		local p31 = p1:magnitude( p3 );
		local angle = math.acos( ((p12^2) + (p23^2) - (p31^2)) / (2 * p12 * p31 ) );
		return angle;
	end;
	mt = {
		__mul = function( p1, p2 )
			if( type(p1):lower() == "number" )then
				return p2:scale( p1 );
			end
			if( type(p2):lower() == "number" )then
				return p1:scale( p2 );
			end
			error( "dumbass" );
		end;
		__sub = function( p1, p2 )
			return Vector2D.new( p1.x - p2.x, p1.y - p2.y );
		end
		
		};	
	}
Vector2D.mt.__index = Vector2D;
return Vector2D;