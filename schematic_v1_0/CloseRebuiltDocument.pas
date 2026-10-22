Procedure CloseRebuiltDocument;
Var
    Doc : IServerDocument;
    TargetPath : String;
    Lines : TStringList;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0_Rebuilt.PcbDoc';
    Doc := Client.OpenDocument('PCB', TargetPath);
    If Doc <> Nil Then
    Begin
        If Doc.Modified Then Doc.DoFileSave('');
        Client.CloseDocument(Doc);
    End;
    Lines := TStringList.Create;
    Lines.Add('CLOSED=1');
    Lines.SaveToFile('F:\workSapce_PCB\aquarium\schematic_v1_0\close-rebuilt-status.txt');
    Lines.Free;
End;

End.
