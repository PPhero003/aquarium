// Generate Altium ASCII schematics and vector review sheets from one circuit model.
const fs=require('fs'), path=require('path');
const out=__dirname, W=1600,H=1100;
const sheets=[], components=[], pins=[], allNets=new Map();
const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
let S, owner=-1, uid=0;
const id=()=>('ATO'+(++uid).toString(26).toUpperCase()).padEnd(8,'X');
function rec(type,obj={}) {const r={RECORD:type,...obj}; S.records.push(r);return S.records.length-1;}
function attrs(){return owner<0?{OWNERPARTID:-1}:{OWNERINDEX:owner,OWNERPARTID:1,ISNOTACCESIBLE:'T'};}
function xy(x,y){return {'LOCATION.X':x,'LOCATION.Y':H-y};}
function line(x1,y1,x2,y2,color='#263b59',width=1.5){
 S.svg.push(`<path d="M${x1} ${y1}L${x2} ${y2}" stroke="${color}" stroke-width="${width}" fill="none"/>`);
 rec(6,{...attrs(),LINEWIDTH:1,COLOR:8388608,LOCATIONCOUNT:2,X1:x1,Y1:H-y1,X2:x2,Y2:H-y2});
}
function coilArc(cx,cy,r,vertical=false){
 // Native Altium arc: integer center/radius, angles in degrees.
 // Avoid decimal values in ASCII X/Y fields (fractions need separate *_FRAC fields).
 const d=vertical?`M${cx} ${cy-r}A${r} ${r} 0 0 1 ${cx} ${cy+r}`:
                  `M${cx-r} ${cy}A${r} ${r} 0 0 1 ${cx+r} ${cy}`;
 S.svg.push(`<path d="${d}" stroke="#263b59" stroke-width="1.5" fill="none"/>`);
 rec(12,{...attrs(),...xy(cx,cy),RADIUS:r,LINEWIDTH:1,STARTANGLE:vertical?'270.000':'0.000',ENDANGLE:vertical?'90.000':'180.000',COLOR:8388608});
}
function text(x,y,t,size=12,color='#263b59',anchor='start'){
 S.svg.push(`<text x="${x}" y="${y}" font-size="${size}" fill="${color}" text-anchor="${anchor}">${esc(t)}</text>`);
 rec(4,{...attrs(),...xy(x,y+2),COLOR:8388608,FONTID:size>=19?3:size>=14?2:1,TEXT:t});
}
function rect(x,y,w,h,fill='none',color='#263b59'){
 S.svg.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" stroke="${color}" stroke-width="1.3"/>`);
 rec(14,{...attrs(),...xy(x,y+h),'CORNER.X':x+w,'CORNER.Y':H-y,COLOR:8388608,AREACOLOR:fill==='none'?16777215:15794175,ISSOLID:fill==='none'?'F':'T',LINEWIDTH:1});
}
function wire(net,...pts){
 for(let i=1;i<pts.length;i++){
  const [x1,y1]=pts[i-1],[x2,y2]=pts[i]; if(x1===x2&&y1===y2)continue;
  if(x1!==x2&&y1!==y2)throw Error('Nonorthogonal wire '+net);
  S.wires.push({net,a:[x1,y1],b:[x2,y2]});
  S.svg.push(`<path d="M${x1} ${y1}L${x2} ${y2}" stroke="#16715b" stroke-width="1.7" fill="none"/>`);
  rec(27,{OWNERPARTID:-1,LINEWIDTH:1,COLOR:32768,LOCATIONCOUNT:2,X1:x1,Y1:H-y1,X2:x2,Y2:H-y2});
 }
}
function label(net,x,y){
 S.labels.push({net,p:[x,y]});
 S.svg.push(`<text x="${x+3}" y="${y-5}" font-size="11" fill="#13634c">${esc(net)}</text>`);
 rec(25,{OWNERPARTID:-1,...xy(x,y),COLOR:32768,FONTID:1,TEXT:net});
}
function power(net,x,y,ground=false){
 S.labels.push({net,p:[x,y]});
 if(ground){
  S.svg.push(`<path d="M${x} ${y}v8m-10 0h20m-16 4h12m-9 4h6" fill="none" stroke="#16715b" stroke-width="1.5"/>`);
 }else{
  S.svg.push(`<path d="M${x} ${y}v-12m-8 0h16" fill="none" stroke="#16715b" stroke-width="1.5"/><text x="${x}" y="${y-18}" text-anchor="middle" font-size="12" fill="#13634c">${esc(net)}</text>`);
 }
 rec(17,{OWNERPARTID:-1,...xy(x,y),STYLE:ground?4:2,SHOWNETNAME:ground?'F':'T',ORIENTATION:ground?3:1,COLOR:32768,FONTID:1,TEXT:net});
}
function nc(p){
 const [x,y]=p;S.svg.push(`<path d="M${x-4} ${y-4}l8 8m-8 0l8-8" stroke="#8f96a3" stroke-width="1.5"/>`);
 rec(22,{OWNERPARTID:-1,...xy(x,y),COLOR:128,ORIENTATION:1,SYMBOL:'Thin Cross',ISACTIVE:'T',SUPPRESSALL:'T'});
}
function pin(c,num,name,x,y,dir,net,len=20,show=true,electrical=4){
 const dx=dir===0?1:dir===2?-1:0,dy=dir===1?-1:dir===3?1:0;
 const end=[x+dx*len,y+dy*len];
 // Altium pin Location is the body end; orientation points outward.
 rec(2,{OWNERINDEX:c.idx,OWNERPARTID:1,FORMALTYPE:1,ELECTRICAL:electrical,PINCONGLOMERATE:(show?56:32)+dir,PINLENGTH:len,...xy(x,y),NAME:name,DESIGNATOR:num});
 S.svg.push(`<path d="M${x} ${y}L${end[0]} ${end[1]}" stroke="#263b59" stroke-width="1.5"/>`);
 if(show){
  if(dir===0||dir===2){
   S.svg.push(`<text x="${x+dx*(len/2)}" y="${y-5}" text-anchor="middle" font-size="10" fill="#8a3640">${num}</text>`);
   S.svg.push(`<text x="${x-dx*8}" y="${y+4}" text-anchor="${dir===0?'end':'start'}" font-size="11" fill="#263b59">${esc(name)}</text>`);
  }else{
   S.svg.push(`<text x="${x+6}" y="${y+dy*(len/2)}" font-size="10" fill="#8a3640">${num}</text>`);
   S.svg.push(`<text x="${x}" y="${y-dy*15+4}" text-anchor="middle" font-size="10" fill="#263b59">${esc(name)}</text>`);
  }
 }
 const pp={ref:c.ref,num:String(num),name,net,sheet:S.name,p:end,body:[x,y]};pins.push(pp);c.pins.push(pp);S.pins.push(pp);
 if(net){if(!allNets.has(net))allNets.set(net,[]);allNets.get(net).push(`${c.ref}-${num}`);}else nc(end);
 return end;
}
function footprintFor(ref,value,kind){
 const fixed={
  J1:'TB_2P_P5.08',J2:'TB_2P_P5.08',F1:'PPTC_RADIAL_P5.10_D8.0',
  Q1:'SOT-223-4',Q2:'SOT-23-3',D1:'SOD-123',D2:'D_SMA',
  U1:'TSOT-23-6_P0.95',U2:'SOIC-16_P1.27',U3:'TSSOP-20_P0.65',L1:'IND_SMD_6.0x6.0',
  J3:'HDR_1x4_P2.54',J4:'HDR_1x4_P2.54',J5:'HDR_1x4_P2.54',J6:'HDR_1x4_P2.54',J7:'HDR_1x4_P2.54',
  SW1:'SW_TACT_6x6_4P',SW2:'SW_TACT_6x6_4P',SW3:'SW_TACT_6x6_4P',D3:'LED_0603_1608Metric',D4:'LED_0603_1608Metric'
 };
 if(fixed[ref])return fixed[ref];
 if(kind==='R')return 'R_0603_1608Metric';
 if(kind==='CP')return 'CP_RADIAL_D8.0_P3.50';
 if(kind==='C'){
  if(ref==='C2')return 'C_1210_3225Metric';
  if(['C5','C6','C8','C17'].includes(ref))return 'C_0805_2012Metric';
  return 'C_0603_1608Metric';
 }
 return '';
}
function begin(ref,value,x,y,kind){
 if(components.some(c=>c.ref===ref))throw Error('Duplicate '+ref);
 const named={
  F1:'PTC_RESETTABLE_FUSE',U1:'AP63203WU_7',U2:'74HC4052D',U3:'STM32G030F6P6',
  Q1:'PMOS_DMP6023LE',Q2:'NMOS_AO3400A',J1:'DC_INPUT_2P',J2:'PUMP_OUTPUT_2P',
  J3:'SENSOR_UART_4P',J4:'SENSOR_UART_4P',J5:'SWD_4P',J6:'SENSOR_UART_4P',J7:'WIFI_UART_4P'
 };
 const footprint=footprintFor(ref,value,kind);
 const generic={R:'RESISTOR_0603',C:'CAPACITOR',CP:'CAPACITOR_POLARIZED_RADIAL',D:'DIODE',Z:'ZENER_DIODE',LED:'LED_0603',SW:'SWITCH_TACT_6X6',L:'INDUCTOR_6X6'};
 let libRef=named[ref]||generic[kind]||kind.replace(/[^A-Za-z0-9_]/g,'_');
 if(kind==='C')libRef='CAPACITOR_'+footprint.replace(/[^A-Za-z0-9]/g,'_').toUpperCase();
 const pkg={
  F1:'Radial leaded PPTC',U1:'TSOT26',U2:'SO16 (SOT109-1)',U3:'TSSOP20',
  Q1:'SOT223 (tab/pad 4 = drain)',Q2:'SOT23',D1:'SOD-123',D2:'SMA'
 }[ref];
 const description=(pkg?`${value}; package ${pkg}`:value)+(footprint?`; footprint ${footprint}`:'');
 const idx=rec(1,{LIBREFERENCE:libRef,COMPONENTDESCRIPTION:description,PARTCOUNT:2,DISPLAYMODECOUNT:1,OWNERPARTID:-1,...xy(x,y),CURRENTPARTID:1,SOURCELIBRARYNAME:'Aquarium_ATO_PhysicalPin_V1_1.SchLib',TARGETFILENAME:'*',UNIQUEID:id(),AREACOLOR:15794175,COLOR:8388608,PARTIDLOCKED:'F',DESIGNITEMID:libRef});
 const c={ref,value,kind,libRef,footprint,idx,pins:[],sheet:S.name}; components.push(c);owner=idx;return c;
}
function end(c,x,y){
 owner=-1;
 for(const [r,n,t,yy] of [[34,'Designator',c.ref,y],[41,'Comment',c.value,y+16]]){
  rec(r,{OWNERINDEX:c.idx,OWNERPARTID:-1,INDEXINSHEET:-1,...xy(x,yy),COLOR:8388608,FONTID:1,TEXT:t,NAME:n,UNIQUEID:id()});
  S.svg.push(`<text x="${x}" y="${yy}" font-size="12" fill="#263b59">${esc(t)}</text>`);
 }
 if(c.footprint){
  const container=rec(44,{OWNERINDEX:c.idx});
  const model=rec(45,{OWNERINDEX:container,INDEXINSHEET:-1,MODELNAME:c.footprint,MODELTYPE:'PCBLIB',DATAFILECOUNT:1,MODELDATAFILE0:'Aquarium_ATO_Footprints_V1_1.PcbLib',MODELDATAFILEENTITY0:c.footprint,MODELDATAFILEKIND0:'PCBLib',ISCURRENT:'T',UNIQUEID:id()});
  const map=rec(46,{OWNERINDEX:model});
  rec(47,{OWNERINDEX:map});
  rec(48,{OWNERINDEX:model});
 }
 S.records[c.idx].ALLPINCOUNT=c.pins.length;
 return c;
}
function passive(ref,value,x,y,orient,n1,n2,kind='R'){
 const c=begin(ref,value,x,y,kind),v=orient==='v';
 const P=(a,b)=>v?[x+b,y+a]:[x+a,y+b];
 const l=(a,b,d,e)=>line(...P(a,b),...P(d,e));
 let a,b;
 if(kind==='C'||kind==='CP'){
  l(-4,-13,-4,13);l(4,-13,4,13);
  a=pin(c,1,'',...P(-4,0),v?1:2,n1,26,false);
  b=pin(c,2,'',...P(4,0),v?3:0,n2,26,false);
  if(kind==='CP')text(...P(-13,-19),'+',12);
 }else if(kind==='D'||kind==='Z'||kind==='LED'){
  // terminal 1 cathode, terminal 2 anode; vertical cathode at top.
  if(kind==='LED') {l(9,-12,9,12);l(9,0,-9,-12);l(-9,-12,-9,12);l(-9,12,9,0);}
  else {l(-9,-12,-9,12);l(-9,0,9,-12);l(9,-12,9,12);l(9,12,-9,0);}
  if(kind==='Z'){l(-9,-12,-13,-12);l(-9,12,-5,12);}
  a=pin(c,kind==='LED'?2:1,kind==='LED'?'A':'K',...P(-10,0),v?1:2,n1,20,false);
  b=pin(c,kind==='LED'?1:2,kind==='LED'?'K':'A',...P(10,0),v?3:0,n2,20,false);
  if(kind==='LED'){l(-6,-17,5,-28);l(1,-18,12,-29);l(5,-28,4,-23);l(12,-29,11,-24);}
 }else if(kind==='SW'){
  l(-10,0,11,-12);l(10,0,18,0);
  a=pin(c,1,'',...P(-10,0),v?1:2,n1,20,false);b=pin(c,2,'',...P(10,0),v?3:0,n2,20,false);
 }else if(kind==='L'){
  for(let turn=0;turn<4;turn++)coilArc(...P(-15+turn*10,0),5,v);
  a=pin(c,1,'',...P(-20,0),v?1:2,n1,10,false);b=pin(c,2,'',...P(20,0),v?3:0,n2,10,false);
 }else{
  if(v)rect(x-8,y-15,16,30);else rect(x-15,y-8,30,16);
  if(kind==='F')l(-15,0,15,0);
  a=pin(c,1,'',...P(-15,0),v?1:2,n1,15,false);b=pin(c,2,'',...P(15,0),v?3:0,n2,15,false);
 }
 const below=['R20','R22','R24'].includes(ref);
 end(c,v?x+20:x-20,v?y-4:below?y+25:kind==='LED'?y-55:y-35);return {a,b,c};
}
function ic(ref,value,x,y,w,h,defs){
 const c=begin(ref,value,x,y,'IC_'+value);rect(x,y,w,h,'#fff9df');const pp={};
 for(const [n,name,px,py,dir,net,e]of defs)pp[n]=pin(c,n,name,px,py,dir,net,20,true,e??4);
 const topView={U1:'TSOT26 TOP VIEW',U2:'SO16 TOP VIEW',U3:'TSSOP20 TOP VIEW'}[ref];
 if(topView)text(x+w/2,y+22,topView,9,'#263b59','middle');
 end(c,x-(ref==='U2'?20:0),y-35);return pp;
}
function connector(ref,value,x,y,nets,names){
 const c=begin(ref,value,x,y,'Connector_'+nets.length);rect(x,y,90,nets.length*40+10,'#eef6fc');const pp={};
 nets.forEach((n,i)=>pp[i+1]=pin(c,i+1,names[i],x,y+30+i*40,2,n,20,true));
 end(c,x,y-50);return pp;
}
function mos(ref,value,x,y,pch,gate,drain,source){
 const c=begin(ref,value,x,y,pch?'PMOS':'NMOS');
 if(pch){
  // DMP6023LE SOT223 top view: tab/pad 4 at the top; leads 1,2,3
  // from left to right at the bottom. Pads 2 and 4 are both Drain.
  rect(x,y,110,105,'#fff9df');
  text(x+55,y+42,'P-MOS',10,'#263b59','middle');text(x+55,y+62,'SOT223 TOP VIEW',9,'#263b59','middle');
  const TAB=pin(c,4,'D / TAB',x+55,y,1,drain,20,false);
  const G=pin(c,1,'G',x+20,y+105,3,gate,20,false);
  const D=pin(c,2,'D',x+55,y+105,3,drain,20,false);
  const SS=pin(c,3,'S',x+90,y+105,3,source,20,false);
  text(x+55,y-6,'4 D/TAB',9,'#263b59','middle');
  text(x+20,y+98,'1 G',9,'#263b59','middle');text(x+55,y+98,'2 D',9,'#263b59','middle');text(x+90,y+98,'3 S',9,'#263b59','middle');
  end(c,x+125,y+15);return {G,D,S:SS,TAB};
 }
 // AO3400A SOT23 top view: pin 3 at the top; pins 1 and 2 at the bottom.
 rect(x,y,100,95,'#fff9df');
 text(x+50,y+35,'N-MOS',10,'#263b59','middle');text(x+50,y+54,'SOT23 TOP VIEW',9,'#263b59','middle');
 const D=pin(c,3,'D',x+50,y,1,drain,20,false);
 const G=pin(c,1,'G',x+22,y+95,3,gate,20,false);
 const SS=pin(c,2,'S',x+78,y+95,3,source,20,false);
 text(x+50,y-6,'3 D',9,'#263b59','middle');text(x+22,y+88,'1 G',9,'#263b59','middle');text(x+78,y+88,'2 S',9,'#263b59','middle');
 end(c,x+115,y+15);return {G,D,S:SS};
}
function panel(x,y,w,h,title){rect(x,y,w,h,'none','#b7c4d3');text(x+15,y+26,title,16);}
function start(name,title,num){
 S={name,title,num,svg:[],records:[],wires:[],labels:[],pins:[]};sheets.push(S);owner=-1;
 rec(31,{FONTIDCOUNT:3,SIZE1:9,FONTNAME1:'Arial',SIZE2:12,FONTNAME2:'Arial',SIZE3:18,FONTNAME3:'Arial',USEMBCS:'T',ISBOC:'T',SHEETSTYLE:2,USECUSTOMSHEET:'T',CUSTOMX:W,CUSTOMY:H,SYSTEMFONT:1,BORDERON:'F',AREACOLOR:16777215,SNAPGRIDON:'T',SNAPGRIDSIZE:10,VISIBLEGRIDON:'F',VISIBLEGRIDSIZE:10,DISPLAY_UNIT:0});
 rect(20,20,W-40,H-40);text(45,55,'AQUARIUM ATO / '+title,23);
 text(45,79,'V1.0  |  12 V DC input / 3.3 V logic  |  2026-10-13',12);
 line(20,100,W-20,100);line(20,H-60,W-20,H-60);
 text(45,H-37,'Connected dots = joined nets. Crossing lines without a dot are NOT connected. Same net names connect across sheets.',11);
 text(W-220,H-37,`A3  |  Sheet ${num} / 3  |  V1.0`,12);
}

