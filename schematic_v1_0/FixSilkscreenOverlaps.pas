{ AD19 deterministic silkscreen placement. }
{ Does not use PCB rectangle records because their fields are not reliable through }
{ the AD19 external DelphiScript entry point. No copper or component is moved. }
Var
    SL_Board : IPCB_Board;
    SL_Placed, SL_Errors, SL_FunctionTexts : Integer;
    SL_Log : TStringList;

Function SL_FindComponent(ARef : String) : IPCB_Component;
Var It : IPCB_BoardIterator; C : IPCB_Component;
Begin
    Result := Nil;
    It := SL_Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do
    Begin
        If C.SourceDesignator = ARef Then
        Begin
            Result := C;
            Break;
        End;
        C := It.NextPCBObject;
    End;
    SL_Board.BoardIterator_Destroy(It);
End;

Function SL_IsZoneText(S : String) : Boolean;
Begin
    Result := (S = 'AQUARIUM ATO V1.0') Or
              (S = 'POWER / BUCK') Or (S = 'PUMP') Or
              (S = 'SENSORS') Or (S = 'MCU / SWD') Or
              (S = 'WIFI / USER') Or
              (S = 'PLACEMENT ONLY - UNROUTED') Or
              (S = 'MANUAL COPPER - CHECK DRC');
End;

Procedure SL_MoveZoneTexts;
Var It : IPCB_BoardIterator; T : IPCB_Text;
Begin
    It := SL_Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eTextObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    T := It.FirstPCBObject;
    While T <> Nil Do
    Begin
        If (T.Layer = eTopOverlay) And SL_IsZoneText(T.Text) Then
        Begin
            PCBServer.SendMessageToRobots(T.I_ObjectAddress, c_Broadcast,
                PCBM_BeginModify, c_NoEventData);
            T.Layer := eMechanical2;
            PCBServer.SendMessageToRobots(T.I_ObjectAddress, c_Broadcast,
                PCBM_EndModify, c_NoEventData);
            Inc(SL_FunctionTexts);
        End;
        T := It.NextPCBObject;
    End;
    SL_Board.BoardIterator_Destroy(It);
End;

Procedure SL_PlaceName(ARef : String; Xmm, Ymm : Double);
Var C : IPCB_Component; Dsg : IPCB_Text;
Begin
    C := SL_FindComponent(ARef);
    If C = Nil Then
    Begin
        Inc(SL_Errors);
        SL_Log.Add('NAME_COMPONENT_MISSING|' + ARef);
        Exit;
    End;
    Dsg := C.Name;
    PCBServer.SendMessageToRobots(C.I_ObjectAddress, c_Broadcast,
        PCBM_BeginModify, c_NoEventData);
    C.NameOn := True;
    C.NameAutoPosition := eAutoPos_Manual;
    Dsg.Text := ARef;
    Dsg.Layer := eTopOverlay;
    Dsg.Size := MMsToCoord(0.72);
    Dsg.Width := MMsToCoord(0.11);
    Dsg.Rotation := 0;
    Dsg.XLocation := MMsToCoord(Xmm);
    Dsg.YLocation := MMsToCoord(Ymm);
    C.Rebuild;
    C.SetState_xSizeySize;
    PCBServer.SendMessageToRobots(C.I_ObjectAddress, c_Broadcast,
        PCBM_EndModify, c_NoEventData);
    Inc(SL_Placed);
    SL_Log.Add('TOP_OVERLAY|' + ARef + '|' + FloatToStr(Xmm) + '|' + FloatToStr(Ymm));
End;

