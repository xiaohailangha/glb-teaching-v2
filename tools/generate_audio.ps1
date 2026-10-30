Add-Type -AssemblyName System.Speech
$projectRoot = Split-Path -Parent $PSScriptRoot
$audioDir = Join-Path $projectRoot 'assets\avatar\audio'
New-Item -ItemType Directory -Path $audioDir -Force | Out-Null
$source = @'
using System;
using System.Collections.Generic;
using System.Speech.Synthesis;
using System.IO;
using System.Globalization;
public static class LessonAudio {
    public static void Generate(string directory) {
        using (var synth = new SpeechSynthesizer()) {
            var voice = "";
            foreach (var v in synth.GetInstalledVoices()) {
                Console.WriteLine("VOICE: " + v.VoiceInfo.Name + " " + v.VoiceInfo.Culture.Name);
                if(v.Enabled && v.VoiceInfo.Culture.Name == "en-US") voice = v.VoiceInfo.Name;
            }
            if (voice == "") throw new Exception("No en-US desktop voice installed.");
            synth.SelectVoice(voice);
            synth.Rate = -1;
            var all = new List<string>();
            foreach (var word in new [] {"apple","banana","cat","dog","fish","moon","sun","book","hello","thank"}) {
                var cues = new List<string>();
                EventHandler<VisemeReachedEventArgs> handler = (o,e) => {
                    cues.Add("{\"time\":" + e.AudioPosition.TotalSeconds.ToString("0.000",CultureInfo.InvariantCulture) + ",\"duration\":" + e.Duration.TotalSeconds.ToString("0.000",CultureInfo.InvariantCulture) + ",\"id\":" + e.Viseme + "}");
                };
                synth.VisemeReached += handler;
                synth.SetOutputToWaveFile(Path.Combine(directory,word+".wav"));
                synth.Speak(word);
                synth.SetOutputToNull();
                synth.VisemeReached -= handler;
                all.Add("\""+word+"\":{\"voice\":\""+voice+"\",\"cues\":["+String.Join(",",cues)+"]}");
                Console.WriteLine(word+": "+cues.Count+" visemes");
            }
            File.WriteAllText(Path.Combine(directory,"timings.json"),"{"+String.Join(",",all)+"}");
        }
    }
}
'@
Add-Type -TypeDefinition $source -ReferencedAssemblies 'System.Speech'
[LessonAudio]::Generate($audioDir)
