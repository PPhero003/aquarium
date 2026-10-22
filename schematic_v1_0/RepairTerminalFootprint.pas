Var RepairFp : IPCB_LibComponent;

Procedure AddTerminalPad(AName : String; Xmm : Double);
Var NP : IPCB_Pad;
Begin
    NP := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    NP.X := MMsToCoord(Xmm); NP.Y := MMsToCoord(0);
    NP.Layer := eMultiLayer; NP.Name := AName; NP.Mode := ePadMode_Simple;
    NP.HoleSize := MMsToCoord(1.20);
    NP.TopShape := eRounded;
    NP.TopXSize := MMsToCoord(2.40); NP.TopYSize := MMsToCoord(2.40);
    RepairFp.AddPCBObject(NP);
    PCBServer.SendMessageToRobots(RepairFp.I_ObjectAddress, c_Broadcast,
        PCBM_BoardRegisteration, NP.I_ObjectAddress);
End;

Procedure RepairTerminalFootprint;
Var
    LibPath, AuditPath : String;
    Lib : IPCB_Library;
    LI : IPCB_LibraryIterator;
    Fp : IPCB_LibComponent;
    GI : IPCB_GroupIterator;
    P : IPCB_Pad;
    PadCount : Integer;
    Lines : TStringList;

Begin
    LibPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_Footprints_V1_1.PcbLib';
    AuditPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\terminal-footprint-repair.txt';
    Lib := PCBServer.GetPCBLibraryByPath(LibPath);
    If Lib = Nil Then Exit;
    Fp := Nil;
    LI := Lib.LibraryIterator_Create; LI.SetState_FilterAll;
    Try
        Fp := LI.FirstPCBObject;
        While Fp <> Nil Do
        Begin
            If Fp.Name = 'TB_2P_P5.08' Then Break;
            Fp := LI.NextPCBObject;
        End;
    Finally
        Lib.LibraryIterator_Destroy(LI);
    End;
    If Fp = Nil Then Exit;
    RepairFp := Fp;
    PadCount := 0;
    GI := Fp.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject));
    P := GI.FirstPCBObject;
    While P <> Nil Do Begin Inc(PadCount); P := GI.NextPCBObject; End;
    Fp.GroupIterator_Destroy(GI);
    If PadCount = 0 Then
    Begin
        PCBServer.PreProcess;
        AddTerminalPad('1',-2.54);
        AddTerminalPad('2', 2.54);
        PCBServer.PostProcess;
        PadCount := 2;
    End;
    Lines := TStringList.Create;
    Lines.Add('Footprint=TB_2P_P5.08');
    Lines.Add('Pads=' + IntToStr(PadCount));
    Lines.Add('SaveRequired=Yes');
    Lines.SaveToFile(AuditPath); Lines.Free;
    Lib.Board.ViewManager_FullUpdate;
End;

End.
