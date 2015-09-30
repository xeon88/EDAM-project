/*
    ************************
    PROGETTO EDAM
    Author: Marco Corona
    ***********************
*/

/*
    GLOBAL
*/

~global=(
  waves_carrier: 120,
  offset_freq: nil,
  pad_carrier: nil,
  bus: (
     waves: Bus.audio(s,2),
     water: Bus.audio(s,2),
     didger: Bus.audio(s,2)
  )

  melody_seq: nil,
  waves: nil,
  water: nil,
  didger:nil

);

/*
  SynthDef
*/

(

SynthDef(\waves,{ |numHarm=2 |
  var waves;
  waves=Mix.fill(numHarm,{
    arg index;
    var lf, rf , mod_amp, env;
    lf= (index+1)*~global[\waves_carrier]*PinkNoise.ar(0.05,1);
    rf= lf + ~global[\offset_freq];
    mod_amp=0.015*(1/(index+1)**2);
    SinOsc.ar([lf,rf],0,mod_amp);}
   );

  Out.ar(busnum,waves);
}).add;


SynthDef(\pad,{ |busnum |
  pad=Mix.fill(3,{
    arg index;
    var lf, rf , mod_amp;
    index=index+1;
    ~env=Env.new([0,0.5,0],[4-index,15-index,4-index],'sine',2,0);
    lf= (index)*pad_carrier;
    rf= lf + offset;
    mod_amp=0.015*(1/(index)**2);
    (Saw.ar([lf,rf]+Rand(-1,0),mod_amp) + Saw.ar([lf,rf]+ Rand(0,1),mod_amp,0) +LFTri.ar([lf,rf],0,mod_amp))*EnvGen.ar(~env);}
   );
  pad=pad*PinkNoise.ar(0.025,1);
  pad=BLowPass4.ar(pad,750,0.9);
  pad=CombC.ar(pad,0.35,SinOsc.kr(2,0,0.00005,0.3),1);
  pad=GVerb.ar(pad,20,2,0.6);

  Out.ar(busnum,pad);
}).add;


SynthDef(\wind, { |busnum|
  var wind;
  wind=BBandPass.ar(WhiteNoise.ar(0.01),SinOsc.ar(0.125,pi,550,550),0.75);
  Out.ar(busnum,wind);
}).add;


SynthDef(\water,{}).add;

SynteDef(\didger,{}).add;

SynthDef(\main,{}).add;

)