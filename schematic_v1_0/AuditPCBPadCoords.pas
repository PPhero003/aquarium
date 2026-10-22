Procedure AuditPCBPadCoords;
Var
    TargetPath, OutPath : String;
    Doc : IServerDocument;
    Board : IPCB_Board;
    BI : IPCB_BoardIterator;
    C : IPCB_Component;
    GI : IPCB_GroupIterator;
    P : IPCB_Pad;
    Lines : TStringList;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0.PcbDoc';
    OutPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\pcb-pad-coordinate-probe.txt';
    Doc := Client.OpenDocument('PCB', TargetPath);
    If Doc <> Nil Then Client.ShowDocument(Doc);
    Board := PCBServer.GetPCBBoardByPath(TargetPath);
    If Board = Nil Then Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;
    Lines := TStringList.Create;
    Lines.Add('REF|CX|CY|PAD|PX|PY');
    BI := Board.BoardIterator_Create;
    BI.AddFilter_ObjectSet(MkSet(eComponentObject));
    BI.AddFilter_LayerSet(AllLayers);
    BI.AddFilter_Method(eProcessAll);
    C := BI.FirstPCBObject;
    While C <> Nil Do
    Begin
        GI := C.GroupIterator_Create;
        GI.AddFilter_ObjectSet(MkSet(ePadObject));
        P := GI.FirstPCBObject;
        While P <> Nil Do
        Begin
            Lines.Add(C.SourceDesignator + '|' + FloatToStr(CoordToMMs(C.X)) + '|' +
                FloatToStr(CoordToMMs(C.Y)) + '|' + P.Name + '|' +
                FloatToStr(CoordToMMs(P.X)) + '|' + FloatToStr(CoordToMMs(P.Y)));
            P := GI.NextPCBObject;
        End;
        C.GroupIterator_Destroy(GI);
        C := BI.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(BI);
    Lines.SaveToFile(OutPath);
    Lines.Free;
End;

End.
