class LessonMicrophone extends AudioWorkletProcessor {
  constructor(){super();this.buffer=new Float32Array(2048);this.offset=0;this.stopped=false;this.port.onmessage=()=>{this.stopped=true;if(this.offset)this.port.postMessage(this.buffer.slice(0,this.offset));this.port.postMessage({flushed:true});};}
  process(inputs){const channel=inputs[0]?.[0];if(channel&&!this.stopped)for(const value of channel){this.buffer[this.offset++]=value;if(this.offset===this.buffer.length){this.port.postMessage(this.buffer);this.buffer=new Float32Array(2048);this.offset=0;}}return true;}
}
registerProcessor('lesson-microphone',LessonMicrophone);
