Procedure ProbePCBContext;
Var D : IServerDocument; B : IPCB_Board; L : TStringList;
Begin
    L := TStringList.Create;
    L.Add('START');
    D := Client.OpenDocument('PCB', 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0.PcbDoc');
    If D = Nil Then L.Add('Document=Nil') Else
    Begin
        L.Add('Document=OK');
        Client.ShowDocument(D);
    End;
    B := PCBServer.GetPCBBoardByPath('F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0.PcbDoc');
    If B = Nil Then L.Add('BoardByPath=Nil') Else L.Add('BoardByPath=OK');
    B := PCBServer.GetCurrentPCBBoard;
    If B = Nil Then L.Add('CurrentBoard=Nil') Else L.Add('CurrentBoard=OK');
    L.SaveToFile('F:\workSapce_PCB\aquarium\schematic_v1_0\pcb-context-probe.txt');
    L.Free;
End;
