import path from 'node:path';
import {fileURLToPath} from 'node:url';

export const projectRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export const dataRoot=path.resolve(process.env.SNOW_DATA_DIR||path.join(projectRoot,'var'));
export const cacheRoot=path.resolve(process.env.SNOW_CACHE_DIR||path.join(projectRoot,'cache'));
export const authDirectory=path.join(dataRoot,'auth');
export const learningDirectory=path.join(dataRoot,'learning');
export const contentDirectory=path.join(dataRoot,'content');