// Sheet 1: input protection, buck regulator and low-side pump driver.
start('01_Power_Pump','POWER & PUMP',1);
panel(45,130,600,470,'1. INPUT PROTECTION');
let j=connector('J1','DC IN 12V',100,220,['+12V_IN','GND'],['+12V','GND']);
// J1 left-facing pins route to input rail along the upper margin.
wire('+12V_IN',j[1],[60,250],[60,200],[240,200]);
let r=passive('F1','RL60-050 / 0.5A',270,200,'h','+12V_IN','VIN_FUSED','F');
let q=mos('Q1','DMP6023LE-13',320,260,true,'Q1_GATE','VIN_FUSED','VIN_P');
wire('VIN_FUSED',r.b,[375,200],[375,240],q.TAB);
wire('VIN_FUSED',[300,200],[300,405],[375,405],q.D);
wire('VIN_P',q.S,[410,400],[570,400]);power('VIN_P',570,400);
wire('GND',j[2],[60,290],[60,530],[570,530]);power('GND',570,530,true);
r=passive('R1','47k',250,460,'v','Q1_GATE','GND');
wire('Q1_GATE',q.G,[250,385],r.a);wire('GND',r.b,[250,530]);
let d=passive('D1','BZT52C10',480,460,'v','VIN_P','Q1_GATE','Z');
wire('VIN_P',[480,400],d.a);wire('Q1_GATE',d.b,[480,560],[210,560],[210,385],[340,385]);
text(90,575,'D1: cathode -> Q1 source; anode -> gate.',11);

