// Build a fresh PCB for JLCEDA Pro without running Altium Designer.
//
// Data sources:
//   - GenerateAquariumFullLayout.pas: placement and net assignments.
//   - GeneratePCBPlacement.pas: matching legacy placement cross-check.
//   - RouteAndPourAquarium.pas: explicit two-layer routing plan.
//   - FixSilkscreenOverlaps.pas: component designator positions.
//   - .eda_import/.../PCB1.pcbdoc: the user's original EasyEDA/LCSC
//     footprint geometry, stored as Altium ASCII.
//
// Output is Altium ASCII because JLCEDA Pro imports that format directly.
// The old board rules and all old board-level graphics/copper are discarded.

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const PAS = path.join(ROOT, 'GenerateAquariumFullLayout.pas');
const PLACEMENT_PAS = path.join(ROOT, 'GeneratePCBPlacement.pas');
const ROUTING_PAS = path.join(ROOT, 'RouteAndPourAquarium.pas');
const SILKSCREEN_PAS = path.join(ROOT, 'FixSilkscreenOverlaps.pas');
const SOURCE = path.join(ROOT, '..', '.eda_import',
  'New Project_2026-10-12_11-10-43', 'Board1', 'PCB1.pcbdoc');
const OUTPUT = path.join(ROOT, 'Aquarium_ATO_V1_0_LCEDA.PcbDoc');
const AUDIT = path.join(ROOT, 'Aquarium_ATO_V1_0_LCEDA_AUDIT.txt');
const BOARD_WIDTH = 120;
const BOARD_HEIGHT = 72;
const PLACEMENT_SCALE = 1.2;
const SIGNAL_TRACK_WIDTH = 0.23;
const PREFERRED_SIGNAL_TRACK_WIDTH = 0.40;
const ROUTING_CLEARANCE = 0.20;

const pas = fs.readFileSync(PAS, 'utf8');
const placementPas = fs.readFileSync(PLACEMENT_PAS, 'utf8');
const routingPas = fs.readFileSync(ROUTING_PAS, 'utf8');
const silkscreenPas = fs.readFileSync(SILKSCREEN_PAS, 'utf8');
const sourceLines = fs.readFileSync(SOURCE, 'latin1')
  .split(/\r?\n/).filter(Boolean);

function fail(message) { throw new Error(message); }
function nearly(a, b, eps = 1e-6) { return Math.abs(a - b) <= eps; }
function normAngle(a) {
  let v = a % 360;
  if (v < 0) v += 360;
  return nearly(v, 360) ? 0 : v;
}
function fmt(n) {
  const v = Math.abs(n) < 5e-8 ? 0 : n;
  return Number(v.toFixed(5)).toString();
}
function mm(v) { return `${fmt(v / 25.4 * 1000)}mil`; }
function parseLength(value) {
  const m = String(value).match(/^\s*(-?(?:\d+(?:\.\d*)?|\.\d+))\s*(mil|mm)\s*$/i);
  if (!m) fail(`Unsupported coordinate: ${value}`);
  const n = Number(m[1]);
  return m[2].toLowerCase() === 'mm' ? n : n * 0.0254;
}

function parseRecord(line) {
  if (!line.startsWith('|')) fail(`Bad PCB record: ${line.slice(0, 80)}`);
  return line.slice(1).split('|').map(token => {
    const p = token.indexOf('=');
    return p < 0 ? [token, ''] : [token.slice(0, p), token.slice(p + 1)];
  });
}
function serialize(rec) { return '|' + rec.map(([k, v]) => `${k}=${v}`).join('|'); }
function get(rec, key) {
  const pair = rec.find(x => x[0] === key);
  return pair ? pair[1] : undefined;
}
function set(rec, key, value) {
  const pair = rec.find(x => x[0] === key);
  if (pair) pair[1] = String(value);
  else rec.push([key, String(value)]);
}
function make(type, fields) {
  return [['RECORD', type], ...Object.entries(fields).map(([k, v]) => [k, String(v)])];
}
function extractMatches(text, regex) {
  return [...text.matchAll(regex)].map(match => match.slice(1));
}
function requireSameRecords(label, expected, actual) {
  if (expected.length !== actual.length ||
      expected.some((record, index) =>
        record.length !== actual[index].length ||
        record.some((value, field) => value !== actual[index][field]))) {
    fail(`PCB PAS sources disagree on ${label}`);
  }
}

const addPartRe = /AddPart\('([^']*)','([^']*)','([^']*)','([^']*)','([^']*)','([^']*)',\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)\);/g;
const routePlanRe = /MR_Plan\('([^']+)','([^']+)','([^']+)','([^']+)','([^']+)',\s*([\d.]+),\s*(True|False),\s*([\d.]+)\);/g;
const designatorRe = /SL_PlaceName\('([^']+)',\s*(-?[\d.]+),\s*(-?[\d.]+)\)/g;
requireSameRecords('component placement', extractMatches(pas, addPartRe),
  extractMatches(placementPas, addPartRe));
requireSameRecords('manual routing plan', extractMatches(pas, routePlanRe),
  extractMatches(routingPas, routePlanRe));
requireSameRecords('designator placement', extractMatches(pas, designatorRe),
  extractMatches(silkscreenPas, designatorRe));

const records = sourceLines.map(parseRecord);
const boardRecords = records.filter(r => get(r, 'RECORD') === 'Board');
if (boardRecords.length < 1) fail('Source board records missing');

const sourceComponents = new Map();
for (const rec of records.filter(r => get(r, 'RECORD') === 'Component')) {
  const ref = get(rec, 'SOURCEDESIGNATOR');
  if (!ref || sourceComponents.has(ref)) fail(`Duplicate/missing source component ${ref}`);
  sourceComponents.set(ref, {
    rec,
    id: Number(get(rec, 'ID')),
    x: parseLength(get(rec, 'X')),
    y: parseLength(get(rec, 'Y')),
    rotation: Number(get(rec, 'ROTATION') || 0),
    pattern: get(rec, 'PATTERN')
  });
}

// Parse the authoritative placement block from the PAS file.
const placements = new Map();
for (const m of pas.matchAll(addPartRe)) {
  const p = {
    ref: m[1], value: m[2], footprint: m[3], libRef: m[4], uid: m[5],
    sheet: m[6], x: Number(m[7]), y: Number(m[8]), rotation: Number(m[9])
  };
  if (placements.has(p.ref)) fail(`Duplicate PAS placement ${p.ref}`);
  placements.set(p.ref, p);
}

const nets = [];
for (const m of pas.matchAll(/AddNet\('([^']+)'\);/g)) {
  if (!nets.includes(m[1])) nets.push(m[1]);
}
const netId = new Map(nets.map((n, i) => [n, i]));

const assignments = new Map();
for (const m of pas.matchAll(/AssignPad\('([^']+)','([^']+)','([^']+)'\);/g)) {
  const key = `${m[1]}\0${m[2]}`;
  if (assignments.has(key) && assignments.get(key) !== m[3])
    fail(`Conflicting pad assignment ${m[1]}.${m[2]}`);
  assignments.set(key, m[3]);
}

const designators = new Map();
for (const m of silkscreenPas.matchAll(designatorRe)) {
  designators.set(m[1], { x: Number(m[2]), y: Number(m[3]) });
}

