# pepper-points



Basic ideas:
1. Streams aren't real.
2. Having a single difficulty rating is inaccurate and utterly exploitable. Yet necessary.
3. Aim is aim, there is no "flow aim", or "jump aim". All motions your aim hand makes are from the same basic concept, from one position to the next. 
4. Aim's only scorable difficulty is precision, if a map is scaled to be 2x smaller - CS included - it should be the same difficulty and reward the same PP. Thus only scaling-invariant values such as aim angle-range can be used.
5. The only objects that can be scored are those that break combo when missed, such as slider ticks and circles. ( Spinners are iffy and ignored. )
6. Accuracy performance should not be left to the mappers discretion.

So far I believe there are 3 arguably quantifiable concepts. There may perhaps be more, or the sub categories split out.
* Aim
* Tapping
* Reading - debatable

All points are based on the assumption that a playthrough is perfect, any effort above the minimum required to SS the map is ignored. As such, snapping to notes is completely uncalculated, and only the minimum acceleration required to pass through each and every note is used. 

Sub categories as follow:

* Aim
  * Time spent over note 
    * Linear patterns are effectively difficult due to the decreased period of time available to hit them. 
  * Angle of approach 
    * The range of angles that would take you from one to the next. Effectively combines CS and distance into one to remove scaling issues.
* Tapping 
  * Accuracy
    * Rhythm Complexity   
      * Takes the variance of estimated BPM between hit objects in (arbitrary length after note) per note and average over entire map length. 
    * Instead of using a mapper-defined valued like OD, this will be calculated using the UR and a minimum applicable UR calculated using the Rhythm Complexity, thus any UR lower than that would be irrelevant, similar to SSing a map. However this would de-weight 1-2 jump spams, since they are not complex rhythmically. It would then most likely be calculated like
    >p = f(rhythm complexity);    
    >Value = g( p / Max( UR, p )  );
  * Strain
    * Since speed is quite literally a binary, "Can I hit that speed?", It is the total strain required which is the issue. However arguably strain increases with speed so it's somewhat involved anyway. Currently strain has an effective cap which is determined by the speed.
* Reading - uncertain, difficult due to relatively subjective view point
  * Spacing
    * Variance in spacing of notes currently on screen - this may over-weight spacing variant streams, but i doubt it
  * Note density & Overlaps - the major issue with this is sliders
    * Probably something like:
    >Total_Current_Overlap * Screen_Coverage * Note_Density

Little breakdown of calculations - feel free to make me look like an idiot:
* Time spent over note - "Aim Timing" for simplicity
    * Calculated from the maintainable velocity and required acceleration to reach the next circle - currently calculated wrong before .5pi rad
    >Time = 0.5 * CircleRadius / ( InitialSpeed + sqrt( InitialSpeed² + (2 * Acceleration * CircleRadius ) ) )
    * Used to calculate both entry and exit timing. 
* Angle of Approach
    > atan2( CircleRadius, Distance );
* Tapping Strain
    * Notes per second is estimated by time from previous note. 
    * Reduction Power is used to increase drop off, going from 1/4 to 1/2 could previously take a while to reflect in the strain. Weighting currently tuned to speed that up.
    > Strain = PreviousCircle.Strain - ( PreviousCircle.Strain / ( NotesPerSecond ^ Weighting.Strain.ReductionPower ) ) + NotesPerSecond
    * Currently calculated wrong for slider ticks, just defaults to 0. Is there strain for a slider tick?
* Aim Aggregate
    * Uses a relatively simple inverse curve. 
    > Aggregate = (a / ( (Timing^b) * (v.AimAngle^c) ))^d
    * b is currently 4 and c is currently 3. a is just a scale to bring it up to around 1. d is currently 0.7, but it's entirely arbitrary.
    * This causes linear patterns to outscale jumps of a similar distance spacing. Slightly.
* The rest to be finished.

## Turning those relatively arbitrary values into more arbitrary values - aka. turning those values into actual pp numbers. 

Currently we have the Aim Aggregate and Tapping Strain. There are 4 stages to calculating pp per note from these. The first stage is simply:
> InitialValue = AimAggregate * ( Strain ^ Weighting.Strain.RatioPower )

This produces quite large varying results, so we simply smooth by applying the average of the values from objects either side. Currently it's set to use 13, 6 objects from either side to smooth over. It then uses a secondary smoothing filter.

> n = v.SmoothValue + 1;  
> Value = LastCircle.WeightedValue - (LastCircle.WeightedValue / n^Weighting.Generic.SmoothingPower) + n;

This effectively requires harder sections to be more strainful for longer to maintain their strain.
From this we then calculate a doubt value. This takes the variance of strain from a number of objects either side, and generates a doubt value. For more strenuous sections, more notes are required, similar to the previous filter.  
> DoubtCap = MaxDoubtCap - ( (MaxDoubtCap - MinDoubtCap) / (2^(#Circles/DoubtObjCountScale)))  
> DoubtCap = DoubtCap * TotalDoubt / #Circles;  

Using this formula we calculate the maximum doubt value. Any values below this maintain their original weight, values above are re-weighted using:
> NewValue = CalculatedWeight * ( DoubtCap / Doubt )  

From this we then calculate the total value by applying this to all values:    
> Total += 10 ^ ( A * NewValue );  
> FinalMapValue = log( Total ) / log( 10 ^ A );  

Where A is currently 5. This applies a sort-of length bonus based on the consistent difficulty of the map. Multiple sections of similar difficulty, or one large section of a maintained difficulty, will slightly increase the total value. However it almost entirely ignores easier sections.


## Todo
* Implement genuinely not stupid numbers for individual statistics. 

## After thoughts
* Aim pp is scaled with combo, however acc pp is scaled entirely by acc, disregarding misses. Or at least, acc isn't scaled so deeply by combo. Frankly if you can't aim a map your accuracy will be garbage anyway. Would likely have to derank NF for this, since it may be possible to keep acc up except for the one bit of a map you can't pass

