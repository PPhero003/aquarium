Var
    Board : IPCB_Board;

Function FindComponent(ARef : String) : IPCB_Component;
Var It : IPCB_BoardIterator; C : IPCB_Component;
Begin
    Result := Nil;
    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do
    Begin
        If C.SourceDesignator = ARef Then Begin Result := C; Break; End;
        C := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
End;

Procedure Place(ARef : String; Xmm, Ymm, ARotation : Double);
Var C : IPCB_Component; DeltaAngle : Double;
Begin
    C := FindComponent(ARef);
    If C = Nil Then Exit;
    PCBServer.SendMessageToRobots(C.I_ObjectAddress, c_Broadcast,
        PCBM_BeginModify, c_NoEventData);
    DeltaAngle := ARotation - C.Rotation;
    While DeltaAngle > 180 Do DeltaAngle := DeltaAngle - 360;
    While DeltaAngle <= -180 Do DeltaAngle := DeltaAngle + 360;
    If DeltaAngle <> 0 Then C.RotateAroundXY(C.X, C.Y, DeltaAngle);
    C.MoveByXY(MMsToCoord(Xmm) - C.X, MMsToCoord(Ymm) - C.Y);
    C.Layer := eTopLayer;
    C.NameOn := True;
    C.CommentOn := False;
    C.Name.Text := ARef;
    C.Name.Layer := eTopOverlay;
    C.Name.Size := MMsToCoord(0.8);
    C.Name.Width := MMsToCoord(0.12);
    C.Name.Rotation := 0;
    C.NameAutoPosition := eAutoPos_TopCenter;
    C.AutoPosition_NameComment;
    C.Rebuild;
    C.SetState_xSizeySize;
    PCBServer.SendMessageToRobots(C.I_ObjectAddress, c_Broadcast,
        PCBM_EndModify, c_NoEventData);
End;

Function FindPadByName(AName : String) : IPCB_Pad;
Var It : IPCB_BoardIterator; P : IPCB_Pad;
Begin
    Result := Nil;
    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(ePadObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    P := It.FirstPCBObject;
    While P <> Nil Do
    Begin
        If P.Name = AName Then Begin Result := P; Break; End;
        P := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
End;

Procedure MountingHole(AName : String; Xmm, Ymm : Double);
Var P : IPCB_Pad;
Begin
    P := FindPadByName(AName);
    If P = Nil Then
    Begin
        P := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
        P.Name := AName;
        Board.AddPCBObject(P);
        PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast,
            PCBM_BoardRegisteration, P.I_ObjectAddress);
    End;
    P.X := MMsToCoord(Xmm); P.Y := MMsToCoord(Ymm);
    P.Layer := eMultiLayer; P.Mode := ePadMode_Simple;
    P.HoleSize := MMsToCoord(3.20);
    P.TopShape := eRounded;
    P.TopXSize := MMsToCoord(3.20); P.TopYSize := MMsToCoord(3.20);
    P.Plated := False;
End;

Procedure SetBoardOutline100x60;
Var O : IPCB_BoardOutline; S : TPolySegment;
Begin
    O := Board.BoardOutline;
    PCBServer.SendMessageToRobots(O.I_ObjectAddress, c_Broadcast,
        PCBM_BeginModify, c_NoEventData);
    O.SetState_PointCount(4);
    S := TPolySegment; S.Kind := ePolySegmentLine;
    S.vx := MMsToCoord(0); S.vy := MMsToCoord(0); O.SetState_Segments(0,S);
    S := TPolySegment; S.Kind := ePolySegmentLine;
    S.vx := MMsToCoord(100); S.vy := MMsToCoord(0); O.SetState_Segments(1,S);
    S := TPolySegment; S.Kind := ePolySegmentLine;
    S.vx := MMsToCoord(100); S.vy := MMsToCoord(60); O.SetState_Segments(2,S);
    S := TPolySegment; S.Kind := ePolySegmentLine;
    S.vx := MMsToCoord(0); S.vy := MMsToCoord(60); O.SetState_Segments(3,S);
    O.Invalidate; O.Rebuild; O.Validate;
    PCBServer.SendMessageToRobots(O.I_ObjectAddress, c_Broadcast,
        PCBM_EndModify, c_NoEventData);
    Board.UpdateBoardOutline;
End;

Function RectsWithinGap(A, B : TCoordRect; Gap : TCoord) : Boolean;
Begin
    Result := (A.Left < B.Right + Gap) And (A.Right + Gap > B.Left) And
              (A.Bottom < B.Top + Gap) And (A.Top + Gap > B.Bottom);