const links = [];
for (const m of routingPas.matchAll(routePlanRe)) {
  links.push({ net: m[1], ra: m[2], pa: m[3], rb: m[4], pb: m[5],
    width: Number(m[6]), bottom: m[7] === 'True', laneY: Number(m[8]) });
}
const endpointDegree = new Map();
for (const link of links) for (const key of [
  `${link.ra}\0${link.pa}`, `${link.rb}\0${link.pb}`
]) endpointDegree.set(key,(endpointDegree.get(key)||0)+1);

if (placements.size !== 64) fail(`Expected 64 placements, found ${placements.size}`);
if (sourceComponents.size !== 64) fail(`Expected 64 source footprints, found ${sourceComponents.size}`);
if (nets.length !== 41) fail(`Expected 41 nets, found ${nets.length}`);
if (assignments.size !== 172) fail(`Expected 172 assigned pads, found ${assignments.size}`);
if (designators.size !== 64) fail(`Expected 64 designator locations, found ${designators.size}`);
if (links.length !== 132) fail(`Expected 132 full-net links, found ${links.length}`);

for (const p of placements.values()) {
  const src = sourceComponents.get(p.ref);
  if (!src) fail(`Footprint source missing ${p.ref}`);
  if (src.pattern !== p.footprint)
    fail(`Footprint mismatch ${p.ref}: source=${src.pattern}, PAS=${p.footprint}`);
}

function rotatePoint(x, y, cx, cy, deltaDeg, tx, ty) {
  const a = deltaDeg * Math.PI / 180;
  const dx = x - cx, dy = y - cy;
  return {
    x: tx + dx * Math.cos(a) - dy * Math.sin(a),
    y: ty + dx * Math.sin(a) + dy * Math.cos(a)
  };
}
function transformPair(rec, xKey, yKey, src, dst, delta) {
  const xv = get(rec, xKey), yv = get(rec, yKey);
  if (xv === undefined || yv === undefined) return;
  const p = rotatePoint(parseLength(xv), parseLength(yv), src.x, src.y,
    delta, dst.x, dst.y);
  set(rec, xKey, mm(p.x));
  set(rec, yKey, mm(p.y));
}
function rotateField(rec, key, delta) {
  const v = get(rec, key);
  if (v !== undefined && Number.isFinite(Number(v))) set(rec, key, fmt(normAngle(Number(v) + delta)));
}

// Expand the PAS placement uniformly to open routing channels on both layers.
const outline = boardRecords[0].map(x => [...x]);
for (let i = 0; i < 5; i++) {
  const pts = [[0, 0], [BOARD_WIDTH, 0], [BOARD_WIDTH, BOARD_HEIGHT],
    [0, BOARD_HEIGHT], [0, 0]][i];
  set(outline, `KIND${i}`, '0');
  set(outline, `VX${i}`, mm(pts[0])); set(outline, `VY${i}`, mm(pts[1]));
  set(outline, `CX${i}`, '0mil'); set(outline, `CY${i}`, '0mil');
  set(outline, `SA${i}`, '0'); set(outline, `EA${i}`, '0'); set(outline, `R${i}`, '0mil');
}
set(outline, 'POLYGONOUTLINE', 'FALSE');
set(outline, 'ISSHAPEBASED', 'TRUE');
set(outline, 'MAINCONTOURVERTEXCOUNT', '5');

const out = [outline, ...boardRecords.slice(1).map(r => r.map(x => [...x]))];

for (let i = 0; i < nets.length; i++) {
  out.push(make('Net', { ID: i, NAME: nets[i], VISIBLE: 'FALSE', JUMPERSVISIBLE: 'FALSE' }));
}

// Preserve the source component IDs because every footprint primitive refers
// to them. Component values and library names are updated from the PAS data.
for (const [ref, src] of sourceComponents) {
  const dst = placements.get(ref);
  const target = { ...dst, x: dst.x * PLACEMENT_SCALE, y: dst.y * PLACEMENT_SCALE };
  const rec = src.rec.map(x => [...x]);
  set(rec, 'X', mm(target.x)); set(rec, 'Y', mm(target.y));
  set(rec, 'ROTATION', fmt(normAngle(dst.rotation)));
  set(rec, 'PATTERN', dst.footprint);
  set(rec, 'SOURCEDESIGNATOR', ref);
  set(rec, 'SOURCEUNIQUEID', dst.uid);
  set(rec, 'NAMEON', 'TRUE'); set(rec, 'COMMENTON', 'FALSE');
  out.push(rec);
}

const padIndex = new Map();
const ownedTypes = new Set(['Pad', 'Track', 'Arc', 'Region', 'Text']);
for (const original of records) {
  const type = get(original, 'RECORD');
  if (!ownedTypes.has(type) || get(original, 'COMPONENT') === undefined) continue;
  const rec = original.map(x => [...x]);
  const id = Number(get(rec, 'COMPONENT'));
  const src = [...sourceComponents.values()].find(c => c.id === id);
  if (!src) fail(`Primitive refers to unknown component ID ${id}`);
  const dst = placements.get(get(src.rec, 'SOURCEDESIGNATOR'));
  const target = { ...dst, x: dst.x * PLACEMENT_SCALE, y: dst.y * PLACEMENT_SCALE };
  const ref = dst.ref;
  const delta = dst.rotation - src.rotation;

  if (type === 'Pad') {
    transformPair(rec, 'X', 'Y', src, target, delta);
    rotateField(rec, 'ROTATION', delta);
    rotateField(rec, 'HOLEROTATION', delta);
    const pin = get(rec, 'NAME');
    const assigned = assignments.get(`${ref}\0${pin}`);
    set(rec, 'NET', assigned === undefined ? '-1' : netId.get(assigned));
    const key = `${ref}\0${pin}`;
    if (padIndex.has(key)) fail(`Duplicate footprint pad ${ref}.${pin}`);
    padIndex.set(key, rec);
  } else if (type === 'Track') {
    transformPair(rec, 'X1', 'Y1', src, target, delta);
    transformPair(rec, 'X2', 'Y2', src, target, delta);
  } else if (type === 'Arc') {
    transformPair(rec, 'LOCATION.X', 'LOCATION.Y', src, target, delta);
    rotateField(rec, 'STARTANGLE', delta); rotateField(rec, 'ENDANGLE', delta);
  } else if (type === 'Text') {
    transformPair(rec, 'X', 'Y', src, target, delta);
    rotateField(rec, 'ROTATION', delta);
    if (get(rec, 'DESIGNATOR') === 'TRUE') {
      const pos = designators.get(ref);
      set(rec, 'TEXT', ref);
      set(rec, 'X', mm(pos.x * PLACEMENT_SCALE));
      set(rec, 'Y', mm(pos.y * PLACEMENT_SCALE));
      set(rec, 'ROTATION', '0'); set(rec, 'HEIGHT', mm(0.72)); set(rec, 'WIDTH', mm(0.11));
      set(rec, 'LAYER', 'TOPOVERLAY');
    }
  } else if (type === 'Region') {
    const indices = new Set();
    for (const [key] of rec) {
      const m = key.match(/^(?:VX|VY|CX|CY)(\d+)$/);
      if (m) indices.add(Number(m[1]));
    }
    for (const i of indices) {
      transformPair(rec, `VX${i}`, `VY${i}`, src, target, delta);
      // CX/CY=0 is a sentinel for line segments. Transform only real centers.
      const cx = get(rec, `CX${i}`), cy = get(rec, `CY${i}`);
      if (cx !== undefined && cy !== undefined &&
          (!nearly(parseLength(cx), 0) || !nearly(parseLength(cy), 0)))
        transformPair(rec, `CX${i}`, `CY${i}`, src, target, delta);
      rotateField(rec, `SA${i}`, delta); rotateField(rec, `EA${i}`, delta);
    }
  }
  out.push(rec);
}

