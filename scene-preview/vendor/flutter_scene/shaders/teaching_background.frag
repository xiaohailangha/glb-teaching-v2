// Compose light behind premultiplied character coverage, before Flutter text.
uniform sampler2D input_color;
uniform FireworksInfo {
  vec4 clock; // progress, burst count, aspect, reduced motion
  vec4 centers[5]; // x,y,start,end
  vec4 shapes[5]; // radius,rays,color,seed
  vec4 style; // welcome world
} fireworks;
in vec2 v_uv;
out vec4 frag_color;
float hash(float n) { return fract(sin(n)*43758.5453); }
vec3 palette(float c) {
  if(c<.5) return vec3(1.,.86,.62);
  if(c<1.5) return vec3(.77,.94,.90);
  if(c<2.5) return vec3(.85,.87,1.);
  return vec3(1.,.85,.80);
}
vec3 sparks(vec2 uv) {
  float t=fireworks.clock.x;
  if(t<0. || t>=1.) return vec3(0.);
  vec3 light=vec3(0.);
  float aspect=fireworks.clock.z;
  for(int b=0;b<5;b++) {
    if(float(b)>=fireworks.clock.y) break;
    vec4 c=fireworks.centers[b], s=fireworks.shapes[b];
    float age=(t-c.z)/(c.w-c.z);
    if(age<=0. || age>=1.) continue;
    vec2 delta=(uv-c.xy)*vec2(aspect,1.);
    if(fireworks.clock.w>.5) {
      float d=length(delta);
      light+=palette(s.z)*exp(-d*d/0.00002)*.3;
      continue;
    }
    delta.y-=.13*age*age;
    delta.y/=.86;
    float radius=length(delta), angle=atan(delta.y,delta.x);
    float sector=6.2831853/s.y;
    float ray=floor(angle/sector+.5);
    float rayAngle=ray*sector;
    float across=abs(sin(angle-rayAngle))*radius;
    float speed=s.x*(.48+.52*hash(ray*12.9898+s.w));
    float head=speed*(1.-exp(-3.8*age));
    float tail=speed*(1.-exp(-3.8*max(0.,age-.20)));
    float fade=pow(1.-age,.9);
    float line=exp(-across*across/0.000002);
    float streak=smoothstep(tail,head+.0001,radius)*(1.-smoothstep(head,head+.003,radius));
    float tip=exp(-pow((radius-head)/.0035,2.)-across*across/0.00001);
    float glow=exp(-pow((radius-head)/.009,2.)-across*across/0.00009);
    float core=exp(-radius*radius/.00015)*pow(1.-age,8.);
    light+=palette(s.z)*fade*(line*streak*.46+tip*.72+glow*.09+core*.25);
  }
  return light;
}
void main() {
  vec4 character=texture(input_color,v_uv);
  float y=clamp(v_uv.y,0.,1.);
  float gray=y<=.72 ? mix(68./255.,125./255.,y/.72) : mix(125./255.,128./255.,(y-.72)/.28);
  vec3 background=vec3(gray);
  if(fireworks.style.x>0.) {
    vec2 uv=v_uv;
    background=mix(vec3(.025,.19,.27),vec3(.20,.62,.63),smoothstep(0.,1.,uv.y));
    vec2 sun=(uv-vec2(.17,.24))*vec2(fireworks.clock.z,1.);
    float glow=exp(-dot(sun,sun)*16.);
    background+=vec3(.28,.24,.10)*glow;
    float disk=1.-smoothstep(.073,.076,length(sun));
    background=mix(background,vec3(1.,.82,.43),disk);
    float hill=.78+.06*sin(uv.x*5.5+.5);
    background=mix(background,vec3(.08,.36,.39),smoothstep(hill,hill+.004,uv.y));
    float front=.91+.045*sin(uv.x*9.-1.);
    background=mix(background,vec3(.035,.24,.29),smoothstep(front,front+.004,uv.y));
    float stars=pow(max(0.,sin(uv.x*43.)*sin(uv.y*37.)),90.)*.18*(1.-uv.y);
    background+=vec3(stars);
    background=mix(vec3(gray),background,fireworks.style.x);
  }
  background+=sparks(v_uv);
  frag_color=vec4(character.rgb+background*(1.-character.a),1.);
}
