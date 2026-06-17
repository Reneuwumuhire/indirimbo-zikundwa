import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
const W=390,H=844; mkdirSync('caps',{recursive:true});
const b=await chromium.launch({headless:true});
const ctx=await b.newContext({viewport:{width:W,height:H},deviceScaleFactor:2,hasTouch:true,isMobile:true});
const p=await ctx.newPage();
const shot=async(x)=>{await p.screenshot({path:`caps/${x}.png`});console.log('shot',x);};
const tap=async(x,y,d=1100)=>{await p.touchscreen.tap(x,y);await p.waitForTimeout(d);};
const wheel=async(dy,d=700)=>{await p.mouse.move(195,430);await p.mouse.wheel(0,dy);await p.waitForTimeout(d);};
await p.goto('http://localhost:8099/',{waitUntil:'load'});
await p.waitForTimeout(5000);
await p.setViewportSize({width:W,height:H+2});await p.waitForTimeout(400);
await p.setViewportSize({width:W,height:H});
await p.evaluate(()=>window.dispatchEvent(new Event('resize')));
await p.waitForTimeout(2200);
await tap(341,805);            // settings
await wheel(700);
await tap(200,405);           // select Montserrat & Lora row
await tap(49,805,900);        // Recueils
await tap(110,330);           // book
await tap(195,360);           // song -> reader
await shot('reader-montserrat');
await b.close();