for (const [key, net] of assignments) {
  if (!netId.has(net)) fail(`Assignment uses undeclared net ${net}`);
  if (!padIndex.has(key)) fail(`Assigned footprint pad is missing: ${key.replace('\0', '.')}`);
}

function addTrack(x1, y1, x2, y2, width, layer, net) {
  if (nearly(x1, x2) && nearly(y1, y2)) return;
  out.push(make('Track', {
    NET: netId.get(net), LAYER: layer, POLYGONOUTLINE: 'FALSE',
    X1: mm(x1), Y1: mm(y1), X2: mm(x2), Y2: mm(y2), WIDTH: mm(width),
    USERROUTED: 'TRUE', LOCKED: 'FALSE',
    SOLDERMASKEXPANSIONMODE: 'None', PASTEMASKEXPANSIONMODE: 'None'
  }));
  routeTracks.push({ x1, y1, x2, y2, width, layer, net });
}
function add45(x1, y1, x2, y2, width, layer, net) {
  const dx = x2 - x1, dy = y2 - y1;
  if (nearly(dx, 0) || nearly(dy, 0)) return addTrack(x1, y1, x2, y2, width, layer, net);
  const step = Math.min(Math.abs(dx), Math.abs(dy));
  const xm = x1 + Math.sign(dx) * step, ym = y1 + Math.sign(dy) * step;
  addTrack(x1, y1, xm, ym, width, layer, net);
  addTrack(xm, ym, x2, y2, width, layer, net);
}
function padInfo(ref, pin) {
  const rec = padIndex.get(`${ref}\0${pin}`);
  if (!rec) fail(`Route pad missing ${ref}.${pin}`);
  return {
    rec, ref, pin, x: parseLength(get(rec, 'X')), y: parseLength(get(rec, 'Y')),
    layer: get(rec, 'LAYER'), net: nets[Number(get(rec, 'NET'))]
  };
}

// Copper is built in a staging suffix of `out`. If the independent sanity
// audit finds even one direct short, the whole suffix is rejected and the
// delivered PCB remains safely unrouted for manual work in JLCEDA.
const copperStart = out.length;
const routeTracks = [];
const routeVias = [];
const escapeByPad = new Map();
function viaFor(p, net) {
  if (p.layer === 'MULTILAYER') return null;
  const key = `${p.ref}\0${p.pin}`;
  if (escapeByPad.has(key)) return escapeByPad.get(key);
  const c = placements.get(p.ref);
  const dx = p.x - c.x * PLACEMENT_SCALE, dy = p.y - c.y * PLACEMENT_SCALE;
  const shift = escapeByPad.size % 2 === 0 ? 2.0 : 1.25;
  let x = p.x, y = p.y;
  if (Math.abs(dx) >= Math.abs(dy)) x += dx < 0 ? -shift : shift;
  else y += dy < 0 ? -shift : shift;
  if (x < 2) x = p.x + shift;
  if (x > BOARD_WIDTH - 2) x = p.x - shift;
  if (y < 2) y = p.y + shift;
  if (y > BOARD_HEIGHT - 2) y = p.y - shift;
  const via = { x, y, net };
  escapeByPad.set(key, via); routeVias.push(via);
  out.push(make('Via', {
    NET: netId.get(net), LAYER: 'MULTILAYER', X: mm(x), Y: mm(y),
    SIZE: mm(0.70), HOLESIZE: mm(0.30), LOWLAYER: 'TOP', HIGHLAYER: 'BOTTOM',
    PLATED: 'TRUE', TENTINGTOP: 'FALSE', TENTINGBOTTOM: 'FALSE', LOCKED: 'FALSE'
  }));
  add45(p.x, p.y, x, y, 0.20, 'TOP', net);
  return via;
}

for (const l of links) {
  const a = padInfo(l.ra, l.pa), b = padInfo(l.rb, l.pb);
  if (a.net !== l.net || b.net !== l.net)
    fail(`Route net precheck failed ${l.net}: ${l.ra}.${l.pa}=${a.net}, ${l.rb}.${l.pb}=${b.net}`);
  if (l.bottom) {
    const va = viaFor(a, l.net), vb = viaFor(b, l.net);
    const p1 = va || a, p2 = vb || b;
    const laneY = l.laneY * PLACEMENT_SCALE;
    add45(p1.x, p1.y, p1.x, laneY, l.width, 'BOTTOM', l.net);
    addTrack(p1.x, laneY, p2.x, laneY, l.width, 'BOTTOM', l.net);
    add45(p2.x, laneY, p2.x, p2.y, l.width, 'BOTTOM', l.net);
  } else if (l.laneY > 0) {
    const laneY = l.laneY * PLACEMENT_SCALE;
    add45(a.x, a.y, a.x, laneY, l.width, 'TOP', l.net);
    addTrack(a.x, laneY, b.x, laneY, l.width, 'TOP', l.net);
    add45(b.x, laneY, b.x, b.y, l.width, 'TOP', l.net);
  } else {
    add45(a.x, a.y, b.x, b.y, l.width, 'TOP', l.net);
  }
}

const groundEscapes = [
  ['C1','2'],['C2','2'],['C3','2'],['C5','2'],['C6','2'],['C7','2'],['C8','2'],
  ['C9','2'],['C10','2'],['C11','2'],['C12','2'],['C13','2'],['C14','2'],['C15','2'],
  ['C16','2'],['C17','2'],['C18','2'],['D3','1'],['D4','1'],['J1','2'],['J3','2'],
  ['J4','2'],['J5','3'],['J6','2'],['J7','2'],['Q2','2'],['R1','2'],['R5','2'],
  ['R12','2'],['R13','2'],['SW1','2'],['SW2','2'],['SW3','2'],['U1','4'],
  ['U2','7'],['U2','8'],['U3','5']
];
for (const [ref, pin] of groundEscapes) {
  const p = padInfo(ref, pin);
  if (p.net !== 'GND') fail(`Ground escape precheck failed ${ref}.${pin}`);
  viaFor(p, 'GND');
}

function addPolygon(net, layer, left, bottom, right, top) {
  out.push(make('Polygon', {
    NET: netId.get(net), LAYER: layer, LOCKED: 'FALSE', POLYGONOUTLINE: 'FALSE',
    USERROUTED: 'TRUE', POURINDEX: '-1', POUROVER: 'POLYGONS',
    POLYHATCHSTYLE: 'SOLID', REMOVEDEAD: 'TRUE', REMOVEISLANDSBYAREA: 'TRUE',
    KIND0: 0, VX0: mm(left),  VY0: mm(bottom), CX0: '0mil', CY0: '0mil', SA0: 0, EA0: 0, R0: '0mil',
    KIND1: 0, VX1: mm(right), VY1: mm(bottom), CX1: '0mil', CY1: '0mil', SA1: 0, EA1: 0, R1: '0mil',
    KIND2: 0, VX2: mm(right), VY2: mm(top),    CX2: '0mil', CY2: '0mil', SA2: 0, EA2: 0, R2: '0mil',
    KIND3: 0, VX3: mm(left),  VY3: mm(top),    CX3: '0mil', CY3: '0mil', SA3: 0, EA3: 0, R3: '0mil',
    KIND4: 0, VX4: mm(left),  VY4: mm(bottom), CX4: '0mil', CY4: '0mil', SA4: 0, EA4: 0, R4: '0mil',
    POLYGONVERTEXCOUNT: 5
  }));
}
addPolygon('GND', 'BOTTOM', 1.25, 1.25, BOARD_WIDTH-1.25, BOARD_HEIGHT-1.25);
addPolygon('+3V3', 'TOP', 1.50, 1.50, BOARD_WIDTH-1.50, 47.20*PLACEMENT_SCALE);

