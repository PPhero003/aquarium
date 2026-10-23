// Create a separate PCB in the current JLCEDA project, place the 64 schematic
// components using the maintained project layout, and import the schematic netlist.
// The existing Aquarium_ATO_V1_0_LCEDA PCB is never opened for modification.

const PLACEMENT_MM = {
    J1: [12.5, 45, 0],
    F1: [24, 55, 0],
    Q1: [34, 54, 0],
    R1: [32, 48, 0],
    D1: [27, 48, 0],
    C1: [43, 54, 0],
    C2: [47, 52, 90],
    C3: [49, 54, 90],
    U1: [52, 54, 0],
    C4: [54, 57, 0],
    L1: [61, 54, 0],
    C5: [64.5, 54, 90],
    C6: [66.5, 54, 90],
    Q2: [82, 54, 0],
    R4: [80, 48, 0],
    R5: [85, 48, 0],
    D2: [88.5, 54, 0],
    J2: [96.5, 45, 90],
    U3: [58, 33, 0],
    C7: [54, 33.8, 180],
    C8: [52.5, 31, 90],
    R8: [52.5, 27, 90],
    C15: [58, 26, 0],
    SW3: [68, 32, 0],
    J5: [58, 44, 0],
    J7: [96.5, 34, 90],
    C16: [90.5, 30, 90],
    C17: [87, 30, 90],
    C18: [88, 38, 0],
    R2: [72, 38, 0],
    R3: [73.5, 34, 0],
    R25: [78, 38, 0],
    R18: [78, 34, 0],
    R6: [75, 18, 90],
    SW1: [78, 8, 0],
    C13: [81, 18, 90],
    R7: [85, 18, 90],
    SW2: [88, 8, 0],
    C14: [91, 18, 90],
    R9: [75, 24, 0],
    D3: [80, 24, 0],
    R10: [86, 24, 0],
    D4: [91, 24, 0],
    U2: [36, 27, 90],
    C12: [31.5, 22.5, 90],
    R14: [30, 34.5, 0],
    R11: [35, 34.5, 0],
    R12: [40, 34.5, 0],
    R13: [45, 34.5, 0],
    J3: [14, 3, 0],
    C9: [9, 10, 90],
    R19: [12, 15, 90],
    R20: [16, 15, 90],
    R15: [20, 10, 90],
    J4: [38, 3, 0],
    C10: [33, 10, 90],
    R21: [36, 15, 90],
    R22: [40, 15, 90],
    R16: [44, 10, 90],
    J6: [62, 3, 0],
    C11: [57, 10, 90],
    R23: [60, 15, 90],
    R24: [64, 15, 90],
    R17: [68, 10, 90]
};

function sleep(milliseconds) {
    return new Promise(resolve => setTimeout(resolve, milliseconds));
}

