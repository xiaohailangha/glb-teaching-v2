import pathlib,wave,json
root=pathlib.Path(__file__).resolve().parents[1]
folder=root/'assets/avatar/audio'
offsets=[.65,2.05,4.35,6.25]
params=None;result=None;report=[]
for i,offset in enumerate(offsets):
    with wave.open(str(folder/f'performance-{i}.wav'),'rb') as source:
        p=source.getparams();audio=source.readframes(p.nframes)
    if params is None:
        params=p;result=bytearray(p.framerate*10*p.nchannels*p.sampwidth)
    assert p.framerate==params.framerate and p.nchannels==params.nchannels and p.sampwidth==params.sampwidth
    start=round(offset*p.framerate)*p.nchannels*p.sampwidth
    end=offset+p.nframes/p.framerate
    assert end<(offsets[i+1] if i+1<len(offsets) else 10),('Audio overlap',i,end)
    result[start:start+len(audio)]=audio;report.append({'start':offset,'end':end})
with wave.open(str(folder/'performance.wav'),'wb') as output:
    output.setparams(params);output.writeframes(result)
(root/'docs/performance-audio.json').write_text(json.dumps(report,indent=2))
print(report)
