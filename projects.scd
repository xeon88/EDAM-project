/*
    ************************
    PROGETTO EDAM
    Author: Marco Corona
    ***********************
*/

/*
    Global variables Dictionary
*/
(
~global=(
  waves_carrier: 120, // pure tone frequency to create binaural
  offset_pad: 4.5, // freq offset between stereo channel into pad
  check: 1, // flag for pad routine
  bus: (  // private bus
     waves: Bus.audio(s,2),
     pad: Bus.audio(s,2),
     water: Bus.audio(s,2),
     waternoise: Bus.audio(s,1),
     grug:Bus.audio(s,1),
     didger: Bus.audio(s,2)
  ),
  main: nil, // main synth
  pad: nil,  // pad routine
  act_pad: nil, // pad actually played
  prev_pad:nil, // pad to be removed
  next_pad:nil, // next pad to be played
  waves: nil, // waves synth
  wind: nil, // wind synth
  water_rout: nil, // water routine
  water_synth: nil, // water synth
  didger_rout:nil // didgeridoo routine
);

)
/*
  SynthDef
*/


/*
SynthDef to make Binaural waves with frequencies in range [3,15] hz. Waves are gone with a soft wind
*/
(

SynthDef(\waves,{ |offset_freq=4.5|
  var waves;

  waves=Mix.fill(2,{
    arg index;
    var lf, rf , mod_amp, env;
    lf= (index+1)*~global[\waves_carrier];
    rf= lf + offset_freq;
    mod_amp=0.15*(1/(index+1)**2);
    SinOsc.ar([lf,rf],0,mod_amp);
    });
  Out.ar(~global[\bus][\waves].index,waves);
}).add;

/*
Abstract sound composed 3 base components :
2 SawTooth waves and 1 Triangular waves

Args:
 - freq - note to have to be played
*/

SynthDef(\pad,{ |freq|
  var pad;

  pad=Mix.fill(3,{
    arg index;
    var lf, rf , mod_amp;
    index=index+1;
    ~env=Env.new([0,1,0.7,0],[3/index,1/index,4/index,2/index],'sine',nil,0,0); // high harmonics has to last less than low harmonics and carrier freq
    lf= (index)*freq;
    rf= lf + ~global[\offset_pad] ; // set offest
    mod_amp=0.15*(1/(index)**2);
    (Saw.ar([lf,rf]+Rand(-1,0),mod_amp) +
     Saw.ar([lf,rf]+ Rand(0,1),mod_amp,0) +
     LFTri.ar([lf,rf],0,mod_amp))*EnvGen.ar(~env);}
   );
  pad=pad*PinkNoise.ar(0.025,1); // add noise to low frequencies
  pad=BLowPass4.ar(pad,750,0.9); // more soft sound
  pad=CombC.ar(pad,0.35,SinOsc.kr(2,0,0.0005,0.3),1); // add a slowness sensation through delay
  pad=GVerb.ar(pad,8,0.5,0.6); // add strong reverb
  Out.ar(~global[\bus][\pad].index,pad);
}).add;




SynthDef(\wind, {
  var wind;
  wind=Pan2.ar(BBandPass.ar(WhiteNoise.ar(0.025),SinOsc.ar(0.125,pi,300,390),0.75),SinOsc.ar(0.125,0,0.65,0));
  Out.ar(~global[\bus][\waves],[wind,wind]);
}).add;


/*
 Water SynthDef
*/


SynthDef(\grugling,{

  var triglobal, freq, grugling , freq_dust;

   freq_dust=170;
	 grugling={6.collect({

    triglobal = Dust.kr(freq_dust);
		freq =
			// Generally choose from a varied base freq
			TExpRand.kr(400,5000, triglobal)
			// Wobbly variation
			+ LFNoise0.kr(20, mul: 300)
    // General tendency for upward rise
    + EnvGen.kr(Env.perc(1).range(0,10), triglobal);
    SinOsc.ar(freq, Rand(0,pi), 0.1);
    }).mean;
  };
  grugling=BBandPass.ar(grugling,2000,1.5);
  Out.ar(~global[\bus][\grug].index,grugling);
}).add;


SynthDef(\waternoise,{

   var noise;

   noise=Mix.fill(3,{
   arg index;
   var freq;
    freq =100+1000*index+ Rand(0,0.125);
    SinOsc.ar(freq,0,0.05/(100*index+1)**2);
});

  noise=noise * WhiteNoise.ar(0.5);
  noise=BLowPass.ar(noise,2000,1.5);
  noise=GVerb.ar(noise,250,2.5,0.7,0.4,15,0.4);
  Out.ar(~global[\bus][\waternoise].index,noise);
}).add;



SynthDef(\water,{ |pos=0|

  var noise, grug , water, cp;

  noise=In.ar(~global[\bus][\waternoise].index,1);
  grug=In.ar(~global[\bus][\grug].index,1);
  water=noise+grug;
  Out.ar(~global[\bus][\water].index,Pan2.ar(water,pos));
}).add;


SynthDef(\didger,{ |bufnum|

Out.ar(~global[\bus][\didger].index,

        Pan2.ar(PlayBuf.ar(
					1, //# of channels
					bufnum, //# of the buffer to be played
					BufRateScale.kr(bufnum),//Scale the SampleRate to 44.1K
					//free the synth after playing
					doneAction: 2
       ),0)
	);


}).add;


SynthDef(\main,{ |pad_vol=0.15, waves_vol=0.1 ,water_vol=0.15 ,didger_vol=0.15|

  var in_pad, in_waves, in_water, in_didger, output;


  // collect from private pad bus
  in_pad=In.ar(~global[\bus] [\pad].index,2)*pad_vol;
  // collect from private waves bus
  in_waves=In.ar(~global[\bus][\waves].index,2)*waves_vol;
  // collect from private water bus
  in_water=In.ar(~global[\bus][\water].index,2)*water_vol;
  // collect from private didger bus
  in_didger=In.ar(~global[\bus][\didger].index,2)*didger_vol;

  output=in_pad + in_waves + in_water + in_didger;
  output=Limiter.ar(output,0.9);
  Out.ar(0,output);
}).add;

)