panel(680,130,875,470,'2. 12 V -> 3.3 V / BUCK REGULATOR');
let u=ic('U1','AP63203WU-7',1060,270,190,220,[
 [1,'FB',1060,310,2,'+3V3',0],[2,'EN',1060,370,2,'VIN_P',0],[3,'VIN',1060,430,2,'VIN_P',7],
 [6,'BST',1250,310,0,'BST'],[5,'SW',1250,370,0,'SW'],[4,'GND',1250,430,0,'GND',7]]);
power('VIN_P',750,250);wire('VIN_P',[750,250],[930,250]);
wire('VIN_P',[970,370],u[2]);label('VIN_P',970,370);
wire('VIN_P',[970,430],u[3]);label('VIN_P',970,430);
for(const [ref,val,x,kind]of [['C1','47u/50V',750,'CP'],['C2','10u/50V',840,'C'],['C3','100n/50V',930,'C']]){
 const c=passive(ref,val,x,420,'v','VIN_P','GND',kind);wire('VIN_P',[x,250],c.a);wire('GND',c.b,[x,530]);
}
wire('GND',[750,530],[1500,530]);wire('GND',u[4],[1270,530]);power('GND',1270,530,true);
let c=passive('C4','100n',1310,340,'v','BST','SW','C');wire('BST',u[6],c.a);wire('SW',u[5],c.b,[1370,370]);
let l=passive('L1','3.9uH / Isat 4A',1400,370,'h','SW','+3V3','L');wire('+3V3',l.b,[1500,370]);
wire('+3V3',[1500,370],[1500,210],[1010,210],[1010,310],u[1]);power('+3V3',1500,210);
for(const [ref,x]of [['C5',1340],['C6',1460]]){
 c=passive(ref,'22u/10V',x,470,'v','+3V3','GND','C');wire('+3V3',c.a,[x,420],[1500,420],[1500,370]);wire('GND',c.b,[x,530]);
}
text(720,575,'C2/C5/C6: X7R. C2/C3 close to VIN-GND. C4 across BST-SW. FB senses output AFTER L1.',11);

