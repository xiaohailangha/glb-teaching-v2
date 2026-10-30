Add-Type -AssemblyName System.Speech
$teachingAudioDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\avatar\audio'
$teachingSource = @'
using System;
using System.Collections.Generic;
using System.Speech.Synthesis;
using System.IO;
using System.Globalization;
public static class TeachingPrompts {
 public static void Generate(string directory) {
  string[] ids={"intro_warm","intro_listen","intro_next","intro_retry","intro_slow","invite_one","invite_two","encourage_one","encourage_two"};
  string[] words={"Let's try this word.","Listen to this.","Here's our next word.","Let's try it together.","Listen closely.","Your turn.","Now, you try.","Let's keep going.","Thanks for trying."};
  var entries=new List<string>();
  using(var synth=new SpeechSynthesizer()) {
   synth.SelectVoice("Microsoft Zira Desktop");synth.Rate=0;
   for(int i=0;i<ids.Length;i++) {
    var cues=new List<string>();
    EventHandler<VisemeReachedEventArgs> handler=(o,e)=>cues.Add("{\"time\":"+e.AudioPosition.TotalSeconds.ToString("0.000",CultureInfo.InvariantCulture)+",\"id\":"+e.Viseme+"}");
    synth.VisemeReached+=handler;
    synth.SetOutputToWaveFile(Path.Combine(directory,ids[i]+".wav"));synth.Speak(words[i]);synth.SetOutputToNull();synth.VisemeReached-=handler;
    entries.Add("\""+ids[i]+"\":{\"text\":\""+words[i]+"\",\"cues\":["+String.Join(",",cues)+"]}");
   }
  }
  File.WriteAllText(Path.Combine(directory,"teaching-prompts.json"),"{"+String.Join(",",entries)+"}");
 }
}
'@
Add-Type -TypeDefinition $teachingSource -ReferencedAssemblies 'System.Speech'
[TeachingPrompts]::Generate($teachingAudioDir)
