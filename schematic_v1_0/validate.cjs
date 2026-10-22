// Independent read-back of exported Altium records; resolve physical wires + global labels.
const fs=require('fs'),path=require('path');const dir=__dirname;
const model=JSON.parse(fs.readFileSync(path.join(dir,'circuit.json'),'utf8'));
const parent=new Map(), foundPins=[], counts={components:0,pins:0,wires:0,junctions:0};
const root=x=>{if(!parent.has(x))parent.set(x,x);if(parent.get(x)!==x)parent.set(x,root(parent.get(x)));return parent.get(x);};
const join=(a,b)=>parent.set(root(a),root(b));
const expected=new Map(model.pins.map(p=>[p.ref+'-'+p.num,p.net]));
const on=(p,w)=>w.a[0]===w.b[0]?p[0]===w.a[0]&&p[1]>=Math.min(w.a[1],w.b[1])&&p[1]<=Math.max(w.a[1],w.b[1]):p[1]===w.a[1]&&p[0]>=Math.min(w.a[0],w.b[0])&&p[0]<=Math.max(w.a[0],w.b[0]);
for(const sheet of model.sheets){
 const rows=fs.readFileSync(path.join(dir,sheet.name+'.SchDoc'),'ascii').trim().split(/\r?\n/).slice(1).map(l=>Object.fromEntries(l.split('|').filter(Boolean).map(s=>{const n=s.indexOf('=');return [s.slice(0,n),s.slice(n+1)];})));
 for(const r of rows)for(const [key,value]of Object.entries(r)){
  if(/^(LOCATION\.[XY]|CORNER\.[XY]|[XY]\d+|RADIUS|PINLENGTH)$/.test(key)&&!Number.isInteger(Number(value)))
   throw Error(`${sheet.name}: invalid fractional Altium coordinate ${key}=${value}`);
 }
 const comp=new Map(),points=new Map(),wires=[];
 const point=(x,y)=>{const k=sheet.name+':'+x+','+y;points.set(k,[x,y]);root(k);return k;};
 for(let i=0;i<rows.length;i++)if(rows[i].RECORD==='1'){comp.set(i,{});counts.components++;}
 for(const r of rows)if(r.RECORD==='34')comp.get(+r.OWNERINDEX).ref=r.TEXT;
 for(const [idx,c]of comp)if(c.ref==='L1'){
  const arcs=rows.filter(r=>r.RECORD==='12'&&Number(r.OWNERINDEX)===idx);
  if(arcs.length!==4||arcs.some(r=>r.RADIUS!=='5'||r.STARTANGLE!=='0.000'||r.ENDANGLE!=='180.000'))
   throw Error('L1 must contain four native semicircular arcs');
 }
 for(const r of rows){
  const x=+r['LOCATION.X'],y=+r['LOCATION.Y'];
  if(r.RECORD==='2'){
   const c=comp.get(+r.OWNERINDEX);if(!c)throw Error('Bad pin owner');
   const rot=(+r.PINCONGLOMERATE)&3,len=+r.PINLENGTH;
   const ex=x+(rot===0?len:rot===2?-len:0),ey=y+(rot===1?len:rot===3?-len:0);
   foundPins.push({id:c.ref+'-'+r.DESIGNATOR,node:point(ex,ey)});counts.pins++;
  }
  if(r.RECORD==='27'){
   const a=[+r.X1,+r.Y1],b=[+r.X2,+r.Y2];wires.push({a,b});point(...a);point(...b);counts.wires++;
  }
  if(r.RECORD==='29'){point(x,y);counts.junctions++;}
  if(r.RECORD==='25'||r.RECORD==='17')join(point(x,y),'NET:'+r.TEXT);
 }
 for(const w of wires){const ps=[...points].filter(([k,p])=>on(p,w));for(const [k]of ps)join(ps[0][0],k);}
}
const byRoot=new Map(),byNet=new Map(),errors=[];
for(const p of foundPins){
 if(!expected.has(p.id)){errors.push('Unexpected pin '+p.id);continue;}
 const e=expected.get(p.id),r=root(p.node);if(!byRoot.has(r))byRoot.set(r,[]);byRoot.get(r).push({...p,expected:e});
 if(e!==null){if(!byNet.has(e))byNet.set(e,new Set());byNet.get(e).add(r);}
}
for(const [r,pp]of byRoot){const names=new Set(pp.map(p=>p.expected));if(names.size>1)errors.push('Short circuit: '+pp.map(p=>p.id+'='+p.expected).join(', '));if(names.has(null)&&pp.length>1)errors.push('NC pin connected');}
for(const [net,rs]of byNet)if(rs.size!==1)errors.push('Split net '+net+' / islands='+rs.size);
if(foundPins.length!==177||counts.components!==64)errors.push('Unexpected component/pin totals');
const required={
 'R11-1':'+3V3','R11-2':'MUX_E','R12-1':'MUX_S0','R12-2':'GND','R13-1':'MUX_S1','R13-2':'GND',
 'R14-1':'+3V3','R14-2':'SENS_RX','R5-1':'PUMP_GATE','R5-2':'GND','R8-1':'+3V3','R8-2':'NRST',
 'C7-1':'+3V3','C7-2':'GND','C8-1':'+3V3','C8-2':'GND','C12-1':'+3V3','C12-2':'GND','C15-1':'NRST','C15-2':'GND',
 'U1-1':'+3V3','U1-2':'VIN_P','U1-3':'VIN_P','U1-4':'GND','U1-5':'SW','U1-6':'BST',
 'U2-1':'MAIN_TX_MUX','U2-2':'RES_TX_MUX','U2-3':'SENS_RX','U2-4':null,'U2-5':'AUX_TX_MUX','U2-6':'MUX_E','U2-7':'GND','U2-8':'GND',
 'U2-9':'MUX_S1','U2-10':'MUX_S0','U2-11':null,'U2-12':'MAIN_RX_MUX','U2-13':'SENS_TX','U2-14':'AUX_RX_MUX','U2-15':'RES_RX_MUX','U2-16':'+3V3',
 'U3-1':'WIFI_RX','U3-2':'MUX_S0','U3-3':'MUX_S1','U3-4':'+3V3','U3-5':'GND','U3-6':'NRST','U3-7':'MUX_E','U3-8':null,
 'U3-9':'SENS_TX','U3-10':'SENS_RX','U3-11':'PUMP_CMD','U3-12':'KEY_MANUAL','U3-13':'LED_STATUS','U3-14':'LED_FAULT','U3-15':null,
 'U3-16':'KEY_AUTO','U3-17':null,'U3-18':'SWDIO','U3-19':'SWCLK','U3-20':'WIFI_TX',
 'Q1-1':'Q1_GATE','Q1-2':'VIN_FUSED','Q1-3':'VIN_P','Q1-4':'VIN_FUSED','Q2-1':'PUMP_GATE','Q2-2':'GND','Q2-3':'PUMP_NEG',
 'D1-1':'VIN_P','D1-2':'Q1_GATE','D2-1':'VIN_P','D2-2':'PUMP_NEG','J2-1':'VIN_P','J2-2':'PUMP_NEG'
};
for(const [id,net]of Object.entries(required))if(expected.get(id)!==net)errors.push('Design invariant: '+id);
const result={date:'2026-10-13',...counts,nets:byNet.size,connectedPins:172,noConnectPins:5,exportConnectivity:errors.length?'FAIL':'PASS',errors,scope:'Altium ASCII read-back + geometric connectivity and key pin/net invariants. Not an Altium ERC or PCB footprint check.'};
fs.writeFileSync(path.join(dir,'validation.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));if(errors.length)process.exitCode=1;