// Copper sanity audit. This is intentionally independent of either EDA: it
// catches direct shorts in the scripted routes before the file is imported.
function pointSegmentDistance(px, py, x1, y1, x2, y2) {
  const dx = x2 - x1, dy = y2 - y1;
  if (nearly(dx, 0) && nearly(dy, 0)) return Math.hypot(px - x1, py - y1);
  const t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)));
  return Math.hypot(px - (x1 + t * dx), py - (y1 + t * dy));
}
function orient(a, b, c) { return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x); }
function segmentsCross(a, b) {
  const p1={x:a.x1,y:a.y1}, p2={x:a.x2,y:a.y2}, q1={x:b.x1,y:b.y1}, q2={x:b.x2,y:b.y2};
  const o1=orient(p1,p2,q1), o2=orient(p1,p2,q2), o3=orient(q1,q2,p1), o4=orient(q1,q2,p2);
  return ((o1 > 1e-8 && o2 < -1e-8) || (o1 < -1e-8 && o2 > 1e-8)) &&
         ((o3 > 1e-8 && o4 < -1e-8) || (o3 < -1e-8 && o4 > 1e-8));
}
function segmentDistance(a, b) {
  if (segmentsCross(a, b)) return 0;
  return Math.min(
    pointSegmentDistance(a.x1,a.y1,b.x1,b.y1,b.x2,b.y2),
    pointSegmentDistance(a.x2,a.y2,b.x1,b.y1,b.x2,b.y2),
    pointSegmentDistance(b.x1,b.y1,a.x1,a.y1,a.x2,a.y2),
    pointSegmentDistance(b.x2,b.y2,a.x1,a.y1,a.x2,a.y2));
}
function segmentHitsExpandedPad(t, p, extra) {
  const angle = -Number(get(p.rec, 'ROTATION') || 0) * Math.PI / 180;
  const cx=p.x, cy=p.y, c=Math.cos(angle), s=Math.sin(angle);
  const local = (x,y) => ({x:(x-cx)*c-(y-cy)*s, y:(x-cx)*s+(y-cy)*c});
  const a=local(t.x1,t.y1), b=local(t.x2,t.y2);
  const hx=parseLength(get(p.rec,'XSIZE'))/2+extra;
  const hy=parseLength(get(p.rec,'YSIZE'))/2+extra;
  let lo=0, hi=1;
  for (const [p0, d, h] of [[a.x,b.x-a.x,hx],[a.y,b.y-a.y,hy]]) {
    if (nearly(d,0)) { if (p0 < -h || p0 > h) return false; }
    else {
      let t1=(-h-p0)/d, t2=(h-p0)/d;
      if (t1>t2) [t1,t2]=[t2,t1];
      lo=Math.max(lo,t1); hi=Math.min(hi,t2);
      if (lo>hi) return false;
    }
  }
  return true;
}
function viaHitsPad(v, p) {
  const angle = -Number(get(p.rec, 'ROTATION') || 0) * Math.PI / 180;
  const dx=v.x-p.x, dy=v.y-p.y, c=Math.cos(angle), s=Math.sin(angle);
  const x=dx*c-dy*s, y=dx*s+dy*c;
  const hx=parseLength(get(p.rec,'XSIZE'))/2, hy=parseLength(get(p.rec,'YSIZE'))/2;
  const qx=Math.max(Math.abs(x)-hx,0), qy=Math.max(Math.abs(y)-hy,0);
  return Math.hypot(qx,qy) < 0.35 + ROUTING_CLEARANCE + 1e-5;
}
const pads = [...padIndex.entries()].map(([key, rec]) => {
  const [ref,pin]=key.split('\0');
  return {ref,pin,rec,x:parseLength(get(rec,'X')),y:parseLength(get(rec,'Y')),
    layer:get(rec,'LAYER'),net:Number(get(rec,'NET'))<0?'NC':nets[Number(get(rec,'NET'))]};
});
function padRect(p) {
  const a=Number(get(p.rec,'ROTATION')||0)*Math.PI/180, c=Math.cos(a), s=Math.sin(a);
  return {cx:p.x,cy:p.y,hx:parseLength(get(p.rec,'XSIZE'))/2,hy:parseLength(get(p.rec,'YSIZE'))/2,
    ux:{x:c,y:s},uy:{x:-s,y:c}};
}
function rectProjectionRadius(r, axis) {
  return r.hx*Math.abs(r.ux.x*axis.x+r.ux.y*axis.y)+
         r.hy*Math.abs(r.uy.x*axis.x+r.uy.y*axis.y);
}
function padRectsOverlap(a,b) {
  const ra=padRect(a), rb=padRect(b), d={x:rb.cx-ra.cx,y:rb.cy-ra.cy};
  for (const axis of [ra.ux,ra.uy,rb.ux,rb.uy]) {
    const gap=Math.abs(d.x*axis.x+d.y*axis.y)-rectProjectionRadius(ra,axis)-rectProjectionRadius(rb,axis);
    if (gap>=-1e-5) return false;
  }
  return true;
}
const padBoardViolations=[];
for (const p of pads) {
  const r=padRect(p);
  const ex=Math.abs(r.ux.x)*r.hx+Math.abs(r.uy.x)*r.hy;
  const ey=Math.abs(r.ux.y)*r.hx+Math.abs(r.uy.y)*r.hy;
  if (p.x-ex<0 || p.x+ex>BOARD_WIDTH || p.y-ey<0 || p.y+ey>BOARD_HEIGHT)
    padBoardViolations.push(`${p.ref}.${p.pin}`);
}
const foreignNetPadOverlaps=[];
for (let i=0;i<pads.length;i++) for (let j=i+1;j<pads.length;j++) {
  const a=pads[i],b=pads[j];
  if (a.net==='NC'||b.net==='NC'||a.net===b.net) continue;
  if (a.layer!=='MULTILAYER'&&b.layer!=='MULTILAYER'&&a.layer!==b.layer) continue;
  if (padRectsOverlap(a,b)) foreignNetPadOverlaps.push(`${a.ref}.${a.pin}:${a.net}|${b.ref}.${b.pin}:${b.net}`);
}
let copperConflicts=[];
let conflictKeys=new Set();
function conflict(key, message) {
  if (!conflictKeys.has(key)) { conflictKeys.add(key); copperConflicts.push(message); }
}
function auditCopper() {
  copperConflicts = [];
  conflictKeys = new Set();
for (let i=0;i<routeTracks.length;i++) {
  const t=routeTracks[i];
  for (const p of pads) {
    if (p.net===t.net || p.net==='NC') continue;
    if (p.layer!=='MULTILAYER' && p.layer!==t.layer) continue;
      if (segmentHitsExpandedPad(t,p,t.width/2+ROUTING_CLEARANCE))
      conflict(`TP${i}:${p.ref}.${p.pin}`,`TRACK_PAD|${t.net}|${t.layer}|${p.ref}.${p.pin}|${p.net}`);
  }
  for (let j=i+1;j<routeTracks.length;j++) {
    const u=routeTracks[j];
    if (u.layer!==t.layer || u.net===t.net) continue;
    if (segmentDistance(t,u) < (t.width+u.width)/2+ROUTING_CLEARANCE-1e-5)
      conflict(`TT${i}:${j}`,`TRACK_TRACK|${t.layer}|${t.net}|${u.net}`);
  }
  for (let j=0;j<routeVias.length;j++) {
    const v=routeVias[j];
    if (v.net===t.net) continue;
    if (pointSegmentDistance(v.x,v.y,t.x1,t.y1,t.x2,t.y2) <
        0.35+t.width/2+ROUTING_CLEARANCE-1e-5)
      conflict(`TV${i}:${j}`,`TRACK_VIA|${t.net}|${v.net}`);
  }
}
for (let i=0;i<routeVias.length;i++) {
  const v=routeVias[i];
  for (const p of pads) {
    if (p.net===v.net || p.net==='NC') continue;
    if (viaHitsPad(v,p)) conflict(`VP${i}:${p.ref}.${p.pin}`,
      `VIA_PAD|${v.net}|${p.ref}.${p.pin}|${p.net}|${fmt(v.x)},${fmt(v.y)}`);
  }
  for (let j=i+1;j<routeVias.length;j++) {
    const u=routeVias[j];
    if (u.net!==v.net && Math.hypot(v.x-u.x,v.y-u.y)<
        0.70+ROUTING_CLEARANCE-1e-5)
      conflict(`VV${i}:${j}`,
        `VIA_VIA|${v.net}|${u.net}|${fmt(v.x)},${fmt(v.y)}|${fmt(u.x)},${fmt(u.y)}`);
  }
}
}
function disconnectedPlannedLinks() {
  const graph = new Map();
  const node = (net, layer, x, y) =>
    `${net}|${layer}|${x.toFixed(5)}|${y.toFixed(5)}`;
  function connect(a,b) {
    if(!graph.has(a))graph.set(a,new Set());
    if(!graph.has(b))graph.set(b,new Set());
    graph.get(a).add(b);graph.get(b).add(a);
  }
  for(const t of routeTracks)
    connect(node(t.net,t.layer,t.x1,t.y1),node(t.net,t.layer,t.x2,t.y2));
  for(const v of routeVias)
    connect(node(v.net,'TOP',v.x,v.y),node(v.net,'BOTTOM',v.x,v.y));
  const failures=[];
  for(const l of links){
    const a=padInfo(l.ra,l.pa),b=padInfo(l.rb,l.pb);
    const start=node(l.net,'TOP',a.x,a.y),goal=node(l.net,'TOP',b.x,b.y);
    const seen=new Set([start]),queue=[start];
    for(let i=0;i<queue.length&&!seen.has(goal);i++){
      for(const next of graph.get(queue[i])||[]){
        if(seen.has(next))continue;
        seen.add(next);queue.push(next);
      }
    }
    if(!seen.has(goal))failures.push(l);
  }
  return failures;
}
auditCopper();
let connectivityFailures = disconnectedPlannedLinks();
let emitScriptedCopper = copperConflicts.length === 0 &&
  connectivityFailures.length === 0;