function requireApi(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function pcbCoordinateFromMillimeters(value) {
    return value * 1000 / 25.4;
}

async function main() {
    if (typeof eda === 'undefined') {
        throw new Error('Run this file in the JLCEDA Pro script environment.');
    }

    const sourceDocument = await eda.dmt_SelectControl.getCurrentDocumentInfo();
    requireApi(
        sourceDocument && sourceDocument.documentType === 1,
        'Focus one of the imported project schematic sheets before running this script.'
    );

    const sourceComponents = await eda.sch_PrimitiveComponent.getAll(undefined, true);
    const byRef = new Map();
    for (const component of sourceComponents) {
        if (typeof component.getState_Designator !== 'function') {
            continue;
        }
        const ref = component.getState_Designator();
        if (!ref || !Object.prototype.hasOwnProperty.call(PLACEMENT_MM, ref)) {
            continue;
        }
        requireApi(!byRef.has(ref), `Duplicate schematic designator: ${ref}`);
        byRef.set(ref, component);
    }

    const expectedRefs = Object.keys(PLACEMENT_MM);
    const missingRefs = expectedRefs.filter(ref => !byRef.has(ref));
    requireApi(
        missingRefs.length === 0,
        `Schematic is missing expected components: ${missingRefs.join(', ')}`
    );

    const componentData = expectedRefs.map(ref => {
        const schematicComponent = byRef.get(ref);
        const device = schematicComponent.getState_Component();
        const footprint = schematicComponent.getState_Footprint();
        requireApi(
            device && device.uuid,
            `${ref} has no imported EDA device object. Import/link its device library first.`
        );
        requireApi(
            footprint,
            `${ref} has no imported EDA footprint association. Import/link its footprint library first.`
        );
        return { ref, schematicComponent, device, footprint };
    });

    const netlist = await eda.sch_Netlist.getNetlist('Protel2');
    requireApi(
        typeof netlist === 'string' && netlist.length > 0,
        'The project schematic did not return a Protel2 netlist.'
    );
    const missingNetlistRefs = expectedRefs.filter(ref => !netlist.includes(ref));
    requireApi(
        missingNetlistRefs.length === 0,
        `The Protel2 netlist is missing expected designators: ${missingNetlistRefs.join(', ')}`
    );

    const pcbName = `Aquarium_ATO_V1_0_Rebuild_${Date.now()}`;
    const pcbUuid = await eda.dmt_Pcb.createPcb(pcbName);
    requireApi(pcbUuid, `JLCEDA could not create the new PCB "${pcbName}".`);
    console.log('Created separate PCB:', pcbName, pcbUuid);

    await sleep(1500);
    await eda.dmt_EditorControl.openDocument(pcbUuid);
    await sleep(1200);

    const targetDocument = await eda.dmt_SelectControl.getCurrentDocumentInfo();
    requireApi(
        targetDocument &&
            targetDocument.documentType === 3 &&
            targetDocument.uuid === pcbUuid,
        'The new PCB did not become the focused document; no components were placed.'
    );

    const placed = [];
    let padCount = 0;
    for (const item of componentData) {
        const [xMm, yMm, rotation] = PLACEMENT_MM[item.ref];
        const pcbComponent = await eda.pcb_PrimitiveComponent.create(
            item.device,
            1,
            pcbCoordinateFromMillimeters(xMm),
            pcbCoordinateFromMillimeters(yMm),
            rotation,
            false
        );
        requireApi(pcbComponent, `JLCEDA could not place ${item.ref}.`);

        const updated = await eda.pcb_PrimitiveComponent.modify(
            pcbComponent.getState_PrimitiveId(),
            {
                designator: item.ref,
                name: item.schematicComponent.getState_Name() || item.ref
            }
        );
        requireApi(updated, `JLCEDA placed ${item.ref} but could not set its designator.`);
        requireApi(
            updated.getState_Footprint(),
            `${item.ref} was placed without an associated PCB footprint.`
        );
        const pads = await eda.pcb_PrimitiveComponent.getAllPinsByPrimitiveId(
            updated.getState_PrimitiveId()
        );
        requireApi(pads && pads.length > 0, `${item.ref} has no PCB pads after placement.`);
        padCount += pads.length;
        placed.push(updated);
    }

    const netlistImported = await eda.pcb_Net.setNetlist('Protel2', netlist);
    requireApi(netlistImported, 'The new PCB rejected the schematic Protel2 netlist.');

    const finalComponents = await eda.pcb_PrimitiveComponent.getAll(1);
    const finalRefs = finalComponents.map(component => component.getState_Designator());
    const duplicateFinalRefs = finalRefs.filter((ref, index) => finalRefs.indexOf(ref) !== index);
    const missingPlaced = expectedRefs.filter(ref => !finalRefs.includes(ref));
    const unexpectedFinalRefs = finalRefs.filter(ref => !expectedRefs.includes(ref));
    requireApi(
        finalComponents.length === expectedRefs.length &&
            duplicateFinalRefs.length === 0 &&
            unexpectedFinalRefs.length === 0,
        `PCB component set differs from the schematic: total=${finalComponents.length}, ` +
            `duplicates=${[...new Set(duplicateFinalRefs)].join(', ')}, ` +
            `unexpected=${[...new Set(unexpectedFinalRefs)].join(', ')}`
    );
    requireApi(
        missingPlaced.length === 0,
        `PCB verification found components missing after placement: ${missingPlaced.join(', ')}`
    );

    const nets = await eda.pcb_Net.getAllNetName();
    requireApi(nets && nets.length > 0, 'The PCB has no nets after netlist import.');
    console.log('PCB rebuild complete:', JSON.stringify({
        pcbName,
        pcbUuid,
        components: placed.length,
        pads: padCount,
        nets: nets.length,
        routedTracks: 0,
        currentPcbPreserved: true
    }, null, 2));
    console.log('The board is placed and netlisted, but is not routed or DRC-checked.');
    console.log('Review the component footprints and airwires before routing. The original PCB was not changed.');
    await eda.sys_MessageBox.showInformationMessage([
        'New PCB: ' + pcbName,
        'Components placed: ' + placed.length,
        'Pads: ' + padCount,
        'Nets: ' + nets.length,
        'Routing: not performed',
        'Existing PCB: preserved'
    ].join('\n'));
}

main().catch(async error => {
    console.error('Aquarium PCB rebuild failed:', error);
    if (typeof eda !== 'undefined' && eda.sys_MessageBox) {
        await eda.sys_MessageBox.showInformationMessage(
            'Aquarium PCB rebuild failed: ' + (error && error.message ? error.message : String(error))
        );
    }
    throw error;
});
