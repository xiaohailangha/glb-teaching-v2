import {defineConfig} from 'vite';
import vue from '@vitejs/plugin-vue';
export default defineConfig({base:'/admin/',plugins:[vue()],build:{outDir:'build'},server:{port:5320,proxy:{'/api':{target:'http://127.0.0.1:5296'},'/scene':{target:'http://127.0.0.1:5319'}}}});
