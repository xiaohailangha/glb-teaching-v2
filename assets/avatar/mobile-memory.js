// iOS browsers share a tighter page/GPU memory budget than desktop browsers.
// Keep the original GLB, vertices, rig, expressions and animation clips intact.
export function isIOSBrowser(nav=globalThis.navigator){
  return /iPad|iPhone|iPod/.test(nav?.userAgent||'')||
    (nav?.platform==='MacIntel'&&nav?.maxTouchPoints>1);
}

export async function prepareMobileModel(root,{enabled=isIOSBrowser(),resizeImage=resizeTextureImage}={}){
  const report={enabled,halfFloatGeometries:0,resizedImages:0,textureBytesBefore:0,textureBytesAfter:0};
  if(!enabled)return report;
  const images=new Map();
  root.traverse(obj=>{
    if(!obj.isMesh)return;
    if(obj.geometry.morphAttributes.position?.length){
      obj.geometry.userData.morphTextureHalfFloat=true;
      report.halfFloatGeometries++;
    }
    for(const material of Array.isArray(obj.material)?obj.material:[obj.material]){
      for(const texture of Object.values(material)){
        if(!texture?.isTexture||!texture.image?.width||texture.isDataTexture)continue;
        const image=texture.image;
        if(!images.has(image))images.set(image,{textures:new Set(),maxSize:1024});
        const item=images.get(image);item.textures.add(texture);
        // Preserve the close-up face's skin/normal detail at original resolution.
        if(material.name==='Runtime_storm_head')item.maxSize=2048;
      }
    }
  });
  for(const [image,{textures,maxSize}]of images){
    const scale=Math.min(1,maxSize/Math.max(image.width,image.height));
    const width=Math.max(1,Math.round(image.width*scale)),height=Math.max(1,Math.round(image.height*scale));
    report.textureBytesBefore+=image.width*image.height*4*4/3;
    report.textureBytesAfter+=width*height*4*4/3;
    if(scale===1)continue;
    const resized=await resizeImage(image,width,height);
    for(const texture of textures){texture.image=resized;texture.needsUpdate=true;}
    image.close?.();report.resizedImages++;
  }
  return report;
}

async function resizeTextureImage(image,width,height){
  const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;
  const context=canvas.getContext('2d');
  if(!context)throw Error('无法准备手机人物纹理');
  context.drawImage(image,0,0,width,height);
  return canvas;
}
