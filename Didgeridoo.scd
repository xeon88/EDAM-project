

/*
  Declaration of global var
*/
(
~global=(
  low_amplitudetable: nil,  /*coefficients for low frequencies*/
  high_amplitudetable: nil, /*coefficients for high frequencies*/
  lfbus: Bus.audio(s,2),    /*audio bus for low frequencies*/
  hfbus: Bus.audio(s,2),    /*audio bus for high frequencies*/
  carrier: 65 ,             /*carrier frequencies to model harmonics*/
  synths: (                 /*global synths var*/
    lf1: nil,
    hf1: nil,
    hf2: nil,
    noise: nil,
    didg: nil
  );,
  groups:(                  /*global groups var*/
   sources: nil,
   noises: nil ,
   exec: nil
  );
);

 /*Coefficients to control harmonics amplitude*/

~global[\low_amplitudetable]=[
    0.05,0.9,0.2,0.4,0.05,0.25,0.15,0.1,0.15,0.08,
    0.05,0.07,0.05,0.09,0.02,0.1,0.05,0.09,0.05,0.08,
    0.1,0.06,0.05,0.06,0.07,0.09,0.06,0.05,0.03,0.02
    ];
~global[\high_amplitudetable]=[
    0.015, 0.017, 0.016, 0.014, 0.013, 0.0145, 0.014, 0.012, 0.01, 0.0095,
    0.0085, 0.007, 0.006, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005,
    0.005, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005,
];

)


s.boot;

/*
 Initizialize a freqscopeview to check output spectrum
*/

(
w = Window("My Analyzer", Rect(0, 0, 2100, 1200)); // width should be 511
f = FreqScopeView(w, w.view.bounds);
f.active_(true); // turn it on the first time;
f.dbRange_(200);
w.onClose_({ f.kill }); // you must have this
w.front;
)



/*
   every harmonic's amplitude was composed by SinOsc limited by
   a different range for each harmonics according to table's coefficients
*/


/*
   Synthdef to control low part of spectrum of Didgeridoo
*/

(

SynthDef.new(\LowDidgeridoo, {arg freq;
    var didgeridoo, numHarm;
    numHarm=30;
    didgeridoo=Mix.fill(numHarm,{
      arg index;
      var mod_amp , mod_freq, freq_osc;
      var kr_mul , kr_add, harm_amp;
      harm_amp=~global[\low_amplitudetable][index];
    kr_mul=harm_amp + PinkNoise.ar(0.01);
    kr_add=harm_amp*(0.1/(index+1)**2);
      mod_amp=SinOsc.kr(1,0,kr_mul,kr_add);
      freq_osc=freq*index;
      SinOsc.ar(freq_osc,0 , mod_amp,0);
      });
  Out.ar(~global[\lfbus].index,didgeridoo);
}).add;

/*
   Synthdef to control high part of spectrum of Didgeridoo
*/

SynthDef.new(\HighDidgeridoo, { arg freq, first_harm;
    var didgeridoo, numHarm;
    numHarm=30;
  didgeridoo=Mix.fill(numHarm,{
    arg index;
    var mod_amp , mod_freq, freq_osc ;
    var kr_mul,kr_add, harm_amp;
    harm_amp=~global[\high_amplitudetable][index];
    kr_mul=harm_amp;
    kr_add=harm_amp*(0.005/(first_harm+index)**2);
    mod_amp=SinOsc.kr(1,0,kr_mul, kr_add);
    freq_osc=freq*(first_harm+index);
    SinOsc.ar(freq_osc,0 , mod_amp,0);
  });
  Out.ar(~global[\hfbus].index,didgeridoo);
}).add;

/*
 Apply Noise to produce more natural sounds
*/

SynthDef.new(\ApplyNoise, {

  var lf,hf;
  lf=In.ar(~global[\lfbus].index,2);
  hf=In.ar(~global[\hfbus].index,2);
  lf=Mix.new([lf,BrownNoise.ar(0.1)]);
  hf=Mix.new([hf,BrownNoise.ar(0.1)]);
  Out.ar(~global[\lfbus].index,lf);
  Out.ar(~global[\hfbus].index,hf);

}).add;


/*
   Synthdef to mix low and high part of spectrum of Didgeridoo
*/
SynthDef.new(\Didgeridoo, {
  var lf, hf ,result;
  lf=Limiter.ar(In.ar(~global[\lfbus].index,2),0.25);
  hf=Limiter.ar(In.ar(~global[\hfbus].index,2),0.25);
  result=LPF.ar(GVerb.ar(Limiter.ar(Mix.new([lf,hf]),0.5),25,1,0.8),3600);
  Out.ar(0,Pan2.ar(result,0));
  Out.ar(1,Pan2.ar(result,0));
}).add;
)

(
 /*Inizialize group*/
~global[\groups][\sources]=Group.new;
~global[\groups][\noises]=Group.after(~global[\groups][\sources]);
~global[\groups][\exec]=Group.after(~global[\groups][\noises]);

/*Insertion synths into Groups*/

~global[\synths][\lf1]=Synth(\LowDidgeridoo,[\freq,~global[\carrier]],~global[\groups][\sources]);
~global[\synths][\hf1]=Synth(\HighDidgeridoo,[\freq,~global[\carrier], \first_harm, 30],~global[\groups][\sources]);
~global[\synths][\hf2]=Synth(\HighDidgeridoo,[\freq,~global[\carrier], \first_harm, 60],~global[\groups][\sources]);
~global[\synths][\noise]=Synth(\ApplyNoise, ~global[\groups][\noises]);
~global[\synths][\didg]=Synth(\Didgeridoo, ~global[\groups][\exec]);

)


s.scope;
s.freeAll;

