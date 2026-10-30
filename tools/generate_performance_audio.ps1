Add-Type -AssemblyName System.Speech
$projectRoot = Split-Path -Parent $PSScriptRoot
$audioDir = Join-Path $projectRoot 'assets\avatar\audio'
$source = @'
using System;
using System.Collections.Generic;
using System.Speech.Synthesis;
using System.IO;
using System.Globalization;
public static class PerformanceAudio {
 public static void Generate(string directory) {
  using(var synth = new SpeechSynthesizer()) {
   synth.SelectVoice("Microsoft Zira Desktop"); synth.Rate=0;
   string[] text={"Hey!", "Let's say apple.", "Apple.", "Your turn!"};
   double[] offsets={0.65,2.05,4.35,6.25};
   var all=new List<string>();
   for(int i=0;i<text.Length;i++) {
    double offset=offsets[i];var cues=new List<string>();
    EventHandler<VisemeReachedEventArgs> handler=(o,e)=>{
     cues.Add("{\"time\":"+(offset+e.AudioPosition.TotalSeconds).ToString("0.000",CultureInfo.InvariantCulture)+",\"id\":"+e.Viseme+"}");
    };
    synth.VisemeReached+=handler;
    synth.SetOutputToWaveFile(Path.Combine(directory,"performance-"+i+".wav"));
    synth.Speak(text[i]);synth.SetOutputToNull();synth.VisemeReached-=handler;
    all.AddRange(cues);
   }
   File.WriteAllText(Path.Combine(directory,"performance-cues.json"),"{\"voice\":\"Microsoft Zira Desktop\",\"duration\":10,\"cues\":[{\"time\":0,\"id\":0},"+String.Join(",",all)+",{\"time\":10,\"id\":0}]}");
  }
 }
}
'@
Add-Type -TypeDefinition $source -ReferencedAssemblies 'System.Speech'
[PerformanceAudio]::Generate($audioDir)