Procedure SL_Layout;
Begin
    SL_Placed := 0; SL_Errors := 0; SL_FunctionTexts := 0;
    SL_Log := TStringList.Create;
    SL_Log.Add('AD19 deterministic designator placement; no record-field access');
    SL_MoveZoneTexts;
    SL_PlaceName('J1',8.21,52.50); SL_PlaceName('F1',23.04,57.45);
    SL_PlaceName('Q1',33.04,58.00); SL_PlaceName('R1',31.04,45.36);
    SL_PlaceName('D1',26.04,49.60); SL_PlaceName('C1',42.04,57.88);
    SL_PlaceName('C2',47.05,51.64); SL_PlaceName('C3',50.05,45.31);
    SL_PlaceName('U1',51.04,56.40); SL_PlaceName('C4',55.54,54.37);
    SL_PlaceName('L1',60.04,57.23); SL_PlaceName('C5',67.04,51.12);
    SL_PlaceName('C6',71.04,51.12); SL_PlaceName('Q2',81.10,56.20);
    SL_PlaceName('R4',79.04,49.34); SL_PlaceName('R5',84.04,49.34);
    SL_PlaceName('D2',87.54,56.04); SL_PlaceName('J2',95.54,48.27);
    SL_PlaceName('U3',56.82,37.39); SL_PlaceName('C7',52.92,35.35);
    SL_PlaceName('C8',49.15,30.48); SL_PlaceName('R8',51.54,23.51);
    SL_PlaceName('C15',56.66,27.58); SL_PlaceName('SW3',66.66,34.22);
    SL_PlaceName('J5',57.04,46.00); SL_PlaceName('J7',95.54,39.81);
    SL_PlaceName('C16',89.16,32.64); SL_PlaceName('C17',85.66,32.12);
    SL_PlaceName('C18',86.66,39.77); SL_PlaceName('R2',71.04,39.34);
    SL_PlaceName('R3',72.54,35.34); SL_PlaceName('R25',76.65,39.59);
    SL_PlaceName('R18',76.65,35.59); SL_PlaceName('R6',74.04,20.44);
    SL_PlaceName('SW1',76.66,10.22); SL_PlaceName('C13',79.66,20.64);
    SL_PlaceName('R7',84.04,20.44); SL_PlaceName('SW2',86.66,10.22);
    SL_PlaceName('C14',89.66,20.64); SL_PlaceName('R9',74.04,25.34);
    SL_PlaceName('D3',79.00,25.43); SL_PlaceName('R10',84.66,25.34);
    SL_PlaceName('D4',90.00,25.43); SL_PlaceName('U2',35.04,19.87);
    SL_PlaceName('C12',27.66,29.64); SL_PlaceName('R14',28.66,36.09);
    SL_PlaceName('R11',33.66,36.09); SL_PlaceName('R12',38.65,35.84);
    SL_PlaceName('R13',43.66,35.84); SL_PlaceName('J3',13.04,5.00);
    SL_PlaceName('C9',8.05,12.64); SL_PlaceName('R19',10.66,17.06);
    SL_PlaceName('R20',14.66,17.06); SL_PlaceName('R15',18.66,12.44);
    SL_PlaceName('J4',37.04,5.00); SL_PlaceName('C10',31.66,12.64);
    SL_PlaceName('R21',34.66,17.06); SL_PlaceName('R22',38.66,17.06);
    SL_PlaceName('R16',42.66,12.44); SL_PlaceName('J6',61.04,5.00);
    SL_PlaceName('C11',55.66,12.64); SL_PlaceName('R23',58.65,17.06);
    SL_PlaceName('R24',62.66,17.06); SL_PlaceName('R17',66.66,12.44);
    SL_Log.Add('PLACED_TOP_OVERLAY=' + IntToStr(SL_Placed));
    SL_Log.Add('NAME_ERRORS=' + IntToStr(SL_Errors));
    SL_Log.Add('AREA_TEXTS_TO_MECHANICAL2=' + IntToStr(SL_FunctionTexts));
End;

Procedure SL_SaveReport;
Var P : String;
Begin
    P := ExtractFilePath(SL_Board.FileName);
    If P <> '' Then SL_Log.SaveToFile(P + 'silkscreen-report.txt');
    SL_Log.Free;
End;

Procedure FixSilkscreenOverlaps;
Begin
    SL_Board := PCBServer.GetCurrentPCBBoard;
    If SL_Board = Nil Then Exit;
    PCBServer.PreProcess;
    Try
        SL_Layout;
    Finally
        PCBServer.PostProcess;
    End;
    SL_Board.ViewManager_FullUpdate;
    SL_SaveReport;
End;

End.