panel(45,630,780,380,'3. 12 V PUMP / LOW-SIDE MOSFET');
q=mos('Q2','AO3400A',430,770,false,'PUMP_GATE','PUMP_NEG','GND');
r=passive('R4','1k',220,840,'h','PUMP_CMD','PUMP_GATE');wire('PUMP_CMD',[90,840],r.a);label('PUMP_CMD',90,840);
wire('PUMP_GATE',r.b,[350,840],[350,885],q.G);r=passive('R5','100k',350,920,'v','PUMP_GATE','GND');wire('PUMP_GATE',[350,885],r.a);
wire('GND',r.b,[350,980],[508,980],q.S);power('GND',508,980,true);
j=connector('J2','PUMP 12V',700,720,['VIN_P','PUMP_NEG'],['+12V','PUMP-']);
wire('VIN_P',[620,710],[620,750],j[1]);power('VIN_P',620,710);
wire('PUMP_NEG',q.D,[540,750],[540,790],j[2]);
d=passive('D2','SS16 / 60V',580,750,'v','VIN_P','PUMP_NEG','D');wire('VIN_P',d.a,[580,710],[620,710]);wire('PUMP_NEG',d.b,[580,790],[620,790]);
text(80,710,'R5 is wired to the gate AFTER R4.',12);
text(80,735,'Default state: gate low -> pump OFF.',12);