const plannedCopperTrackCount = routeTracks.length;
const plannedViaCount = routeVias.length;
let unroutedLinks = [];
if (!emitScriptedCopper) {
  out.splice(copperStart);
  routeTracks.length = 0;
  routeVias.length = 0;

  const step = 0.125;
  const width = Math.round(BOARD_WIDTH / step) + 1;
  const height = Math.round(BOARD_HEIGHT / step) + 1;
  const cellCount = width * height;
  const directions = [
    [1,0,1],[-1,0,1],[0,1,1],[0,-1,1],
    [1,1,Math.SQRT2],[1,-1,Math.SQRT2],[-1,1,Math.SQRT2],[-1,-1,Math.SQRT2]
  ];

  function nearestOpen(grid, endpoint, net, traceWidth) {
    const blocked=grid.blocked[0];
    const cx=Math.round(endpoint.x/step),cy=Math.round(endpoint.y/step);
    for(let radius=0;radius<=32;radius++){
      let best=-1,bestD=Infinity;
      for(let dy=-radius;dy<=radius;dy++)for(let dx=-radius;dx<=radius;dx++){
        if(Math.max(Math.abs(dx),Math.abs(dy))!==radius)continue;
        const gx=cx+dx,gy=cy+dy;
        if(gx<2||gx>=width-2||gy<2||gy>=height-2)continue;
        const id=gy*width+gx;if(blocked[id])continue;
        const x=gx*step,y=gy*step;
        const stub={x1:endpoint.x,y1:endpoint.y,x2:x,y2:y,width:traceWidth,
          layer:'TOP',net};
        let safe=true;
        for(const p of pads){
          if(p.net===net||p.net==='NC'||(p.layer!=='MULTILAYER'&&p.layer!=='TOP'))continue;
          if(segmentHitsExpandedPad(stub,p,traceWidth/2+ROUTING_CLEARANCE)){safe=false;break;}
        }
        if(!safe)continue;
        for(const t of routeTracks){
          if(t.net===net||t.layer!=='TOP')continue;
          if(segmentDistance(stub,t)<(traceWidth+t.width)/2+ROUTING_CLEARANCE){safe=false;break;}
        }
        if(!safe)continue;
        for(const v of routeVias){
          if(v.net!==net&&pointSegmentDistance(v.x,v.y,x,y,endpoint.x,endpoint.y)<
            0.35+traceWidth/2+ROUTING_CLEARANCE){safe=false;break;}
        }
        if(!safe)continue;
        const d=(x-endpoint.x)**2+(y-endpoint.y)**2;
        if(d<bestD){best=id;bestD=d;}
      }
      if(best>=0)return best;
    }
    return -1;
  }

  function makeGrid(net, traceWidth) {
    const blocked = [new Uint8Array(cellCount), new Uint8Array(cellCount)];
    const viaBlocked = new Uint8Array(cellCount);
    function markPad(target, p, margin) {
      const r = padRect(p);
      const ex = Math.abs(r.ux.x) * (r.hx + margin) +
        Math.abs(r.uy.x) * (r.hy + margin);
      const ey = Math.abs(r.ux.y) * (r.hx + margin) +
        Math.abs(r.uy.y) * (r.hy + margin);
      const minX = Math.max(0, Math.floor((p.x - ex) / step));
      const maxX = Math.min(width - 1, Math.ceil((p.x + ex) / step));
      const minY = Math.max(0, Math.floor((p.y - ey) / step));
      const maxY = Math.min(height - 1, Math.ceil((p.y + ey) / step));
      for (let gy = minY; gy <= maxY; gy++) for (let gx = minX; gx <= maxX; gx++) {
        const dx = gx * step - p.x, dy = gy * step - p.y;
        if (Math.abs(dx * r.ux.x + dy * r.ux.y) <= r.hx + margin &&
            Math.abs(dx * r.uy.x + dy * r.uy.y) <= r.hy + margin)
          target[gy * width + gx] = 1;
      }
    }
    function markTrack(target, t, margin) {
      const minX = Math.max(0, Math.floor((Math.min(t.x1,t.x2)-margin)/step));
      const maxX = Math.min(width-1, Math.ceil((Math.max(t.x1,t.x2)+margin)/step));
      const minY = Math.max(0, Math.floor((Math.min(t.y1,t.y2)-margin)/step));
      const maxY = Math.min(height-1, Math.ceil((Math.max(t.y1,t.y2)+margin)/step));
      for (let gy=minY;gy<=maxY;gy++) for(let gx=minX;gx<=maxX;gx++)
        if(pointSegmentDistance(gx*step,gy*step,t.x1,t.y1,t.x2,t.y2)<=margin)
          target[gy*width+gx]=1;
    }
    for (const p of pads) {
      if (p.net === net || p.net === 'NC') continue;
      markPad(viaBlocked,p,0.40+ROUTING_CLEARANCE);
      if (p.layer === 'MULTILAYER' || p.layer === 'TOP')
        markPad(blocked[0],p,traceWidth/2+ROUTING_CLEARANCE);
      if (p.layer === 'MULTILAYER' || p.layer === 'BOTTOM')
        markPad(blocked[1],p,traceWidth/2+ROUTING_CLEARANCE);
    }
    for (const t of routeTracks) {
      if (t.net === net) continue;
      markTrack(blocked[t.layer === 'BOTTOM' ? 1 : 0],t,
        (t.width+traceWidth)/2+ROUTING_CLEARANCE);
      markTrack(viaBlocked,t,0.35+t.width/2+ROUTING_CLEARANCE);
    }
    for (const v of routeVias) {
      if (v.net === net) continue;
      const trackClearance=0.35+traceWidth/2+ROUTING_CLEARANCE;
      const viaClearance=0.70+ROUTING_CLEARANCE;
      const minX=Math.max(0,Math.floor((v.x-viaClearance)/step));
      const maxX=Math.min(width-1,Math.ceil((v.x+viaClearance)/step));
      const minY=Math.max(0,Math.floor((v.y-viaClearance)/step));
      const maxY=Math.min(height-1,Math.ceil((v.y+viaClearance)/step));
      for(let gy=minY;gy<=maxY;gy++)for(let gx=minX;gx<=maxX;gx++)
        if(Math.hypot(gx*step-v.x,gy*step-v.y)<viaClearance)
          viaBlocked[gy*width+gx]=1;
      for (const layer of blocked) {
        for(let gy=minY;gy<=maxY;gy++)for(let gx=minX;gx<=maxX;gx++)
          if(Math.hypot(gx*step-v.x,gy*step-v.y)<trackClearance)
            layer[gy*width+gx]=1;
      }
    }
    return { blocked, viaBlocked };
  }

  function astar(grid, start, goal, net, traceWidth) {
    const startId=nearestOpen(grid,start,net,traceWidth);
    const goalId=nearestOpen(grid,goal,net,traceWidth);
    if(startId<0||goalId<0)return null;
    const stateCount=cellCount*2;
    const viaPenalty=20;
    const scores=new Float64Array(stateCount);scores.fill(Infinity);
    const parents=new Int32Array(stateCount);parents.fill(-1);
    const closed=new Uint8Array(stateCount),heap=[];
    function heuristic(id){
      const cell=id%cellCount;
      const dx=Math.abs(cell%width-goalId%width);
      const dy=Math.abs(Math.floor(cell/width)-Math.floor(goalId/width));
      return Math.max(dx,dy)+(Math.SQRT2-1)*Math.min(dx,dy);
    }
    function push(id,priority){
      let i=heap.length;heap.push([id,priority]);
      while(i>0){const p=(i-1)>>1;if(heap[p][1]<=priority)break;heap[i]=heap[p];i=p;}
      heap[i]=[id,priority];
    }
    function pop(){
      const first=heap[0],last=heap.pop();
      if(heap.length){let i=0;while(true){let c=i*2+1;if(c>=heap.length)break;
        if(c+1<heap.length&&heap[c+1][1]<heap[c][1])c++;
        if(heap[c][1]>=last[1])break;heap[i]=heap[c];i=c;}heap[i]=last;}
      return first;
    }
    scores[startId]=0;push(startId,heuristic(startId));
    let expanded=0;
    while(heap.length){
      const [current]=pop();if(closed[current])continue;
      if(++expanded>350000)return null;
      const cell=current%cellCount;
      if(current===goalId){
        const path=[];
        for(let id=current;id>=0;id=parents[id]){
          const cell=id%cellCount;
          path.push({x:(cell%width)*step,y:Math.floor(cell/width)*step,
            layer:Math.floor(id/cellCount)});
          if(id===startId)break;
        }
        return path.reverse();
      }
      closed[current]=1;
      const layer=Math.floor(current/cellCount);
      const gx=cell%width,gy=Math.floor(cell/width);
      for(const [dx,dy,cost] of directions){
        const nx=gx+dx,ny=gy+dy;
        if(nx<2||nx>=width-2||ny<2||ny>=height-2)continue;
        const nextCell=ny*width+nx,next=layer*cellCount+nextCell;
        if(grid.blocked[layer][nextCell]||closed[next])continue;
        if(dx&&dy&&(grid.blocked[layer][gy*width+nx]||
          grid.blocked[layer][ny*width+gx]))continue;
        const score=scores[current]+cost;
        if(score>=scores[next])continue;
        scores[next]=score;parents[next]=current;push(next,score+heuristic(next));
      }
      if(!grid.viaBlocked[cell]&&!grid.blocked[0][cell]&&!grid.blocked[1][cell]){
        const next=(1-layer)*cellCount+cell;
        const score=scores[current]+viaPenalty;
        if(!closed[next]&&score<scores[next]){
          scores[next]=score;parents[next]=current;push(next,score+heuristic(next));
        }
      }
    }
    return null;
  }

  function segmentIsClear(segment, traceWidth, layer, net) {
    for(const p of pads){
      if(p.net===net||p.net==='NC'||(p.layer!=='MULTILAYER'&&p.layer!==layer))continue;
      if(segmentHitsExpandedPad(segment,p,traceWidth/2+ROUTING_CLEARANCE))return false;
    }
    for(const t of routeTracks){
      if(t.net===net||t.layer!==layer)continue;
      if(segmentDistance(segment,t)<
        (traceWidth+t.width)/2+ROUTING_CLEARANCE-1e-5)return false;
    }
    for(const v of routeVias){
      if(v.net===net)continue;
      if(pointSegmentDistance(v.x,v.y,segment.x1,segment.y1,segment.x2,segment.y2)<
        0.35+traceWidth/2+ROUTING_CLEARANCE-1e-5)return false;
    }
    return true;
  }

  function orthogonal45Segments(a,b) {
    const dx=b.x-a.x,dy=b.y-a.y;
    const sx=Math.sign(dx),sy=Math.sign(dy),ax=Math.abs(dx),ay=Math.abs(dy);
    const tolerance=step*0.1;
    if(ax<tolerance||ay<tolerance||Math.abs(ax-ay)<tolerance)return [[b]];
    const corners=ax>ay
      ? [{x:a.x+sx*(ax-ay),y:a.y,layer:a.layer},
        {x:a.x+sx*ay,y:a.y+sy*ay,layer:a.layer}]
      : [{x:a.x,y:a.y+sy*(ay-ax),layer:a.layer},
        {x:a.x+sx*ax,y:a.y+sy*ax,layer:a.layer}];
    return corners.map(corner=>[corner,b]);
  }

  function simplifyPath(path, traceWidth, net) {
    const simplified=[path[0]];
    let start=0;
    while(start<path.length-1){
      let next=start+1;
      let selectedRoute=null;
      for(let candidate=path.length-1;candidate>start+1;candidate--){
        if(path[candidate].layer!==path[start].layer)continue;
        let crossesLayer=false;
        for(let i=start+1;i<=candidate;i++){
          if(path[i].layer!==path[start].layer){crossesLayer=true;break;}
        }
        if(crossesLayer)continue;
        const layer=path[start].layer===1?'BOTTOM':'TOP';
        const routes=orthogonal45Segments(path[start],path[candidate]);
        for(const route of routes){
          if(route.every((point,index)=>{
            const from=index===0?path[start]:route[index-1];
            return segmentIsClear({x1:from.x,y1:from.y,x2:point.x,y2:point.y},
              traceWidth,layer,net);
          })){
            next=candidate;
            selectedRoute=route;
            break;
          }
        }
        if(selectedRoute)break;
      }
      if(!selectedRoute){
        const routes=orthogonal45Segments(path[start],path[next]);
        const layer=path[start].layer===1?'BOTTOM':'TOP';
        selectedRoute=routes.find(route=>route.every((point,index)=>{
          const from=index===0?path[start]:route[index-1];
          return segmentIsClear({x1:from.x,y1:from.y,x2:point.x,y2:point.y},
            traceWidth,layer,net);
        }));
        if(!selectedRoute)return null;
      }
      simplified.push(...selectedRoute);
      start=next;
    }
    const compact=[];
    for(const point of simplified){
      while(compact.length>=2){
        const a=compact[compact.length-2],b=compact[compact.length-1];
        if(a.layer!==b.layer||b.layer!==point.layer)break;
        const abx=b.x-a.x,aby=b.y-a.y,bcx=point.x-b.x,bcy=point.y-b.y;
        if(Math.abs(abx*bcy-aby*bcx)>1e-6||abx*bcx+aby*bcy<0)break;
        compact.pop();
      }
      compact.push(point);
    }
    return compact;
  }

  function addRoutingVia(x,y,net) {
    if(routeVias.some(v=>v.net===net&&nearly(v.x,x)&&nearly(v.y,y)))return;
    const via={x,y,net};
    routeVias.push(via);
    out.push(make('Via',{
      NET:netId.get(net),LAYER:'MULTILAYER',X:mm(x),Y:mm(y),SIZE:mm(0.70),
      HOLESIZE:mm(0.30),LOWLAYER:'TOP',HIGHLAYER:'BOTTOM',PLATED:'TRUE',
      TENTINGTOP:'FALSE',TENTINGBOTTOM:'FALSE',LOCKED:'FALSE'
    }));
  }

  const padDensity = new Map();
  for (const p of pads) padDensity.set(p.ref,(padDensity.get(p.ref)||0)+1);
  const routeAttempts = links.map(link => {
    const a = padInfo(link.ra, link.pa), b = padInfo(link.rb, link.pb);
    return { ...link, length: Math.hypot(a.x - b.x, a.y - b.y),
      plane:link.net === 'GND' || link.net === '+3V3',
      criticalDecoupling:(link.net === '+3V3' &&
        ((link.ra === 'U3' && link.pa === '4') ||
         (link.rb === 'U3' && link.pb === '4'))) ||
        (link.net === 'GND' &&
        ((link.ra === 'U3' && link.pa === '5') ||
         (link.rb === 'U3' && link.pb === '5'))),
      routeWidth:link.width<0.50?PREFERRED_SIGNAL_TRACK_WIDTH:link.width,
      density:(padDensity.get(link.ra)||0)+(padDensity.get(link.rb)||0),
      endpointDegree:(endpointDegree.get(`${link.ra}\0${link.pa}`)||0)+
        (endpointDegree.get(`${link.rb}\0${link.pb}`)||0) };
  }).sort((a, b) => Number(b.criticalDecoupling) - Number(a.criticalDecoupling) ||
    Number(a.plane) - Number(b.plane) ||
    b.density - a.density ||
    b.endpointDegree - a.endpointDegree || b.routeWidth - a.routeWidth ||
    b.length - a.length);
  for (const link of routeAttempts) {
    const a=padInfo(link.ra,link.pa),b=padInfo(link.rb,link.pb);
    const widthOptions=link.width<0.50
      ?[PREFERRED_SIGNAL_TRACK_WIDTH,SIGNAL_TRACK_WIDTH]
      :[link.routeWidth];
    let simplified=null,selectedWidth=link.routeWidth;
    for(const traceWidth of widthOptions){
      const grid=makeGrid(link.net,traceWidth);
      const points=astar(grid,a,b,link.net,traceWidth);
      if(!points)continue;
      const path=[{x:a.x,y:a.y,layer:0},...points,{x:b.x,y:b.y,layer:0}];
      const candidate=simplifyPath(path,traceWidth,link.net);
      if(!candidate)continue;
      let clear=true;
      for(let i=1;i<candidate.length;i++){
        const prev=candidate[i-1],next=candidate[i];
        if(prev.layer!==next.layer)continue;
        if(!segmentIsClear({x1:prev.x,y1:prev.y,x2:next.x,y2:next.y},
          traceWidth,prev.layer===1?'BOTTOM':'TOP',link.net)){
          clear=false;break;
        }
      }
      if(!clear)continue;
      simplified=candidate;
      selectedWidth=traceWidth;
      break;
    }
    if(!simplified){unroutedLinks.push(link);continue;}
    for(let i=1;i<simplified.length;i++){
      const prev=simplified[i-1],next=simplified[i];
      if(prev.layer!==next.layer)addRoutingVia(prev.x,prev.y,link.net);
      else addTrack(prev.x,prev.y,next.x,next.y,selectedWidth,
        prev.layer===1?'BOTTOM':'TOP',link.net);
    }
  }
  auditCopper();
  connectivityFailures = disconnectedPlannedLinks();
  emitScriptedCopper = unroutedLinks.length === 0 &&
    connectivityFailures.length === 0 && copperConflicts.length === 0;
  if (emitScriptedCopper) {
    addPolygon('GND','TOP',1.25,1.25,BOARD_WIDTH-1.25,BOARD_HEIGHT-1.25);
    addPolygon('GND','BOTTOM',1.25,1.25,BOARD_WIDTH-1.25,BOARD_HEIGHT-1.25);
    addPolygon('+3V3','TOP',1.50,1.50,BOARD_WIDTH-1.50,47.20*PLACEMENT_SCALE);
  } else {
    out.splice(copperStart);
  }
}