End;

Procedure WriteLayoutStatus(Doc : IServerDocument);
Var Lines : TStringList; It1, It2 : IPCB_BoardIterator;
    C1, C2 : IPCB_Component; GI : IPCB_GroupIterator; P : IPCB_Pad;
    Obj : IPCB_Primitive; R1, R2, BoardR : TCoordRect;
    I, J, Components, ComponentPads, Pads, Nets, Rules, Connections : Integer;
    BodyGapViolations, NameBodyOverlaps, NameNameOverlaps, NamesOutside : Integer;
Begin
    Components := 0; ComponentPads := 0; Pads := 0; Nets := 0; Rules := 0;
    Connections := 0; BodyGapViolations := 0; NameBodyOverlaps := 0;
    NameNameOverlaps := 0; NamesOutside := 0;
    BoardR := Board.BoardOutline.BoundingRectangle;

    It1 := Board.BoardIterator_Create;
    It1.AddFilter_ObjectSet(MkSet(eComponentObject));
    It1.AddFilter_LayerSet(AllLayers); It1.AddFilter_Method(eProcessAll);
    C1 := It1.FirstPCBObject;
    While C1 <> Nil Do
    Begin
        Inc(Components);
        GI := C1.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject));
        P := GI.FirstPCBObject;
        While P <> Nil Do Begin Inc(ComponentPads); P := GI.NextPCBObject; End;
        C1.GroupIterator_Destroy(GI);
        R1 := C1.Name.BoundingRectangle;
        If (R1.Left < BoardR.Left) Or (R1.Right > BoardR.Right) Or
           (R1.Bottom < BoardR.Bottom) Or (R1.Top > BoardR.Top) Then Inc(NamesOutside);
        C1 := It1.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It1);

    It1 := Board.BoardIterator_Create;
    It1.AddFilter_ObjectSet(MkSet(eComponentObject));
    It1.AddFilter_LayerSet(AllLayers); It1.AddFilter_Method(eProcessAll);
    I := 0; C1 := It1.FirstPCBObject;
    While C1 <> Nil Do
    Begin
        R1 := C1.BoundingRectangleNoNameComment;
        It2 := Board.BoardIterator_Create;
        It2.AddFilter_ObjectSet(MkSet(eComponentObject));
        It2.AddFilter_LayerSet(AllLayers); It2.AddFilter_Method(eProcessAll);
        J := 0; C2 := It2.FirstPCBObject;
        While C2 <> Nil Do
        Begin
            If J > I Then
            Begin
                R2 := C2.BoundingRectangleNoNameComment;
                If RectsWithinGap(R1,R2,MMsToCoord(0.50)) Then Inc(BodyGapViolations);
                If RectsWithinGap(C1.Name.BoundingRectangle,C2.Name.BoundingRectangle,0) Then
                    Inc(NameNameOverlaps);
            End;
            If C1 <> C2 Then
                If RectsWithinGap(C1.Name.BoundingRectangle,
                    C2.BoundingRectangleNoNameComment,0) Then Inc(NameBodyOverlaps);
            Inc(J); C2 := It2.NextPCBObject;
        End;
        Board.BoardIterator_Destroy(It2);
        Inc(I); C1 := It1.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It1);

    It1 := Board.BoardIterator_Create;
    It1.AddFilter_ObjectSet(MkSet(ePadObject,eNetObject,eRuleObject,eConnectionObject));
    It1.AddFilter_LayerSet(AllLayers); It1.AddFilter_Method(eProcessAll);
    Obj := It1.FirstPCBObject;
    While Obj <> Nil Do
    Begin
        If Obj.ObjectId = ePadObject Then Inc(Pads);
        If Obj.ObjectId = eNetObject Then Inc(Nets);
        If Obj.ObjectId = eRuleObject Then Inc(Rules);
        If Obj.ObjectId = eConnectionObject Then Inc(Connections);
        Obj := It1.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It1);

    Lines := TStringList.Create;
    Lines.Add('Document=' + Doc.FileName);
    Lines.Add('Components=' + IntToStr(Components));
    Lines.Add('ComponentPads=' + IntToStr(ComponentPads));
    Lines.Add('DatabasePads=' + IntToStr(Pads));
    Lines.Add('FreePads=' + IntToStr(Pads-ComponentPads));
    Lines.Add('Nets=' + IntToStr(Nets));
    Lines.Add('Rules=' + IntToStr(Rules));
    Lines.Add('Connections=' + IntToStr(Connections));
    Lines.Add('BodyGapViolationsUnder0.50mm=' + IntToStr(BodyGapViolations));
    Lines.Add('NameBodyOverlaps=' + IntToStr(NameBodyOverlaps));
    Lines.Add('NameNameOverlaps=' + IntToStr(NameNameOverlaps));
    Lines.Add('NamesOutsideBoard=' + IntToStr(NamesOutside));
    Lines.SaveToFile('F:\workSapce_PCB\aquarium\schematic_v1_0\rebuilt-layout-status.txt');
    Lines.Free;
