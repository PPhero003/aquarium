{ Prepares a copied PcbDoc as a genuinely empty AD19 board container. }
Var
    ResetBoard : IPCB_Board;
    ResetDoc : IServerDocument;

Function RemoveFirstObject(AObjectId : TObjectId) : Boolean;
Var It : IPCB_BoardIterator; Obj : IPCB_Primitive;
Begin
    Result := False;
    It := ResetBoard.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(AObjectId));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    Obj := It.FirstPCBObject;
    ResetBoard.BoardIterator_Destroy(It);
    If Obj <> Nil Then
    Begin
        ResetBoard.RemovePCBObject(Obj);
        Result := True;
    End;
End;

Procedure RemoveEveryObject(AObjectId : TObjectId);
Var Guard : Integer;
Begin
    Guard := 0;
    While RemoveFirstObject(AObjectId) Do
    Begin
        Inc(Guard);
        If Guard > 20000 Then Exit;
    End;
End;

Function CountObject(AObjectId : TObjectId) : Integer;
Var It : IPCB_BoardIterator; Obj : IPCB_Primitive;
Begin
    Result := 0;
    It := ResetBoard.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(AObjectId));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    Obj := It.FirstPCBObject;
    While Obj <> Nil Do Begin Inc(Result); Obj := It.NextPCBObject; End;
    ResetBoard.BoardIterator_Destroy(It);
End;

Procedure ResetAquariumPCB;
Var TargetPath, ReportPath : String; Lines : TStringList; Remaining : Integer;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0_New.PcbDoc';
    ReportPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\pcb-reset-status.txt';
    ResetDoc := Client.OpenDocument('PCB', TargetPath);
    If ResetDoc = Nil Then Exit;
    Client.ShowDocument(ResetDoc);
    ResetBoard := PCBServer.GetPCBBoardByPath(TargetPath);
    If ResetBoard = Nil Then Exit;

    PCBServer.PreProcess;
    Try
        { Remove groups first, then any orphan/free primitives. }
        RemoveEveryObject(eComponentObject);
        RemoveEveryObject(ePadObject);
        RemoveEveryObject(eTrackObject);
        RemoveEveryObject(eViaObject);
        RemoveEveryObject(eArcObject);
        RemoveEveryObject(eTextObject);
        RemoveEveryObject(eFillObject);
        RemoveEveryObject(eRegionObject);
        RemoveEveryObject(ePolyObject);
        RemoveEveryObject(eComponentBodyObject);
        RemoveEveryObject(eNetObject);
        RemoveEveryObject(eRuleObject);
    Finally
        PCBServer.PostProcess;
    End;

    { One internal board-shape region is retained by AD19 and is not a
      placed design object. }
    Remaining := CountObject(eComponentObject) + CountObject(ePadObject) +
        CountObject(eTrackObject) + CountObject(eViaObject) +
        CountObject(eArcObject) + CountObject(eTextObject) +
        CountObject(eFillObject) +
        CountObject(ePolyObject) + CountObject(eComponentBodyObject) +
        CountObject(eNetObject) + CountObject(eRuleObject);

    ResetDoc.Modified := True;
    ResetDoc.DoFileSave('');
    Lines := TStringList.Create;
    Lines.Add('RESET_COMPLETE=1');
    Lines.Add('REMAINING_OBJECTS=' + IntToStr(Remaining));
    Lines.Add('COMPONENTS=' + IntToStr(CountObject(eComponentObject)));
    Lines.Add('PADS=' + IntToStr(CountObject(ePadObject)));
    Lines.Add('TRACKS=' + IntToStr(CountObject(eTrackObject)));
    Lines.Add('VIAS=' + IntToStr(CountObject(eViaObject)));
    Lines.Add('ARCS=' + IntToStr(CountObject(eArcObject)));
    Lines.Add('TEXTS=' + IntToStr(CountObject(eTextObject)));
    Lines.Add('FILLS=' + IntToStr(CountObject(eFillObject)));
    Lines.Add('REGIONS=' + IntToStr(CountObject(eRegionObject)));
    Lines.Add('POLYGONS=' + IntToStr(CountObject(ePolyObject)));
    Lines.Add('BODIES=' + IntToStr(CountObject(eComponentBodyObject)));
    Lines.Add('NETS=' + IntToStr(CountObject(eNetObject)));
    Lines.Add('RULES=' + IntToStr(CountObject(eRuleObject)));
    Lines.SaveToFile(ReportPath);
    Lines.Free;
End;

End.