// Mechanical board outline (the Board record above remains authoritative).
for (const [x1, y1, x2, y2] of [[0,0,BOARD_WIDTH,0],
  [BOARD_WIDTH,0,BOARD_WIDTH,BOARD_HEIGHT],
  [BOARD_WIDTH,BOARD_HEIGHT,0,BOARD_HEIGHT],[0,BOARD_HEIGHT,0,0]]) {
  out.push(make('Track', { LAYER: 'MECHANICAL1', POLYGONOUTLINE: 'FALSE',
    X1: mm(x1), Y1: mm(y1), X2: mm(x2), Y2: mm(y2), WIDTH: mm(0.20),
    LOCKED: 'FALSE', SOLDERMASKEXPANSIONMODE: 'None', PASTEMASKEXPANSIONMODE: 'None' }));
}
for (const [name, x, y] of [['MH1',4.8,67.2],['MH2',115.2,67.2],
  ['MH3',4.8,4.8],['MH4',115.2,4.8]]) {
  out.push(make('Pad', { NET: -1, LAYER: 'MULTILAYER', NAME: name,
    HOLESIZE: mm(3.20), PLATED: 'FALSE', PINLENGTH: '0mil', LOCKED: 'FALSE',
    ROTATION: 0, HOLETYPE: 0, HOLEWIDTH: mm(3.20), HOLEROTATION: 0,
    X: mm(x), Y: mm(y), XSIZE: mm(3.20), YSIZE: mm(3.20), SHAPE: 'ROUND', PADMODE: 0,
    PASTEMASKEXPANSIONMODE: 'Manual', PASTEMASKEXPANSION_MANUAL: '0mil',
    SOLDERMASKEXPANSIONMODE: 'Manual', SOLDERMASKEXPANSION_MANUAL: '0mil',
    TENTINGTOP: 'FALSE', TENTINGBOTTOM: 'FALSE' }));
}

