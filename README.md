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
      * If there was any way I could apply an FFT to take the 
    * Instead of using a mapper-defined valued like OD, this will be calculated using the UR and a minimum applicable UR calculated using the Rhythm Complexity, thus any UR lower than that would be irrelevant, similar to SSing a map. However this would de-weight 1-2 jump spams, since they are not complex rhythmically. It would then most likely be calculated like
    >p = f(rhythm complexity);    
    >Value = g( p / Max( UR, p )  );
  * Strain
    * Since speed is quite literally a binary, "Can I hit that speed?", It is the total strain required which is the issue. Speed is also inherently weighted into rhythm complexity, since higher BPM will have larger changes, increasing variance.
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
* Strain
    * Notes per second is estimated by time from previous note. This is an exponential number, so log it or whatever.
    * Reduction Power is used to increase drop off, going from 1/4 to 1/2 could previously take a while to reflect in the strain. Weighting currently tuned to speed that up.
    > Strain = PreviousCircle.Strain - ( PreviousCircle.Strain / ( NotesPerSecond ^ Weighting.Strain.ReductionPower ) ) + NotesPerSecond
* The rest to be finished.

After thoughts:
* Aim pp is scaled with combo, however acc pp is scaled entirely by acc, disregarding misses. Or at least, acc isn't scaled so deeply by combo. Frankly if you can't aim a map your accuracy will be garbage anyway. Would likely have to derank NF for this, since it may be possible to keep acc up except for the one bit of a map you can't pass.