import path from 'node:path';
import {fileURLToPath} from 'node:url';

const projectRoot = fileURLToPath(new URL('../', import.meta.url));
const toolsRoot = process.env.SNOW_FLUTTER_TOOLS ||
    path.join(path.parse(projectRoot).root, 'sdk', 'snow-speaks');

export const outputRoot = path.resolve(toolsRoot, 'scene-preview-output');
export const webOutput = path.join(outputRoot, 'web');

const modelWorkspace = path.resolve(projectRoot, '../卡通人物/Snow Speaks');
export const stormModel = path.join(modelWorkspace, 'models', 'storm-performance.glb');
export const compiledModels = path.join(modelWorkspace, 'compiled');

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(webOutput);
}
