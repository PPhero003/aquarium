// Read-only preflight for rebuilding the Aquarium ATO PCB in JLCEDA Pro.
// Run with any schematic sheet of the imported project focused.

async function main() {
    if (typeof eda === 'undefined') {
        throw new Error('Run this file in the JLCEDA Pro script environment.');
    }

    const document = await eda.dmt_SelectControl.getCurrentDocumentInfo();
    if (!document || document.documentType !== 1) {
        throw new Error('Focus one of the imported project schematic sheets, then run again.');
    }

    const components = await eda.sch_PrimitiveComponent.getAll(undefined, true);
    const rows = components
        .filter(component => typeof component.getState_Designator === 'function')
        .map(component => {
            const device = component.getState_Component();
            const footprint = component.getState_Footprint();
            return {
                ref: component.getState_Designator(),
                value: component.getState_Name(),
                deviceLibraryUuid: device && device.libraryUuid,
                deviceUuid: device && device.uuid,
                deviceType: Object.prototype.toString.call(device),
                deviceKeys: device ? Object.keys(device).join(', ') : '',
                device: device ? `${device.name || ''} [${device.libraryUuid}/${device.uuid}]` : '',
                footprintType: Object.prototype.toString.call(footprint),
                footprintKeys: footprint && typeof footprint === 'object'
                    ? Object.keys(footprint).join(', ')
                    : '',
                footprint: typeof footprint === 'string'
                    ? footprint
                    : footprint
                        ? `${footprint.name || footprint.title || ''} [${footprint.libraryUuid || ''}/${footprint.uuid || ''}]`
                        : '',
                supplierId: component.getState_SupplierId()
            };
        })
        .filter(row => row.ref)
        .sort((a, b) => a.ref.localeCompare(b.ref));

    const refs = rows.map(row => row.ref);
    const duplicates = refs.filter((ref, index) => refs.indexOf(ref) !== index);
    const missingDevice = rows.filter(row => !row.deviceUuid);
    const deviceWithoutLibrary = rows.filter(row => !row.deviceLibraryUuid);
    const missingFootprint = rows.filter(row => !row.footprint);

    console.log('Aquarium PCB preflight');
    console.log('Focused document:', JSON.stringify(document));
    console.log('Schematic component count:', rows.length);
    console.log('Duplicate designators:', JSON.stringify([...new Set(duplicates)]));
    console.log('Components without an EDA device association:', JSON.stringify(missingDevice.map(row => row.ref)));
    console.log('Components without an EDA footprint association:', JSON.stringify(missingFootprint.map(row => row.ref)));
    console.log('Component and library mapping:', JSON.stringify(rows, null, 2));

    const netlist = await eda.sch_Netlist.getNetlist('Protel2');
    if (typeof netlist !== 'string' || netlist.length === 0) {
        throw new Error('The project schematic did not return a Protel2 netlist.');
    }
    console.log('Protel2 netlist character count:', netlist.length);
    console.log('Read-only preflight complete. No PCB or schematic data was changed.');
    await eda.sys_MessageBox.showInformationMessage([
        'Schematic component count: ' + rows.length,
        'Duplicate designators: ' + ([...new Set(duplicates)].join(', ') || 'none'),
        'Missing EDA device UUIDs: ' + (missingDevice.map(row => row.ref).join(', ') || 'none'),
        'Devices without library UUIDs: ' + (deviceWithoutLibrary.map(row => row.ref).join(', ') || 'none'),
        'Missing footprint associations: ' + (missingFootprint.map(row => row.ref).join(', ') || 'none'),
        'Protel2 netlist characters: ' + netlist.length,
        'Sample library mapping: ' + JSON.stringify(rows[0] || null)
    ].join('\n'));
}

main().catch(error => {
    console.error('Aquarium PCB preflight failed:', error);
    throw error;
});
