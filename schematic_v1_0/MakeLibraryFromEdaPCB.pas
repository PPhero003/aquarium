Procedure MakeLibraryFromEdaPCB;
Var TargetPath, ReportPath : String; Doc : IServerDocument; Lines : TStringList;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0.PcbDoc';
    ReportPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\pcb-library-extract.txt';
    Doc := Client.OpenDocument('PCB', TargetPath);
    If Doc = Nil Then Exit;
    Client.ShowDocument(Doc);
    ResetParameters;
    AddStringParameter('AddLibraryToProject','True');
    RunProcess('MakeLib:BuildPCBLibrary');
    Lines := TStringList.Create;
    Lines.Add('Source=Aquarium_ATO_V1_0.PcbDoc');
    Lines.Add('Process=MakeLib:BuildPCBLibrary');
    Lines.Add('ExpectedLibrary=Aquarium_ATO_V1_0.PcbLib');
    Lines.SaveToFile(ReportPath);
    Lines.Free;
End;

End.