(

/*
  ROUTINES
*/

/*
Routine to generate pad sounds through a random note choose.
Since end of evelope routine provide to clean server from synth just be played

*/
~global[\pad]=Routine.new({
    inf.do({
    var freq , time_new_synth,time_free, pitches,
     check,variance;
    time_new_synth=5.5;


    pitches=[[60,56,55],[67,69,73],[68,64,63],[69,66,70],[70,71,73],[70,71,74],[72,73,59]];
      freq=Prand(pitches,inf).asStream; // Random note choose

    switch(~global[\check].value,
      1,{ // first iteration
      ~global[\act_pad]=Synth(\pad,[\freq,freq.next.midicps]);
      ~global[\prev_pad]=~global[\act_pad];
      ~global[\check]=~global[\check]+1;
      time_new_synth.yield;
      }, // second iteration
      2,{
      ~global[\act_pad]=Synth(\pad,[\freq,freq.next.midicps]);
      ~global[\check]=~global[\check]+1;
      time_new_synth.yield;
      },// third or more iteration
      3,{
      ~global[\next_pad]=Synth(\pad,[\freq,freq.next.midicps]);
      ~global[\prev_pad].free; // free old synth
      ~global[\prev_pad]=~global[\act_pad];
      ~global[\act_pad]=~global[\next_pad];
      time_new_synth.yield; // stop routine
      }
    );

  });

  });

/*
Routine to compute water sound
*/

~global[\water_rout]=Routine.new({

  20.do({
    x=Synth(\grugling);
  });
  y=Synth.after(x,\waternoise);
  ~global[\water_synth]=Synth.after(y,\water);
  //x.free;
  //y.free;
});


~global[\didger_rout] = Routine.new({

  var t1, wait;
  t1=Buffer.read(s,Platform.resourceDir +/+ "sounds/didg_3.wav");
  wait=21.89;
  inf.do({
   ~global[\didger_synth]=Synth(\didger,[\bufnum, t1.bufnum]);
   wait.yield;
  });
});

)