panel(860,630,695,380,'DESIGN / LAYOUT NOTES');
[
 '01  Keep the VIN-C2-U1-GND switching loop short.',
 '02  Place C4 at U1 pins 6 and 5; keep SW copper compact.',
 '03  Route FB away from SW, L1 and pump return current.',
 '04  Place D2 near J2/Q2 and use a short pump return loop.',
 '05  VIN_P supplies both the buck converter and the pump.',
 '06  F1 remains 0.5 A from V0.9: check pump startup current.',
 '07  This revision reorganizes wiring; original values retained.',
 '08  PCB footprints / load-current validation are not included.'
].forEach((t,i)=>text(885,700+i*34,t,12));

// Sheet 2: functional MCU symbol, reset, SWD, UART, keys and indicators.
start('02_Controller_IO','CONTROLLER & USER I/O',2);
panel(45,130,925,625,'4. MCU / LOCAL DECOUPLING / RESET');
// TSSOP20 top view: left side 1..10; right side 20..11.
u=ic('U3','STM32G030F6P6',430,215,270,500,[
 [1,'PB7 / USART1_RX',430,255,2,'WIFI_RX',0],[2,'PC14 / PB9',430,300,2,'MUX_S0',2],
 [3,'PC15',430,345,2,'MUX_S1',2],[4,'VDD / VDDA',430,390,2,'+3V3',7],
 [5,'VSS / VSSA',430,435,2,'GND',7],[6,'NRST',430,480,2,'NRST',0],
 [7,'PA0',430,525,2,'MUX_E',2],[8,'PA1',430,570,2,null],
 [9,'PA2 / USART2_TX',430,615,2,'SENS_TX',2],[10,'PA3 / USART2_RX',430,660,2,'SENS_RX',0],
 [20,'PB6 / USART1_TX',700,255,0,'WIFI_TX',2],[19,'PA14 / SWCLK',700,300,0,'SWCLK',0],
 [18,'PA13 / SWDIO',700,345,0,'SWDIO',2],[17,'PA12',700,390,0,null],
 [16,'PA11',700,435,0,'KEY_AUTO',0],[15,'PB0/PB1/PB2/PA8',700,480,0,null],
 [14,'PA7',700,525,0,'LED_FAULT',2],[13,'PA6',700,570,0,'LED_STATUS',2],
 [12,'PA5',700,615,0,'KEY_MANUAL',0],[11,'PA4',700,660,0,'PUMP_CMD',2]]);
for(const n of [1,2,3,7,9,10]){const p=u[n],net=pins.find(z=>z.ref==='U3'&&z.num==n).net;wire(net,[330,p[1]],p);label(net,330,p[1]);}
for(const n of [20,19,18,16,14,13,12,11]){const p=u[n],net=pins.find(z=>z.ref==='U3'&&z.num==n).net;wire(net,p,[800,p[1]]);label(net,800,p[1]);}
wire('+3V3',[350,390],u[4]);power('+3V3',350,390);
wire('GND',[350,435],u[5]);power('GND',350,435,true);
wire('NRST',[330,480],u[6]);label('NRST',330,480);
for(const [ref,val,x]of [['C7','100n',830],['C8','4.7u / 10V',920]]){
 c=passive(ref,val,x,230,'v','+3V3','GND','C');wire('+3V3',[x,180],c.a);power('+3V3',x,180);wire('GND',c.b,[x,290]);power('GND',x,290,true);
}
r=passive('R8','10k',220,240,'v','+3V3','NRST');power('+3V3',220,200);wire('+3V3',[220,200],r.a);wire('NRST',r.b,[220,320]);
c=passive('C15','100n',220,380,'v','NRST','GND','C');wire('NRST',[220,320],c.a);wire('GND',c.b,[220,440]);power('GND',220,440,true);
let sw=passive('SW3','RESET',110,380,'v','NRST','GND','SW');wire('NRST',[110,320],sw.a);wire('GND',sw.b,[110,440]);power('GND',110,440,true);
wire('NRST',[110,320],[220,320]);
label('NRST',220,320);
j=connector('J5','SWD 4PIN',150,530,['+3V3','SWDIO','GND','SWCLK'],['VTREF','SWDIO','GND','SWCLK']);
wire('+3V3',j[1],[90,560]);power('+3V3',90,560);
for(const [n,net]of [[2,'SWDIO'],[4,'SWCLK']]){wire(net,[60,j[n][1]],j[n]);label(net,60,j[n][1]);}
wire('GND',j[3],[100,640],[100,650]);power('GND',100,650,true);
text(320,735,'U3 symbol follows the TSSOP20 physical top-view pin order. Unused pins are marked X.',11);