End;

Procedure LayoutEdaImportedPCB;
Var TargetPath : String; Doc : IServerDocument;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0_Rebuilt.PcbDoc';
    Doc := Client.OpenDocument('PCB', TargetPath);
    If Doc <> Nil Then Client.ShowDocument(Doc);
    Board := PCBServer.GetPCBBoardByPath(TargetPath);
    If Board = Nil Then Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    Board.DisplayUnit := eMetric;
    PCBServer.PreProcess;
    SetBoardOutline100x60;
    { User origin at the board upper-left corner. }
    Board.SetState_XOrigin(MMsToCoord(0));
    Board.SetState_YOrigin(MMsToCoord(60));
    { Four M3 NPTH mounting holes; keep the 8 x 8 mm corner zones clear. }
    MountingHole('MH1',4,56);
    MountingHole('MH2',96,56);
    MountingHole('MH3',4,4);
    MountingHole('MH4',96,4);

    { Power input and buck converter: left-to-right compact power path. }
    Place('J1',12.5,45,0);
    Place('F1', 24,55,0);
    Place('Q1', 34,54,0);
    Place('R1', 32,48,0);
    Place('D1', 27,48,0);
    Place('C1', 43,54,0);
    Place('C2', 48,49,90);
    Place('C3', 51,49,90);
    Place('U1', 52,54,0);
    Place('C4',56.5,57,0);
    Place('L1', 61,54,0);
    Place('C5', 68,49,90);
    Place('C6', 72,49,90);

    { Pump high-current switch and output at the upper-right edge. }
    Place('R4', 80,48,0);
    Place('R5', 85,48,0);
    Place('Q2', 82,54,0);
    Place('D2', 89,54,0);
    Place('J2',96.5,45,90);

    { Controller in the middle, with local bypass and SWD above it. }
    Place('U3', 58,33,0);
    Place('C7',52.5,36,90);
    Place('C8', 52.5,31,90);
    Place('R8', 52.5,27,90);
    Place('C15',58,26,0);
    Place('SW3',68,32,0);
    Place('J5', 58,44,0);

    { Auxiliary/Wi-Fi interface at right edge, with support parts inside. }
    Place('J7',96.5,34,90);
    Place('C16',90.5,30,90);
    Place('C17',87,30,90);
    Place('C18',88,38,0);
    Place('R2', 72,38,0);
    Place('R3',73.5,34,0);
    Place('R25',78,38,0);
    Place('R18',78,34,0);

    { Local user interface kept along the lower-right edge. }
    Place('R6', 75,18,90);
    Place('SW1',78,8,0);
    Place('C13',81,18,90);
    Place('R7',88,18,90);
    Place('SW2',90,8,0);
    Place('C14',94,18,90);
    Place('R9', 75,24,0);
    Place('D3', 80,24,0);
    Place('R10',88,24,0);
    Place('D4',93,24,0);

    { Sensor mux and three repeated sensor channels along bottom edge. }
    Place('U2',36,27,90);
    Place('C12',29,27,90);
    Place('R14',30,34.5,0);
    Place('R11',35,34.5,0);
    Place('R12',40,34.5,0);
    Place('R13',45,34.5,0);

    Place('J3',14,3,0);
    Place('C9',9,10,90);
    Place('R19',12,15,90);
    Place('R20',16,15,90);
    Place('R15',20,10,90);

    Place('J4',38,3,0);
    Place('C10',33,10,90);
    Place('R21',36,15,90);
    Place('R22',40,15,90);
    Place('R16',44,10,90);

    Place('J6',62,3,0);
    Place('C11',57,10,90);
    Place('R23',60,15,90);
    Place('R24',64,15,90);
    Place('R17',68,10,90);

    PCBServer.PostProcess;
    Board.ViewManager_FullUpdate;
    Doc.DoFileSave('');
    WriteLayoutStatus(Doc);
End;

End.