const labels = [
  ['AQUARIUM ATO V1.0',2,58,1.0],['POWER / BUCK',18,58,0.8],['PUMP',82,58,0.8],
  ['SENSORS',2,20,0.8],['MCU / SWD',51,43,0.8],['WIFI / USER',77,28,0.8],
  [emitScriptedCopper ? 'ROUTED - IMPORT / DRC REQUIRED' : 'UNROUTED - MANUAL ROUTING REQUIRED',69,2,0.7]
];
for (const [text, x, y, size] of labels) {
  out.push(make('Text', { LAYER: 'MECHANICAL2', WIDESTRING: '', TEXT: text,
    MIRROR: 'FALSE', ROTATION: 0, INVERTED: 'FALSE',
    X: mm(x * PLACEMENT_SCALE), Y: mm(y * PLACEMENT_SCALE),
    FONTNAME: 'Arial', HEIGHT: mm(size), WIDTH: mm(0.15), ITALIC: 'FALSE',
    BOLD: 'FALSE', FONT: 'DEFAULT', USETTFONTS: 'FALSE', TEXTKIND: 0, LOCKED: 'FALSE' }));
}

// Deliberately do not copy any source DXPRule records. JLCEDA should own the
// final design-rule setup; physical trace and via sizes are already explicit.
fs.writeFileSync(OUTPUT, out.map(serialize).join('\r\n') + '\r\n', 'ascii');