panel(1000,130,555,625,'5. WIFI / 3.3 V UART ONLY');
j=connector('J7','WIFI UART',1430,330,['+3V3','GND','WIFI_MODULE_RX','WIFI_MODULE_TX'],['3V3','GND','RX','TX']);
wire('+3V3',[1050,220],[1380,220],[1380,360],j[1]);power('+3V3',1050,220);
for(const [ref,val,x,kind]of [['C16','100n',1050,'C'],['C17','10u / 10V',1170,'C'],['C18','220u / 6.3V',1290,'CP']]){
 c=passive(ref,val,x,280,'v','+3V3','GND',kind);wire('+3V3',[x,220],c.a);wire('GND',c.b,[x,325]);power('GND',x,325,true);
}
wire('GND',j[2],[1390,400],[1390,410]);power('GND',1390,410,true);
r=passive('R2','1k',1220,440,'h','WIFI_TX','WIFI_MODULE_RX');wire('WIFI_TX',[1040,440],r.a);label('WIFI_TX',1040,440);wire('WIFI_MODULE_RX',r.b,j[3]);
r=passive('R3','1k',1220,580,'h','WIFI_RX','WIFI_MODULE_TX');wire('WIFI_RX',[1040,580],r.a);label('WIFI_RX',1040,580);wire('WIFI_MODULE_TX',r.b,[1410,580],j[4]);
r=passive('R25','10k',1330,385,'v','+3V3','WIFI_MODULE_RX');wire('+3V3',r.a,[1330,350]);power('+3V3',1330,350);wire('WIFI_MODULE_RX',r.b,[1330,440]);
r=passive('R18','10k',1100,530,'v','+3V3','WIFI_RX');power('+3V3',1100,490);wire('+3V3',[1100,490],r.a);wire('WIFI_RX',r.b,[1100,580]);
text(1030,660,'RX / TX on J7 are named from the MODULE side.',12);
text(1030,689,'R18: MCU RX idle-high. R25: module RX idle-high.',11);
text(1030,718,'C16/C17/C18 connect directly across J7 supply.',11);

panel(45,785,925,225,'6. BUTTONS');
for(const [sx,rr,cc,ss,key,title]of [[0,'R6','C13','SW1','KEY_AUTO','AUTO / PAUSE'],[465,'R7','C14','SW2','KEY_MANUAL','MANUAL HOLD']]){
 const x=220+sx,y=900;
 r=passive(rr,'10k',x,850,'v','+3V3',key);power('+3V3',x,820);wire(key,r.b,[x,y],[x+200,y]);label(key,x+95,y);
 sw=passive(ss,title,x-100,940,'v',key,'GND','SW');wire(key,[x-100,y],[x,y]);wire(key,[x-100,y],sw.a);
 c=passive(cc,'100n',x+100,940,'v',key,'GND','C');wire(key,[x+100,y],c.a);
 wire('GND',sw.b,[x-100,985],[x+100,985],c.b);power('GND',x,985,true);
}
panel(1000,785,555,225,'7. STATUS / FAULT INDICATORS');
for(const [yy,rr,dd,net,val]of [[875,'R9','D3','LED_STATUS','STATUS'],[965,'R10','D4','LED_FAULT','FAULT']]){
 r=passive(rr,'1k',1200,yy,'h',net,dd+'_A');wire(net,[1030,yy],r.a);label(net,1030,yy);
 d=passive(dd,val,1380,yy,'h',dd+'_A','GND','LED');
 wire(dd+'_A',r.b,d.a);
 wire('GND',d.b,[1470,yy],[1470,yy+15]);power('GND',1470,yy+15,true);
}

// Sheet 3: mux with bias resistors physically connected, and complete sensor channels.
start('03_Sensors','SENSOR MULTIPLEXER & CONNECTORS',3);
panel(45,130,805,875,'8. DUAL 4:1 UART MULTIPLEXER');
// SO16 top view: left side 1..8; right side 16..9.
u=ic('U2','74HC4052D,652',490,250,240,680,[
 [1,'2Y0',490,300,2,'MAIN_TX_MUX'],[2,'2Y2',490,380,2,'RES_TX_MUX'],
 [3,'2Z / RX',490,460,2,'SENS_RX'],[4,'2Y3 / NC',490,540,2,null],
 [5,'2Y1',490,620,2,'AUX_TX_MUX'],[6,'E (HIGH = OFF)',490,700,2,'MUX_E',0],
 [7,'VEE',490,780,2,'GND',7],[8,'GND',490,860,2,'GND',7],
 [16,'VCC',730,300,0,'+3V3',7],[15,'1Y2',730,380,0,'RES_RX_MUX'],
 [14,'1Y1',730,460,0,'AUX_RX_MUX'],[13,'1Z / TX',730,540,0,'SENS_TX'],
 [12,'1Y0',730,620,0,'MAIN_RX_MUX'],[11,'1Y3 / NC',730,700,0,null],
 [10,'S0',730,780,0,'MUX_S0',0],[9,'S1',730,860,0,'MUX_S1',0]]);
