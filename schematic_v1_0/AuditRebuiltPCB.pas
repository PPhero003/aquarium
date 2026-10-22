{ PCB audit: distinguishes copper-layer track objects from outline and overlay graphics. }
Var
    Board : IPCB_Board;

Function BoolAsText(AValue : Boolean) : String;
Begin
    If AValue Then Result := 'True'
    Else Result := 'False';
End;

Procedure AuditRebuiltPCB;
Var
    AuditPath : String;
    Lines : TStringList;
    It : IPCB_BoardIterator;
    GI : IPCB_GroupIterator;
    C : IPCB_Component;
    P : IPCB_Pad;
    N : IPCB_Net;
    R : IPCB_Rule;
    T : IPCB_Primitive;
    CompCount, NetCount, RuleCount, PadCount, ComponentPadCount, Unassigned : Integer;
    TrackCount, CopperTrackCount, AssignedCopperTrackCount, NonCopperGraphicTrackCount, ViaCount, ConnectionCount, FreePadCount, OutsideOrigins : Integer;
    BadImportedRuleCount : Integer;
    NamesOnSilk, NamesOnMech, HiddenNames, AreaTextsOnSilk : Integer;
    Txt : IPCB_Text;
Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;
    AuditPath := ExtractFilePath(Board.FileName) + 'rebuilt-pcb-audit.txt';

    Lines := TStringList.Create;
    CompCount := 0; NetCount := 0; RuleCount := 0; PadCount := 0; ComponentPadCount := 0;
    Unassigned := 0; TrackCount := 0; CopperTrackCount := 0; ViaCount := 0; ConnectionCount := 0;
    FreePadCount := 0; OutsideOrigins := 0; BadImportedRuleCount := 0;
    AssignedCopperTrackCount := 0; NonCopperGraphicTrackCount := 0;
    NamesOnSilk := 0; NamesOnMech := 0; HiddenNames := 0;
    AreaTextsOnSilk := 0;

    Lines.Add('REBUILT PCB AUDIT');
    Lines.Add('CurrentDocument=' + Board.FileName);
    Lines.Add('ExpectedBoardBounds=0,0,100,60 mm');

    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do
    Begin
        Inc(CompCount);
        If Not C.NameOn Then Inc(HiddenNames)
        Else If (C.Name.Layer = eTopOverlay) Or (C.Name.Layer = eBottomOverlay) Then
            Inc(NamesOnSilk)
        Else
            Inc(NamesOnMech);
        If (C.X < MMsToCoord(0)) Or (C.X > MMsToCoord(100)) Or
           (C.Y < MMsToCoord(0)) Or (C.Y > MMsToCoord(60)) Then
            Inc(OutsideOrigins);
        GI := C.GroupIterator_Create;
        GI.AddFilter_ObjectSet(MkSet(ePadObject));
        P := GI.FirstPCBObject;
        While P <> Nil Do
        Begin
            Inc(ComponentPadCount);
            If P.Net = Nil Then Inc(Unassigned);
            P := GI.NextPCBObject;
        End;
        C.GroupIterator_Destroy(GI);
        Lines.Add('COMP|' + C.SourceDesignator + '|' + C.Pattern + '|' +
            FloatToStr(CoordToMMs(C.X)) + '|' + FloatToStr(CoordToMMs(C.Y)) + '|' +
            FloatToStr(C.Rotation));
        C := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);

    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eNetObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    N := It.FirstPCBObject;
    While N <> Nil Do
    Begin
        Inc(NetCount);
        Lines.Add('NET|' + N.Name + '|PinCount=' + IntToStr(N.PinCount) +
            '|Visible=' + BoolAsText(N.ConnectsVisible) +
            '|Invalid=' + BoolAsText(N.ConnectivelyInvalid));
        N := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);

    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eRuleObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    R := It.FirstPCBObject;
    While R <> Nil Do
    Begin
        Inc(RuleCount);
        If Pos('copperThickness', R.Name) > 0 Then Inc(BadImportedRuleCount);
        Lines.Add('RULE|' + R.Name + '|' + R.Scope1Expression + '|' + R.Scope2Expression);
        R := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);

    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(ePadObject, eTrackObject, eViaObject, eConnectionObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    T := It.FirstPCBObject;
    While T <> Nil Do
    Begin
        If T.ObjectId = ePadObject Then
            Inc(PadCount);
        If T.ObjectId = eTrackObject Then
        Begin
            Inc(TrackCount);
            If (T.Layer = eTopLayer) Or (T.Layer = eBottomLayer) Then
            Begin
                Inc(CopperTrackCount);
                If T.Net <> Nil Then Inc(AssignedCopperTrackCount);
            End
            Else
                Inc(NonCopperGraphicTrackCount);
        End;
        If T.ObjectId = eViaObject Then Inc(ViaCount);
        If T.ObjectId = eConnectionObject Then Inc(ConnectionCount);
        T := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
    FreePadCount := PadCount - ComponentPadCount;
    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eTextObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    T := It.FirstPCBObject;
    While T <> Nil Do
    Begin
        Txt := T;
        If (Txt.Layer = eTopOverlay) And
           ((Txt.Text = 'POWER / BUCK') Or (Txt.Text = 'PUMP') Or
            (Txt.Text = 'SENSORS') Or (Txt.Text = 'MCU / SWD') Or
            (Txt.Text = 'WIFI / USER')) Then Inc(AreaTextsOnSilk);
        T := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);

    Lines.Insert(2,'Components=' + IntToStr(CompCount));
    Lines.Insert(3,'ComponentOriginsOutsideBoard=' + IntToStr(OutsideOrigins));
    Lines.Insert(4,'Nets=' + IntToStr(NetCount));
    Lines.Insert(5,'Rules=' + IntToStr(RuleCount));
    Lines.Insert(6,'BadImportedRules=' + IntToStr(BadImportedRuleCount));
    Lines.Insert(7,'ComponentPads=' + IntToStr(ComponentPadCount));
    Lines.Insert(8,'UnassignedComponentPads=' + IntToStr(Unassigned));
    Lines.Insert(9,'FreePads=' + IntToStr(FreePadCount));
    Lines.Insert(10,'DatabasePads=' + IntToStr(PadCount));
    Lines.Insert(11,'Tracks=' + IntToStr(TrackCount));
    Lines.Insert(12,'CopperLayerTracks=' + IntToStr(CopperTrackCount));
    Lines.Insert(13,'NetAssignedCopperTracks=' + IntToStr(AssignedCopperTrackCount));
    Lines.Insert(14,'NonCopperGraphicTracks=' + IntToStr(NonCopperGraphicTrackCount));
    Lines.Insert(15,'Vias=' + IntToStr(ViaCount));
    Lines.Insert(16,'Connections=' + IntToStr(ConnectionCount));
    Lines.Add('SilkDesignators=' + IntToStr(NamesOnSilk));
    Lines.Add('NonSilkDesignators=' + IntToStr(NamesOnMech));
    Lines.Add('HiddenDesignators=' + IntToStr(HiddenNames));
    Lines.Add('AreaLabelsOnTopOverlay=' + IntToStr(AreaTextsOnSilk));
    Lines.Add('Note=AD19 silk counts do NOT replace DRC / Gerber review');
    Lines.SaveToFile(AuditPath);
    Lines.Free;
End;

End.
