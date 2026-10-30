// Records only this app's rendered character and generated audio. No desktop,
// browser tabs, microphone or screen-capture permission is requested.
export class PerformanceRecording {
  constructor(fullLayout=false){this.recorder=null;this.canvas=null;this.fullLayout=fullLayout;}
  start(audioContext,source){
    const canvas=document.createElement('canvas');canvas.width=1280;canvas.height=720;
    this.canvas=canvas;this.context=canvas.getContext('2d');
    this.audioTarget=audioContext.createMediaStreamDestination();source.connect(this.audioTarget);this.source=source;
    const stream=canvas.captureStream(60);
    for(const track of this.audioTarget.stream.getAudioTracks())stream.addTrack(track);
    const mimeType=MediaRecorder.isTypeSupported('video/webm;codecs=vp9,opus')?'video/webm;codecs=vp9,opus':'video/webm;codecs=vp8,opus';
    const recorder=new MediaRecorder(stream,{mimeType,videoBitsPerSecond:6000000});this.recorder=recorder;
    const chunks=[];recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data);};
    recorder.onstop=async()=>{
      const blob=new Blob(chunks,{type:mimeType});this.source.disconnect(this.audioTarget);
      for(const track of stream.getTracks())track.stop();
      this.canvas=null;this.recorder=null;
      try{
        const response=await fetch('/performance-recording',{method:'POST',headers:{'Content-Type':'video/webm'},body:blob});
        if(!response.ok)throw Error('保存失败');const status=document.querySelector('#record-status');if(status)status.textContent='录制已保存';
      }catch{const status=document.querySelector('#record-status');if(status)status.textContent='录制保存失败';}
    };
    recorder.start();
  }
  draw(character,caption=null){
    if(!this.canvas)return;const c=this.context;
    const gradient=c.createLinearGradient(0,0,0,720);gradient.addColorStop(0,'#444');gradient.addColorStop(.72,'#7d7d7d');gradient.addColorStop(1,'#808080');
    c.fillStyle=gradient;c.fillRect(0,0,1280,720);
    // Preserve the live canvas aspect ratio; stretch would make the face narrower.
    const scale=720/character.height,width=character.width*scale;
    const x=this.fullLayout?(1280-width)*.275:(704-width)/2;
    c.drawImage(character,x,0,width,720);
    c.fillStyle='white';c.font=caption?.teaching?'300 22px Arial':'300 36px Arial';c.fillText(caption?.subtitle||'/ˈæp.əl/  苹果',768,345);
    const title=caption?.title||'APPLE';c.font='900 100px Arial';
    const size=Math.min(100,100*420/c.measureText(title).width);c.font=`900 ${size}px Arial`;c.fillText(title,768,453);
  }
  stop(){if(this.recorder?.state==='recording')this.recorder.stop();}
}
