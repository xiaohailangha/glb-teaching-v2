Add-Type -AssemblyName System.Speech
$courseAudioDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\avatar\audio'
$courseSource = @'
using System;
using System.Collections.Generic;
using System.Speech.Synthesis;
using System.IO;
using System.Globalization;
public static class CoursePrompts {
 public static void Generate(string directory) {
  string[] ids={"course_intro","course_child_intro","course_sound","course_child_sound","course_choice","course_recall","course_support","course_correct","course_attempt","course_transfer","course_finish","course_child_recall"};
  string[] lines={"今天学一个词。先听声音，再试着读。","一起认识一个水果。先听我说。","嘴张开，听这个声音。练过之后，再听完整单词。","听这个声音，我们一起试一试。","刚才听到的单词，是什么意思？","现在看看中文，试着想起它的英文。","没关系，我们一起再听一次。","选对了，这是苹果。","谢谢你的尝试。","再听一次完整的单词，然后自己试着读。","这一轮练习完成了。下次我们再试着回忆。","看看图片，试着说出它的英文。"};
  var entries=new List<string>();
  using(var synth=new SpeechSynthesizer()) {
   synth.SelectVoice("Microsoft Huihui Desktop");synth.Rate=0;
   for(int i=0;i<ids.Length;i++) {
    var cues=new List<string>();
    EventHandler<VisemeReachedEventArgs> handler=(o,e)=>cues.Add("{\"time\":"+e.AudioPosition.TotalSeconds.ToString("0.000",CultureInfo.InvariantCulture)+",\"id\":"+e.Viseme+"}");
    synth.VisemeReached+=handler;
    synth.SetOutputToWaveFile(Path.Combine(directory,ids[i]+".wav"));synth.Speak(lines[i]);synth.SetOutputToNull();synth.VisemeReached-=handler;
    entries.Add("\""+ids[i]+"\":{\"text\":\""+lines[i]+"\",\"voice\":\"Microsoft Huihui Desktop\",\"cues\":["+String.Join(",",cues)+"]}");
   }
  }
  File.WriteAllText(Path.Combine(directory,"course-prompts.json"),"{"+String.Join(",",entries)+"}",new System.Text.UTF8Encoding(false));
 }
}
'@
Add-Type -TypeDefinition $courseSource -ReferencedAssemblies 'System.Speech'
[CoursePrompts]::Generate($courseAudioDir)
