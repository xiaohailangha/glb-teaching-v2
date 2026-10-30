Add-Type -AssemblyName System.Speech
$unitDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\avatar\audio'
$unitSource = @'
using System;
using System.Collections.Generic;
using System.Speech.Synthesis;
using System.IO;
using System.Globalization;
public static class PronunciationUnits {
 public static void Generate(string directory) {
  string[] ids={"ae","p","schwa","l","b","n","k","t","d","aw","g","f","ih","sh","m","uu","s","ah","uh","h","ow","th","ng"};
  string[] ipa={"\u00e6","p","\u0259","l","b","n","k","t","d","\u0254","\u0261","f","\u026a","\u0283","m","u\u02d0","s","\u028c","\u028a","h","o\u028a","\u03b8","\u014b"};
  string[] words={"apple","banana","cat","dog","fish","moon","sun","book","hello","thank"};
  string[] meanings={"\u82f9\u679c","\u9999\u8549","\u732b","\u72d7","\u9c7c","\u6708\u4eae","\u592a\u9633","\u4e66","\u4f60\u597d","\u611f\u8c22"};
  var entries=new List<string>();
  using(var synth=new SpeechSynthesizer()) {
   synth.SelectVoice("Microsoft Zira Desktop");
   for(int i=0;i<ids.Length;i++) {
    GenerateOne(synth,directory,"phoneme_"+ids[i],ipa[i],"phoneme","<speak version=\"1.0\" xml:lang=\"en-US\" xmlns=\"http://www.w3.org/2001/10/synthesis\"><prosody rate=\"slow\"><phoneme alphabet=\"ipa\" ph=\""+ipa[i]+"\">sound</phoneme></prosody></speak>",entries);
   }
   GenerateOne(synth,directory,"group_schwa_l","\u0259l","group","<speak version=\"1.0\" xml:lang=\"en-US\" xmlns=\"http://www.w3.org/2001/10/synthesis\"><phoneme alphabet=\"ipa\" ph=\"\u0259l\">sound</phoneme></speak>",entries);
   synth.SelectVoice("Microsoft Huihui Desktop");
   for(int i=0;i<words.Length;i++)GenerateOne(synth,directory,"meaning_"+words[i],meanings[i],"meaning",null,entries);
  }
  File.WriteAllText(Path.Combine(directory,"pronunciation-units.json"),"{"+String.Join(",",entries)+"}");
 }
 static void GenerateOne(SpeechSynthesizer synth,string directory,string key,string text,string kind,string ssml,List<string> entries){
  var cues=new List<string>();var phones=new List<string>();
  EventHandler<VisemeReachedEventArgs> vh=(o,e)=>cues.Add("{\"time\":"+e.AudioPosition.TotalSeconds.ToString("0.000",CultureInfo.InvariantCulture)+",\"id\":"+e.Viseme+"}");
  EventHandler<PhonemeReachedEventArgs> ph=(o,e)=>{foreach(char phone in e.Phoneme)phones.Add(((int)phone).ToString(CultureInfo.InvariantCulture));};
  synth.VisemeReached+=vh;synth.PhonemeReached+=ph;
  synth.SetOutputToWaveFile(Path.Combine(directory,key+".wav"));
  if(ssml==null)synth.Speak(text);else synth.SpeakSsml(ssml);
  synth.SetOutputToNull();synth.VisemeReached-=vh;synth.PhonemeReached-=ph;
  entries.Add("\""+key+"\":{\"symbol\":\""+text+"\",\"kind\":\""+kind+"\",\"voice\":\""+synth.Voice.Name+"\",\"phones\":["+String.Join(",",phones)+"],\"cues\":["+String.Join(",",cues)+"]}");
  Console.WriteLine(key+": "+String.Join(" ",phones));
 }
}
'@
Add-Type -TypeDefinition $unitSource -ReferencedAssemblies 'System.Speech'
[PronunciationUnits]::Generate($unitDir)
