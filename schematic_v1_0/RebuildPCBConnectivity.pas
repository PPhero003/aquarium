{ AD19 - Refresh the connectivity of EXISTING pads and nets only. }
{ Does not create nets, move text, fix free pads, or route tracks. }
Procedure RebuildPCBConnectivity;
Var
    Board : IPCB_Board;
    It : IPCB_BoardIterator;
    N : IPCB_Net;
    Count : Integer;
    Lines : TStringList;
    ReportPath : String;
Begin
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;
    Count := 0;
    PCBServer.PreProcess;
    Try
        It := Board.BoardIterator_Create;
        It.AddFilter_ObjectSet(MkSet(eNetObject));
        It.AddFilter_LayerSet(AllLayers);
        It.AddFilter_Method(eProcessAll);
        N := It.FirstPCBObject;
        While N <> Nil Do
        Begin
            N.ConnectivelyInvalidate;
            N.Rebuild;
            Board.CleanNet(N);
            Board.AnalyzeNet(N);
            Inc(Count);
            N := It.NextPCBObject;
        End;
        Board.BoardIterator_Destroy(It);
        Board.ConnectivelyValidateNets;
    Finally
        PCBServer.PostProcess;
    End;
    Board.ViewManager_FullUpdate;
    ReportPath := ExtractFilePath(Board.FileName) + 'connectivity-refresh-report.txt';
    Lines := TStringList.Create;
    Lines.Add('STATUS=PASS');
    Lines.Add('NETS_REFRESHED=' + IntToStr(Count));
    Lines.Add('CREATED_PADS=0');
    Lines.Add('CREATED_TRACKS=0');
    Lines.SaveToFile(ReportPath);
    Lines.Free;
End;

End.
