

/*
  Declaration of global var
*/
(
~global=(
  low_amplitudetable: nil,  /*coefficients for low frequencies*/
  high_amplitudetable: nil, /*coefficients for high frequencies*/
  lfbus: Bus.audio(s,2),    /*audio bus for low frequencies*/
  hfbus: Bus.audio(s,2),    /*audio bus for high frequencies*/
  bfbus: Bus.audio(s,2),    /*audio bus for background noise */
  carrier: [65.995,66] ,     /*carrier frequencies to model harmonics*/
  synths: (                 /*global synths var*/
    lf1: nil,
    lf2: nil,
    hf1: nil,
    hf2: nil,
    hf3: nil,
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
    0.0,0.9,0.2,0.5,0.05,0.25,0.15,0.1,0.15,0.08,
    0.05,0.07,0.05,0.09,0.02,0.1,0.05,0.09,0.05,0.08,
    0.1,0.06,0.05,0.06,0.07,0.09,0.06,0.05,0.03,0.02
    ];
~global[\high_amplitudetable]=[
    0.15, 0.17, 0.16, 0.14, 0.13, 0.145, 0.14, 0.12, 0.01, 0.095,
    0.085, 0.07, 0.06, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05,
    0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05,
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
    kr_mul=harm_amp;
    kr_add=harm_amp*(0.0025/(index+1)**3);
      mod_amp=SinOsc.kr(1,0,kr_mul,kr_add);
    freq_osc=freq*index;
      SinOsc.ar(freq_osc,0 , mod_amp,0);
      });
  didgeridoo=didgeridoo-0.015;
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
    kr_add=harm_amp*(0.0025/(first_harm+index)**3);
    mod_amp=SinOsc.kr(1,0,kr_mul, kr_add);
    freq_osc=freq*(first_harm+ index);
    SinOsc.ar(freq_osc,0 , mod_amp,0);
  });
  Out.ar(~global[\hfbus].index,didgeridoo);
}).add;

/*
 Apply Noise to produce more natural sounds
*/

SynthDef.new(\ApplyNoise, {

  var lf,hf, lbn, hbn;
  lf=In.ar(~global[\lfbus].index,2);
  hf=In.ar(~global[\hfbus].index,2);
  hbn=GrayNoise.ar(60)*BrownNoise.ar(50,0.2);
  lbn=GrayNoise.ar(10)*BrownNoise.ar(10);
  lf=lf*lbn;
  hf=hf*hbn;
  Out.ar(~global[\lfbus].index,lf);
  Out.ar(~global[\hfbus].index,hf);
}).add;

SynthDef.new(\BackgroundNoise, {

  var bg;
  bg=BBandPass.ar(GrayNoise.ar(0.00125,5)*BrownNoise.ar(2),12000,0.125);
  Out.ar(~global[\bfbus].index,bg);

}).add;

/*
   Synthdef to mix low and high part of spectrum of Didgeridoo
*/
SynthDef.new(\Didgeridoo, {
  var lf, hf, bf ,result, env;
  //env=Env.new([0,0.5,0], [5,1.5,2],'linear');
  lf=In.ar(~global[\lfbus].index,2);
  hf=In.ar(~global[\hfbus].index,2);
  bf=In.ar(~global[\bfbus].index,2);
  result=Mix.new([lf,hf,bf]);
  //result=HPF.ar(result,600);
  result=LPF.ar(result,1200);
  result=GVerb.ar(result,30,10,0.8);
  result=Limiter.ar(result,0.5);
  Out.ar(0,Pan2.ar(result,0));
  Out.ar(1,Pan2.ar(result,0));
}).add;
)

(
 /*Inizialize group*/
~global[\groups][\sources]=Group.new;
~global[\groups][\noisaes]=Group.after(~global[\groups][\sources]);
~global[\groups][\exec]=Group.after(~global[\groups][\noises]);

/*Insertion synths into Groups*/

~global[\synths][\lf1]=Synth.head(
  ~global[\groups][\sources],\LowDidgeridoo,
  [\freq,~global[\carrier][0]]);

~global[\synths][\lf1]=Synth.after(
  ~global[\groups][\sources],
  \LowDidgeridoo,
  [\freq,~global[\carrier][1]]);

~global[\synths][\hf1]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][0], \first_harm, 30],
  );

~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][0],\first_harm, 60]);

~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][0], \first_harm, 90]);

~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][0], \first_harm, 120],
  );

~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][0], \first_harm, 180]
  );

~global[\synths][\hf1]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][1], \first_harm, 30],
  );

~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][1], \first_harm, 60],
  );

~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][1], \first_harm, 90],
  );

~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][1], \first_harm, 120]);

~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][1], \first_harm, 150]);


~global[\synths][\hf2]=Synth.after(
  ~global[\groups][\sources],
  \HighDidgeridoo,
  [\freq,~global[\carrier][1], \first_harm, 180]);


~global[\synths][\noise]=Synth(\BackgroundNoise,
  ~global[\groups][\noises]);

~global[\synths][\noise]=Synth(\ApplyNoise,
  ~global[\groups][\noises]);

~global[\synths][\didg]=Synth(\Didgeridoo,
  ~global[\groups][\exec]);
)
s.scope;
s.freeAll;

s.queryAllNodes;

/*
 Testing functions
*/


{Limiter.ar(BBandPass.ar(GrayNoise.ar(0.025,12)*BrownNoise.ar(2),Line.ar(2400,600,2,1,0,0),0.25),0.5);}.play



~file;
~inBus;

 /*
  Loading sample throughtly SoundFile class
*/

(
~file=SoundFile.new;
 ~file.openRead(Platform.resourceDir +/+ "sounds/didgeridoo.wav");
//~file.inspect;                                   /*Info*/

x=~file.asBuffer;

/*Write buffer payloa on private bus*/

SynthDef.new(\Synthfile,{ arg bus, bufnum=0;

    Out.ar(bus, PlayBuf.ar( 2 , bufnum, BufRateScale.kr(bufnum)));
}).add;


SynthDef.new(\Outfile,{ arg inbus ;
    var soundInput;
    soundInput=In.ar(inbus , 2);
    Out.ar(0, soundInput);
    Out.ar(1, soundInput);
}).add;

~inBus=Bus.audio(s, 2);

x=Synth(\Synthfile,[\bus , ~inBus.index ]);
z=Synth.after(x,\Outfile, [\inbus, ~inBus.index]);
)





