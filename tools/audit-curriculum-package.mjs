import {auditContentPackage,auditContentPackages} from '../services/curriculum-package.mjs';
if(!process.argv[2])throw Error('请提供独立内容包目录');
const directories=process.argv.slice(2);
const result=directories.length===1?auditContentPackage(directories[0]):auditContentPackages(directories);
console.log(JSON.stringify(result,null,2));
if(!result.contentValid)process.exitCode=1;