for(const n of [1,2,3,5,6]){const p=u[n],net=pins.find(z=>z.ref==='U2'&&z.num==n).net;wire(net,[390,p[1]],p);label(net,390,p[1]);}
for(const n of [15,14,13,12,10,9]){const p=u[n],net=pins.find(z=>z.ref==='U2'&&z.num==n).net;wire(net,p,[820,p[1]]);label(net,780,p[1]);}
wire('+3V3',u[16],[790,300],[790,190]);power('+3V3',790,190);
c=passive('C12','100n',840,230,'v','+3V3','GND','C');wire('+3V3',[840,190],c.a);power('+3V3',840,190);wire('GND',c.b,[840,290]);power('GND',840,290,true);
wire('GND',[440,780],u[7]);power('GND',440,780,true);wire('GND',[440,860],u[8]);power('GND',440,860,true);
r=passive('R14','10k',250,260,'v','+3V3','SENS_RX');power('+3V3',250,210);wire('+3V3',[250,210],r.a);wire('SENS_RX',r.b,[250,300]);
label('SENS_RX',250,300);
r=passive('R11','10k',150,610,'v','+3V3','MUX_E');power('+3V3',150,560);wire('+3V3',[150,560],r.a);wire('MUX_E',r.b,[150,650]);
label('MUX_E',150,650);
r=passive('R12','100k',250,580,'v','MUX_S0','GND');wire('MUX_S0',[250,530],r.a);wire('GND',r.b,[250,640]);power('GND',250,640,true);
label('MUX_S0',250,530);
r=passive('R13','100k',250,750,'v','MUX_S1','GND');wire('MUX_S1',[250,690],r.a);wire('GND',r.b,[250,800]);power('GND',250,800,true);
label('MUX_S1',250,690);
text(85,845,'SELECT TABLE  /  S1 S0',15);
text(85,879,'00  MAIN     01  AUX     10  RESERVOIR',12);
text(85,910,'11  unused; E = 1 disconnects all channels.',12);
text(85,950,'Power-up: R11 holds E high; R12/R13 hold S0/S1 low.',11);
text(85,975,'Disable E before changing the selected UART channel.',11);

for(const [offset,jref,desc,cr,rp,rt,rr,prefix,outRx,outTx]of [
 [0,'J3','MAIN LEVEL','C9','R15','R19','R20','MAIN',12,1],
 [270,'J4','AUX LEVEL','C10','R16','R21','R22','AUX',14,5],
 [540,'J6','RESERVOIR','C11','R17','R23','R24','RES',15,2]]){
 const yy=offset;panel(880,130+yy,675,265,`${jref} / ${desc} / 3.3 V UART`);
 j=connector(jref,desc,1430,210+yy,['+3V3','GND',prefix+'_RX',prefix+'_TX'],['3V3','GND','RX','TX']);
 wire('+3V3',[1190,190+yy],[1380,190+yy],[1380,240+yy],j[1]);power('+3V3',1190,190+yy);
 c=passive(cr,'100n',1190,235+yy,'v','+3V3','GND','C');wire('+3V3',[1190,190+yy],c.a);wire('GND',c.b,[1190,280+yy]);power('GND',1190,280+yy,true);
 wire('GND',j[2],[1390,280+yy],[1390,290+yy]);power('GND',1390,290+yy,true);
 r=passive(rt,'1k',1000,300+yy,'h',prefix+'_RX_MUX',prefix+'_RX');wire(prefix+'_RX_MUX',[920,300+yy],r.a);label(prefix+'_RX_MUX',920,300+yy);
 wire(prefix+'_RX',r.b,[1350,300+yy],[1350,320+yy],j[3]);
 r=passive(rr,'1k',1000,340+yy,'h',prefix+'_TX_MUX',prefix+'_TX');wire(prefix+'_TX_MUX',[920,340+yy],r.a);label(prefix+'_TX_MUX',920,340+yy);
 wire(prefix+'_TX',r.b,[1310,340+yy],[1310,360+yy],j[4]);
 r=passive(rp,'10k',1290,245+yy,'v','+3V3',prefix+'_RX');wire('+3V3',[1290,190+yy],r.a);wire(prefix+'_RX',r.b,[1290,300+yy]);
}
text(910,985,'Connector RX/TX are from the SENSOR side. Each RX pull-up is after its series resistor.',11);

