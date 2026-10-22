Procedure SetBoardOutlineTest;
Var
    TargetPath, OutPath : String;
    Doc : IServerDocument;
    Board : IPCB_Board;
    O : IPCB_BoardOutline;
    S : TPolySegment;
    BR : TCoordRect;
    Lines : TStringList;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0.PcbDoc';
    OutPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\board-outline-test.txt';
    Doc := Client.OpenDocument('PCB', TargetPath);
    If Doc <> Nil Then Client.ShowDocument(Doc);
    Board := PCBServer.GetPCBBoardByPath(TargetPath);
    If Board = Nil Then Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;
    PCBServer.PreProcess;
    O := Board.BoardOutline;
    PCBServer.SendMessageToRobots(O.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
    O.SetState_PointCount(4);
    S := TPolySegment; S.Kind := ePolySegmentLine; S.vx := MMsToCoord(0); S.vy := MMsToCoord(0);
    O.SetState_Segments(0,S);
    S := TPolySegment; S.Kind := ePolySegmentLine; S.vx := MMsToCoord(120); S.vy := MMsToCoord(0);
    O.SetState_Segments(1,S);
    S := TPolySegment; S.Kind := ePolySegmentLine; S.vx := MMsToCoord(120); S.vy := MMsToCoord(80);
    O.SetState_Segments(2,S);
    S := TPolySegment; S.Kind := ePolySegmentLine; S.vx := MMsToCoord(0); S.vy := MMsToCoord(80);
    O.SetState_Segments(3,S);
    O.Invalidate; O.Rebuild; O.Validate;
    PCBServer.SendMessageToRobots(O.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
    Board.UpdateBoardOutline;
    PCBServer.PostProcess;
    BR := O.BoundingRectangle;
    Lines := TStringList.Create;
    Lines.Add('Left=' + FloatToStr(CoordToMMs(BR.Left)));
    Lines.Add('Bottom=' + FloatToStr(CoordToMMs(BR.Bottom)));
    Lines.Add('Right=' + FloatToStr(CoordToMMs(BR.Right)));
    Lines.Add('Top=' + FloatToStr(CoordToMMs(BR.Top)));
    Lines.Add('Width=' + FloatToStr(CoordToMMs(BR.Right-BR.Left)));
    Lines.Add('Height=' + FloatToStr(CoordToMMs(BR.Top-BR.Bottom)));
    Lines.SaveToFile(OutPath); Lines.Free;
    Board.SaveToFile(TargetPath);
End;

End.