(


/**************************************************
*         GUI                                     *
**************************************************/

//var declaration
var window,
	frequencies_knob,
  freq_label,
  theta_freq,
  alpha_freq,
	screen,pos,
	slider_soundscape,
	r_lab,
	l_lab,
	l_t,
	r_t,
    water_knob,
    less_water,
    more_water,
    water_label,

    pad_knob,
    less_pad,
    more_pad,
    pad_label,

    waves_knob,
    less_waves,
    more_waves,
    waves_label,

    didg_knob,
    less_didg,
    more_didg,
    didg_label,

playStop,
    stethoscope,

pad_v,
wav_v,
did_v ,
wat_v,
bin_c,
wat_p;

/**
* INITIALIZATION
*
*/

// main container
window = GUI.window.new("Progetto Corona Marco", Rect(10,0,1200, 800)) ;

// screen as background
screen = GUI.compositeView.new(window,Rect(0,0, 1200,800));

stethoscope = Stethoscope.new(s, zoom:50,view:window.view);
stethoscope.view.bounds = Rect(0,0,1200,500);
stethoscope.view.background= Color.blue;


//Button for toggling the sound on/off
playStop = GUI.button.new(window, Rect(630,50,100,50)).states_([
		["Play",Color.black,Color.white],
		["Stop",Color.white,Color.black]
]);



/*Offset frequencies controller*/
frequencies_knob = GUI.knob.new(window, Rect(150, 215, 100, 100)) ;
frequencies_knob.value = 0.3;
frequencies_knob.color = frequencies_knob.color.put(1,Color.blue);
frequencies_knob.color = frequencies_knob.color.put(3,Color.black);

theta_freq= GUI.staticText.new(window, Rect(50,260,100,50) );
theta_freq.string="theta";
theta_freq.stringColor=Color.white;
alpha_freq= GUI.staticText.new(window, Rect(300,260,100,50) );
alpha_freq.string="alpha";
alpha_freq.stringColor=Color.white;

freq_label= GUI.staticText.new(window, Rect(150,340,100,50) );
freq_label.string="WAVES TYPE";
freq_label.stringColor=Color.white;


/*Stereo pad panning control*/
slider_soundscape = Slider(window, Rect(50, 120, 200, 20));
slider_soundscape.value=0.5;
//labels for panning control
l_lab= GUI.staticText.new(window, Rect(50,130,100,50) );
l_lab.string="Left";
l_lab.stringColor=Color.white;
r_lab= GUI.staticText.new(window, Rect(230,130,100,50) );
r_lab.string="Right";
r_lab.stringColor=Color.white;
pos= GUI.staticText.new(window, Rect(120,140,100,50) );
pos.string="WATER PAN";
pos.stringColor=Color.white;




/* Water control*/

water_knob = GUI.knob.new(window, Rect(900, 215, 100, 100)) ;
water_knob.value = 0.5;
water_knob.color = water_knob.color.put(1,Color.blue);
water_knob.color = water_knob.color.put(3,Color.black);

//labels for water
less_water= GUI.staticText.new(window, Rect(905,260,100,50) );
less_water.string="-";
less_water.stringColor=Color.white;
more_water= GUI.staticText.new(window, Rect(955,260,100,50) );
more_water.string="+";
more_water.stringColor=Color.white;
water_label= GUI.staticText.new(window, Rect(900,340,100,50) );
water_label.string="WATER VOLUME";
water_label.stringColor=Color.white;





/* waves control*/

waves_knob = GUI.knob.new(window, Rect(750, 215, 100, 100)) ;
waves_knob.value = 0;
waves_knob.color = waves_knob.color.put(1,Color.blue);
waves_knob.color = waves_knob.color.put(3,Color.black);

//labels for waves
less_waves= GUI.staticText.new(window, Rect(755,260,100,50) );
less_waves.string="-";
less_waves.stringColor=Color.white;
more_waves= GUI.staticText.new(window, Rect(805,260,100,50) );
more_waves.string="+";
more_waves.stringColor=Color.white;
waves_label= GUI.staticText.new(window, Rect(750,340,100,50) );
waves_label.string="WAVES VOLUME";
waves_label.stringColor=Color.white;

/* pad control */

pad_knob = GUI.knob.new(window, Rect(600, 215, 100, 100)) ;
pad_knob.value = 0;
pad_knob.color = pad_knob.color.put(1,Color.blue);
pad_knob.color = pad_knob.color.put(3,Color.black);


//labels for pad
less_pad= GUI.staticText.new(window, Rect(605,260,100,50) );
less_pad.string="-";
less_pad.stringColor=Color.white;
more_pad= GUI.staticText.new(window, Rect(655,260,100,50) );
more_pad.string="+";
more_pad.stringColor=Color.white;
pad_label= GUI.staticText.new(window, Rect(600,340,100,50) );
pad_label.string="PAD VOLUME";
pad_label.stringColor=Color.white;

/* didgeridoo control*/

didg_knob = GUI.knob.new(window, Rect(450, 215, 100, 100)) ;
didg_knob.value = 0;
didg_knob.color = didg_knob.color.put(1,Color.blue);
didg_knob.color = didg_knob.color.put(3,Color.black);

//labels for didgeridoo
less_didg= GUI.staticText.new(window, Rect(455,260,100,50) );
less_didg.string="-";
less_didg.stringColor=Color.white;
more_didg= GUI.staticText.new(window, Rect(505,260,100,50) );
more_didg.string="+";
more_didg.stringColor=Color.white;
didg_label= GUI.staticText.new(window, Rect(450,340,100,50) );
didg_label.string="YIDAKI VOLUME";
didg_label.stringColor=Color.white;




  // map from 0..1 to other ranges
  pad_v=ControlSpec.new(0.0,0.5, \lin, 0.01);
  wav_v=ControlSpec.new(0.0,0.2, \lin, 0.01);
  did_v=ControlSpec.new(0.0,0.5, \lin, 0.01);
  wat_v=ControlSpec.new(0.0,0.5, \lin, 0.01);
  wat_p=ControlSpec.new(-1.0,1.0, \lin, 0.01);
  bin_c = ControlSpec(3, 15, \linear, 0.5);

/**
* ACTIONS
*
*/

//controller for the stereo position of pad
slider_soundscape.action={|sl| if(~global[\main].isRunning == true,{ ~global[\water_synth].set(\pos,wat_p.map(sl.value));
  wat_p.map(sl.value).postln;
})};
//controller for the frequencies waves
frequencies_knob.action = {|i| if(~global[\main].isRunning == true,{~global[\waves].set(\offset_freq, bin_c.map(i.value))})};
//controller for the water volume
water_knob.action = {|i| if(~global[\main].isRunning == true,{~global[\main].set(\water_vol, wat_v.map(i.value));
})};
//controller for the pad volume
pad_knob.action = {|i| if(~global[\main].isRunning == true,{~global[\main].set(\pad_vol, pad_v.map(i.value))})};
//controller for the waves volume
waves_knob.action = {|i| if(~global[\main].isRunning == true,{~global[\main].set(\waves_vol,wav_v.map(i.value))})};
//controller for the didgeridoo volume
didg_knob.action = {|i| if(~global[\main].isRunning == true,{~global[\main].set(\didger_vol,did_v.map(i.value))})};

//TOGGLE sound ON/OFF
playStop.action = {|x|

	if ( x.value == 0, {
		//if stopped
		~global[\wind].free; //destroy the wind synth
		~global[\pad].stop; //stop pad
		~global[\water_synth].free; //stop water
    ~global[\water_rout].stop; //stop water
    ~global[\waves].free; //stop waves
    ~global[\didger_rout].stop; //stop didger routine
		~global[\didger_synth].free; //free didger synth
    ~global[\main].free;
    s.freeAll;

	},
	{ //else (if played)
      ~global[\waves]=Synth(\waves,[\offset_freq, frequencies_knob.value]);
    ~global[\wind]=Synth.after(~global[\waves],\wind);
      ~global[\main]=Synth.after(~global[\wind],\main,[\pad_vol,pad_knob.value, \waves_vol,waves_knob.value ,\water_vol,water_knob.value,\didger_vol,didg_knob.value]);
    ~global[\pad].reset;
    ~global[\pad].play(SystemClock);
    ~global[\didger].reset;
    ~global[\didger].play(SystemClock);
		//create a node watcher for meaningfull isRunning
		NodeWatcher.register(~global[\main], true);
    ~global[\water_rout].reset;
    ~global[\water_rout].play(SystemClock);

	});
};


window.onClose = {
	if ( ~global[\main].isRunning == true,{
		~global[\main].free;
  }
  );
  ~global[\didger_rout].stop; //stop didger routine
	~global[\didger_synth].free; //stop didger synth
  ~global[\pad].stop; //stop the pad routine
	~global[\water_synth].free;
  ~global[\water_rout].stop;
  ~global[\waves].free; //stop waves
	~global[\wind].free; //destroy the wind synth
  stethoscope.free;
  s.freeAll;
};
window.front ;

)
s.scope;
s.queryAllNodes;

(
~global[\pad].stop;
~global[\didger].stop;
~global[\water_rout].stop;
s.freeAll;
s.queryAllNodes;
)