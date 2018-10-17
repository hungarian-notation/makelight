local ML = {}

--- The length of a beat (quarter-note) in ticks.
ML.TICKS_PER_BEAT 		= 48;

--- The length of a common time (4/4) measure in ticks.
ML.TICKS_PER_MEASURE	= ML.TICKS_PER_BEAT * 4

ML.UPDATE_RATE			= 48;

return ML;