const outCounts = new Map();
for (const r of out) outCounts.set(get(r, 'RECORD'), (outCounts.get(get(r, 'RECORD')) || 0) + 1);
const routedSignalWidthCounts = new Map();
let shortCopperSegments = 0;
let nonOrthogonal45Segments = 0;
for (const track of routeTracks) {
  if (track.width < 0.50) {
    const width = `${fmt(track.width)}mm`;
    routedSignalWidthCounts.set(width,(routedSignalWidthCounts.get(width)||0)+1);
  }
  const dx=Math.abs(track.x2-track.x1),dy=Math.abs(track.y2-track.y1);
  if (Math.hypot(dx,dy)<0.50) shortCopperSegments++;
  const angle=Math.atan2(dy,dx)*180/Math.PI;
  if (Math.min(Math.abs(angle),Math.abs(angle-45),Math.abs(angle-90))>0.1)
    nonOrthogonal45Segments++;
}
const audit = [
  'Aquarium ATO V1.0 - JLCEDA generation audit',
  `Generated=${new Date().toISOString()}`,
  `Source=${path.relative(ROOT, SOURCE)}`,
  `LayoutScript=${path.basename(PAS)}`,
  `PlacementCrossCheck=${path.basename(PLACEMENT_PAS)}`,
  `RoutingScript=${path.basename(ROUTING_PAS)}`,
  `SilkscreenScript=${path.basename(SILKSCREEN_PAS)}`,
  `Board=${BOARD_WIDTH}x${BOARD_HEIGHT} mm`,
  `Components=${outCounts.get('Component') || 0}`,
  `ComponentPads=${[...padIndex.values()].length}`,
  `MountingHoles=4`,
  `Nets=${outCounts.get('Net') || 0}`,
  `AssignedPads=${assignments.size}`,
  `ManualPlanLinks=${links.length}`,
  `PlannedCopperTracks=${plannedCopperTrackCount}`,
  `PlannedVias=${plannedViaCount}`,
  `UnroutedLinks=${unroutedLinks.length}`,
  `DisconnectedPlanLinks=${connectivityFailures.length}`,
  `EmittedCopperTracks=${emitScriptedCopper ? routeTracks.length : 0}`,
  `EmittedVias=${emitScriptedCopper ? routeVias.length : 0}`,
  `PolygonOutlines=${outCounts.get('Polygon') || 0}`,
  `Designators=${designators.size}`,
  `InheritedDXPRules=${outCounts.get('DXPRule') || 0}`,
  `PadBoardViolations=${padBoardViolations.length}`,
  `ForeignNetPadOverlaps=${foreignNetPadOverlaps.length}`,
  `DirectCopperConflicts=${copperConflicts.length}`,
  'RoutingGrid=0.125mm',
  `RoutingClearance=${ROUTING_CLEARANCE}mm`,
  `MinimumSignalTrackWidth=${SIGNAL_TRACK_WIDTH}mm`,
  `PreferredSignalTrackWidth=${PREFERRED_SIGNAL_TRACK_WIDTH}mm`,
  `RoutedSignalWidthCounts=${[...routedSignalWidthCounts].map(([width,count])=>`${width}:${count}`).join(',')}`,
  `ShortCopperSegmentsUnder0.5mm=${shortCopperSegments}`,
  `NonOrthogonal45Segments=${nonOrthogonal45Segments}`,
  'PathSimplification=CLEARANCE_CHECKED_ORTHOGONAL_45',
  `RoutingMethod=${unroutedLinks.length === 0 && copperConflicts.length === 0 ? 'CLEARANCE_ASTAR_GRID' : 'ROUTE_REJECTED'}`,
  `Status=${emitScriptedCopper ? 'ROUTED_IMPORT_AND_DRC_REQUIRED' : 'GENERATED_SAFE_UNROUTED_BOARD'}`,
  ...copperConflicts.slice(0, 40).map(x => `REJECTED_ROUTE_CONFLICT=${x}`),
  ...(copperConflicts.length > 40 ? [`REJECTED_ROUTE_CONFLICTS_OMITTED=${copperConflicts.length - 40}`] : []),
  ...unroutedLinks.map(x => `UNROUTED_LINK=${x.net}|${x.ra}.${x.pa}|${x.rb}.${x.pb}`),
  ...connectivityFailures.map(x => `DISCONNECTED_LINK=${x.net}|${x.ra}.${x.pa}|${x.rb}.${x.pb}`),
  ...padBoardViolations.map(x => `PAD_OUTSIDE_BOARD=${x}`),
  ...foreignNetPadOverlaps.map(x => `PAD_OVERLAP=${x}`),
  emitScriptedCopper
    ? 'Notice=Repour GND top/bottom and +3V3 top, then run full JLCEDA DRC before fabrication.'
    : 'Notice=Routing failed clearance/connectivity prechecks; copper and pours were rejected. Resolve listed conflicts or unrouted links, then run full DRC.'
];
fs.writeFileSync(AUDIT, audit.join('\r\n') + '\r\n', 'utf8');
console.log(audit.join('\n'));