// Junctions are generated only on actual same-net intersections / T branches.
function pointOn(p,s){return (s.a[0]===s.b[0]?p[0]===s.a[0]&&p[1]>=Math.min(s.a[1],s.b[1])&&p[1]<=Math.max(s.a[1],s.b[1]):p[1]===s.a[1]&&p[0]>=Math.min(s.a[0],s.b[0])&&p[0]<=Math.max(s.a[0],s.b[0]));}
const issues=[];
for(const sh of sheets){
 S=sh;owner=-1;const points=new Map();
 for(const w of S.wires)for(const p of [w.a,w.b])points.set(p.join(','),p);
 for(const p of S.pins)if(p.net)points.set(p.p.join(','),p.p);
 for(const p of points.values()){
  const ws=S.wires.filter(w=>pointOn(p,w)), nets=new Set(ws.map(w=>w.net));
  if(nets.size>1){
   // A crossing is safe only when both lines pass through without endpoints.
   const ends=ws.some(w=>w.a.join()==p.join()||w.b.join()==p.join());
   if(ends)issues.push(`${S.name}: different-net wire endpoint intersection at ${p}: ${[...nets]}`);
  }
  const rays=new Set();for(const w of ws)for(const e of [w.a,w.b])if(e.join()!=p.join())rays.add(Math.sign(e[0]-p[0])+','+Math.sign(e[1]-p[1]));
  for(const pin of S.pins)if(pin.net&&pin.p.join()===p.join())rays.add(Math.sign(pin.body[0]-p[0])+','+Math.sign(pin.body[1]-p[1]));
  if(rays.size>=3&&nets.size===1){S.svg.push(`<circle cx="${p[0]}" cy="${p[1]}" r="3" fill="#16715b"/>`);rec(29,{OWNERPARTID:-1,...xy(...p),COLOR:32768});}
 }
 for(const p of S.pins){
  if(!p.net)continue;const ws=S.wires.filter(w=>pointOn(p.p,w));const labels=S.labels.filter(l=>l.p.join()==p.p.join());
  if(!ws.some(w=>w.net===p.net)&&!labels.some(l=>l.net===p.net))issues.push(`Unwired pin ${p.ref}-${p.num} at ${p.p}`);
  for(const w of ws)if(w.net!==p.net)issues.push(`Wrong net on ${p.ref}-${p.num}: ${w.net} expected ${p.net}`);
 }
}
if(issues.length){fs.writeFileSync(path.join(out,'validation-errors.txt'),issues.join('\n'));throw Error(issues.join('\n'));}
for(const sh of sheets){
 S=sh;
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="420mm" height="297mm"><rect width="${W}" height="${H}" fill="white"/><g font-family="Arial, sans-serif">${S.svg.join('\n')}</g></svg>`;
 fs.writeFileSync(path.join(out,S.name+'.svg'),svg);
 const header='|HEADER=Protel for Windows - Schematic Capture Ascii File Version 5.0|WEIGHT='+S.records.length+'|MINORVERSION=2|UNIQUEID='+id();
 const rows=S.records.map(r=>'|'+Object.entries(r).map(([k,v])=>k+'='+String(v).replace(/\|/g,'/')).join('|'));
 fs.writeFileSync(path.join(out,S.name+'.SchDoc'),header+'\r\n'+rows.join('\r\n')+'\r\n','ascii');
}
fs.writeFileSync(path.join(out,'Aquarium_ATO_V1_0.PrjPcb'),'[Design]\r\nVersion=1.0\r\nHierarchyMode=0\r\nNetIdentifierScope=0\r\n'+sheets.map((s,i)=>`\r\n[Document${i+1}]\r\nDocumentPath=${s.name}.SchDoc\r\nAnnotationEnabled=1\r\nAnnotateStartValue=0\r\nAnnotationIndexControlEnabled=0\r\nAnnotateSuffix=\r\nAnnotateScope=All\r\n`).join('')+`\r\n[Document${sheets.length+1}]\r\nDocumentPath=Aquarium_ATO_PhysicalPin_V1_1.SchLib\r\nAnnotationEnabled=1\r\nAnnotateStartValue=0\r\nAnnotationIndexControlEnabled=0\r\nAnnotateSuffix=\r\nAnnotateScope=All\r\n\r\n[Document${sheets.length+2}]\r\nDocumentPath=Aquarium_ATO_Footprints_V1_1.PcbLib\r\nAnnotationEnabled=1\r\nAnnotateStartValue=0\r\nAnnotationIndexControlEnabled=0\r\nAnnotateSuffix=\r\nAnnotateScope=All\r\n`);
fs.writeFileSync(path.join(out,'review.html'),'<!doctype html><html><head><meta charset="utf-8"><title>Aquarium ATO V1.0</title><style>@page{size:A3 landscape;margin:0}*{box-sizing:border-box}html,body{margin:0;background:white}section{width:420mm;height:297mm;break-after:page}section:last-child{break-after:auto}svg{display:block;width:420mm;height:297mm}</style></head><body>'+sheets.map(s=>'<section>'+fs.readFileSync(path.join(out,s.name+'.svg'),'utf8')+'</section>').join('')+'</body></html>');
fs.writeFileSync(path.join(out,'circuit.json'),JSON.stringify({sheets:sheets.map(s=>({name:s.name,wires:s.wires,labels:s.labels})),components,pins},null,2));
fs.writeFileSync(path.join(out,'pin-net.csv'),'Reference,Pin,PinName,Net,Sheet\r\n'+pins.map(p=>[p.ref,p.num,p.name,p.net||'NC',p.sheet].map(s=>'"'+s+'"').join(',')).join('\r\n'));
fs.writeFileSync(path.join(out,'BOM.csv'),'Reference,Value,Footprint,FootprintLibrary,Sheet\r\n'+components.map(c=>[c.ref,c.value+(['C2','C5','C6'].includes(c.ref)?' X7R':''),c.footprint,'Aquarium_ATO_Footprints_V1_1.PcbLib',c.sheet].map(s=>'"'+s+'"').join(',')).join('\r\n'));
console.log(JSON.stringify({sheets:sheets.length,components:components.length,pins:pins.length,nets:allNets.size,nc:pins.filter(p=>!p.net).map(p=>p.ref+'-'+p.num),validation:'All component pins have matching wire/label endpoints; no different-net endpoint collisions.'},null,2));
