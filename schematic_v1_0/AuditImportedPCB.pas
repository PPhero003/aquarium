Var
    Board : IPCB_Board;

Procedure AuditImportedPCB;
Var
    TargetPath, AuditPath : String;
    Doc : IServerDocument;
    Lines : TStringList;
    It : IPCB_BoardIterator;
    GI : IPCB_GroupIterator;
    C : IPCB_Component;
    P : IPCB_Pad;
    T : IPCB_Primitive;
    N : IPCB_Net;
    BR, BoardBR : TCoordRect;
    CompCount, PadCount, NetCount, Unassigned, OutsideCount : Integer;
    TrackCount, CopperTrackCount, ViaCount, ConnectionCount, FreePadCount, AllPadCount : Integer;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0.PcbDoc';
    AuditPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\eda-import-pcb-audit.txt';

    Doc := Client.OpenDocument('PCB', TargetPath);
    If Doc <> Nil Then Client.ShowDocument(Doc);
    Board := PCBServer.GetPCBBoardByPath(TargetPath);
    If Board = Nil Then Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    Lines := TStringList.Create;
    CompCount := 0; PadCount := 0; NetCount := 0;
    Unassigned := 0; OutsideCount := 0;
    TrackCount := 0; CopperTrackCount := 0; ViaCount := 0; ConnectionCount := 0; FreePadCount := 0; AllPadCount := 0;

    Board.BoardOutline.Invalidate;
    Board.BoardOutline.Rebuild;
    Board.BoardOutline.Validate;
    BoardBR := Board.BoardOutline.BoundingRectangle;
    Lines.Add('EDA imported PCB audit');
    Lines.Add('BoardBounds=' + FloatToStr(CoordToMMs(BoardBR.Left)) + ',' +
        FloatToStr(CoordToMMs(BoardBR.Bottom)) + ',' +
        FloatToStr(CoordToMMs(BoardBR.Right)) + ',' +
        FloatToStr(CoordToMMs(BoardBR.Top)) + ' mm');
    Lines.Add('UserOrigin=' + FloatToStr(CoordToMMs(Board.XOrigin)) + ',' +
        FloatToStr(CoordToMMs(Board.YOrigin)) + ' mm');

    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do
    Begin
        Inc(CompCount);
        BR := C.BoundingRectangleNoNameComment;
        If (BR.Left < BoardBR.Left) Or (BR.Right > BoardBR.Right) Or
           (BR.Bottom < BoardBR.Bottom) Or (BR.Top > BoardBR.Top) Then Inc(OutsideCount);
        GI := C.GroupIterator_Create;
        GI.AddFilter_ObjectSet(MkSet(ePadObject));
        P := GI.FirstPCBObject;
        While P <> Nil Do
        Begin
            Inc(PadCount);
            If P.Net = Nil Then Inc(Unassigned);
            P := GI.NextPCBObject;
        End;
        C.GroupIterator_Destroy(GI);
        Lines.Add('COMP|' + C.SourceDesignator + '|' + C.Pattern + '|' +
            FloatToStr(CoordToMMs(C.X)) + '|' + FloatToStr(CoordToMMs(C.Y)) + '|' +
            FloatToStr(C.Rotation) + '|' +
            FloatToStr(CoordToMMs(BR.Left)) + '|' + FloatToStr(CoordToMMs(BR.Bottom)) + '|' +
            FloatToStr(CoordToMMs(BR.Right)) + '|' + FloatToStr(CoordToMMs(BR.Top)));
        C := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);

    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eTrackObject, eViaObject, eConnectionObject, ePadObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    T := It.FirstPCBObject;
    While T <> Nil Do
    Begin
        If T.ObjectId = eTrackObject Then
        Begin
            Inc(TrackCount);
            If T.Net <> Nil Then Inc(CopperTrackCount);
        End;
        If T.ObjectId = eViaObject Then Inc(ViaCount);
        If T.ObjectId = eConnectionObject Then Inc(ConnectionCount);
        If T.ObjectId = ePadObject Then Inc(AllPadCount);
        T := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
    FreePadCount := AllPadCount - PadCount;

    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eNetObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    N := It.FirstPCBObject;
    While N <> Nil Do Begin Inc(NetCount); Lines.Add('NET|' + N.Name); N := It.NextPCBObject; End;
    Board.BoardIterator_Destroy(It);

    Lines.Insert(2, 'Components=' + IntToStr(CompCount));
    Lines.Insert(3, 'Pads=' + IntToStr(PadCount));
    Lines.Insert(4, 'Nets=' + IntToStr(NetCount));
    Lines.Insert(5, 'UnassignedPads=' + IntToStr(Unassigned));
    Lines.Insert(6, 'ComponentsOutsideBoard=' + IntToStr(OutsideCount));
    Lines.Insert(7, 'Tracks=' + IntToStr(TrackCount));
    Lines.Insert(8, 'Vias=' + IntToStr(ViaCount));
    Lines.Insert(9, 'Connections=' + IntToStr(ConnectionCount));
    Lines.Insert(10, 'FreePads=' + IntToStr(FreePadCount));
    Lines.Insert(8, 'CopperTracks=' + IntToStr(CopperTrackCount));
    Lines.SaveToFile(AuditPath);
    Lines.Free;
    Board.ViewManager_FullUpdate;
End;

End.
