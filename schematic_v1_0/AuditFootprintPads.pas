Procedure AuditFootprintPads;
Var
    Lib : IPCB_Library; LibIt : IPCB_LibraryIterator; Fp : IPCB_LibComponent;
    PadIt : IPCB_GroupIterator; P : IPCB_Pad; Lines : TStringList;
Begin
    Lib := PCBServer.GetPCBLibraryByPath(
        'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_Footprints_V1_1.PcbLib');
    If Lib = Nil Then Begin ShowMessage('Final PcbLib is not open.'); Exit; End;
    Lines := TStringList.Create;
    Lines.Add('Footprint|Pad|X_mm|Y_mm');
    LibIt := Lib.LibraryIterator_Create; LibIt.SetState_FilterAll;
    Try
        Fp := LibIt.FirstPCBObject;
        While Fp <> Nil Do
        Begin
            PadIt := Fp.GroupIterator_Create;
            PadIt.AddFilter_ObjectSet(MkSet(ePadObject));
            Try
                P := PadIt.FirstPCBObject;
                While P <> Nil Do
                Begin
                    Lines.Add(Fp.Name + '|' + P.Name + '|' +
                        FloatToStr(CoordToMMs(P.X)) + '|' + FloatToStr(CoordToMMs(P.Y)));
                    P := PadIt.NextPCBObject;
                End;
            Finally
                Fp.GroupIterator_Destroy(PadIt);
            End;
            Fp := LibIt.NextPCBObject;
        End;
    Finally
        Lib.LibraryIterator_Destroy(LibIt);
    End;
    Lines.SaveToFile('F:\workSapce_PCB\aquarium\schematic_v1_0\footprint-pad-position-audit.txt');
    ShowMessage('Pad position audit written: ' + IntToStr(Lines.Count - 1));
    Lines.Free;
End;

End.
