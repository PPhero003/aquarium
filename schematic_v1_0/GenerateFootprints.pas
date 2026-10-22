{ Generates the project PCB footprints in the active, blank PcbLib. }
Var
    CurrentLib : IPCB_Library;
    NewComp    : IPCB_LibComponent;
    FirstComp  : Boolean;

Procedure RegisterPrimitive(P : IPCB_Primitive);
Begin
    NewComp.AddPCBObject(P);
    PCBServer.SendMessageToRobots(NewComp.I_ObjectAddress, c_Broadcast,
        PCBM_BoardRegisteration, P.I_ObjectAddress);
End;

Procedure StartComponent(AName : String);
Begin
    If FirstComp Then
    Begin
        NewComp := CurrentLib.CurrentComponent;
        If NewComp = Nil Then
        Begin
            NewComp := PCBServer.CreatePCBLibComp;
            CurrentLib.RegisterComponent(NewComp);
        End;
        FirstComp := False;
    End
    Else
    Begin
        NewComp := PCBServer.CreatePCBLibComp;
        { The library indexes the component name at registration time. }
        NewComp.Name := AName;
        CurrentLib.RegisterComponent(NewComp);
    End;
    NewComp.Name := AName;
End;

Procedure FinishComponent;
Begin
    PCBServer.SendMessageToRobots(CurrentLib.Board.I_ObjectAddress, c_Broadcast,
        PCBM_BoardRegisteration, NewComp.I_ObjectAddress);
    CurrentLib.CurrentComponent := NewComp;
End;

Procedure AddSmdPad(AName : String; X, Y, SX, SY : Double; AShape : TShape);
Var P : IPCB_Pad;
Begin
    P := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    P.X := MMsToCoord(X); P.Y := MMsToCoord(Y);
    P.Layer := eTopLayer; P.Name := AName; P.Mode := ePadMode_Simple;
    P.TopShape := AShape; P.TopXSize := MMsToCoord(SX); P.TopYSize := MMsToCoord(SY);
    RegisterPrimitive(P);
End;

Procedure AddThPad(AName : String; X, Y, Size, Hole : Double; AShape : TShape);
Var P : IPCB_Pad;
Begin
    P := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    P.X := MMsToCoord(X); P.Y := MMsToCoord(Y);
    P.Layer := eMultiLayer; P.Name := AName; P.Mode := ePadMode_Simple;
    P.HoleSize := MMsToCoord(Hole);
    P.TopShape := AShape; P.TopXSize := MMsToCoord(Size); P.TopYSize := MMsToCoord(Size);
    RegisterPrimitive(P);
End;

Procedure AddLine(X1, Y1, X2, Y2 : Double);
Var T : IPCB_Track;
Begin
    T := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    T.X1 := MMsToCoord(X1); T.Y1 := MMsToCoord(Y1);
    T.X2 := MMsToCoord(X2); T.Y2 := MMsToCoord(Y2);
    T.Layer := eTopOverlay; T.Width := MMsToCoord(0.20);
    RegisterPrimitive(T);
End;

Procedure AddOutline(X1, Y1, X2, Y2 : Double);
Begin
    AddLine(X1,Y1,X2,Y1); AddLine(X2,Y1,X2,Y2);
    AddLine(X2,Y2,X1,Y2); AddLine(X1,Y2,X1,Y1);
End;

Procedure AddCircle(X, Y, R : Double);
Var A : IPCB_Arc;
Begin
    A := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
    A.XCenter := MMsToCoord(X); A.YCenter := MMsToCoord(Y);
    A.Radius := MMsToCoord(R); A.LineWidth := MMsToCoord(0.20);
    A.StartAngle := 0; A.EndAngle := 360; A.Layer := eTopOverlay;
    RegisterPrimitive(A);
End;

Procedure PinOneMark(X, Y : Double);
Begin
    AddCircle(X,Y,0.30);
End;

Procedure MakeChip2(AName : String; PadX, PadY, CenterX, BodyX, BodyY : Double);
Begin
    StartComponent(AName);
    AddSmdPad('1',-CenterX,0,PadX,PadY,eRectangular);
    AddSmdPad('2', CenterX,0,PadX,PadY,eRectangular);
    AddOutline(-BodyX/2,-BodyY/2,BodyX/2,BodyY/2);
    PinOneMark(-BodyX/2-0.35,BodyY/2+0.35);
    FinishComponent;
End;

Procedure MakeSO(AName : String; PinCount : Integer; Pitch, RowX, PadX, PadY, BodyX, BodyY : Double);
Var I, Half : Integer; Y0 : Double;
Begin
    StartComponent(AName); Half := PinCount Div 2; Y0 := Pitch * (Half-1) / 2;
    For I := 0 To Half-1 Do
    Begin
        AddSmdPad(IntToStr(I+1),-RowX,Y0-I*Pitch,PadX,PadY,eRectangular);
        AddSmdPad(IntToStr(PinCount-I),RowX,Y0-I*Pitch,PadX,PadY,eRectangular);
    End;
    AddOutline(-BodyX/2,-BodyY/2,BodyX/2,BodyY/2);
    PinOneMark(-BodyX/2-0.40,BodyY/2-0.35);
    FinishComponent;
End;

Procedure MakeTSOT6;
Begin
    StartComponent('TSOT-23-6_P0.95');
    { Top view: pin 1 at upper left; numbering runs counter-clockwise. }
    { JLCEDA/EasyEDA official library C780769. }
    AddSmdPad('1',-1.20, 0.95,1.10,0.55,eRectangular);
    AddSmdPad('2',-1.20, 0.00,1.10,0.55,eRectangular);
    AddSmdPad('3',-1.20,-0.95,1.10,0.55,eRectangular);
    AddSmdPad('4', 1.20,-0.95,1.10,0.55,eRectangular);
    AddSmdPad('5', 1.20, 0.00,1.10,0.55,eRectangular);
    AddSmdPad('6', 1.20, 0.95,1.10,0.55,eRectangular);
    AddOutline(-0.80,-1.45,0.80,1.45); PinOneMark(-1.00,1.20); FinishComponent;
End;

Procedure MakeSOT23;
Begin
    StartComponent('SOT-23-3');
    AddSmdPad('1',-0.95,-1.00,1.00,0.65,eRectangular);
    AddSmdPad('2', 0.95,-1.00,1.00,0.65,eRectangular);
    AddSmdPad('3', 0.00, 1.00,1.00,0.65,eRectangular);
    AddOutline(-1.50,-0.80,1.50,0.80); PinOneMark(-1.25,-0.55); FinishComponent;
End;

Procedure MakeSOT223;
Begin
    StartComponent('SOT-223-4');
    { JLCEDA/EasyEDA official library C154901, normalized orientation. }
    AddSmdPad('1',-2.30,-2.84,0.98,2.47,eRectangular);
    AddSmdPad('2', 0.00,-2.84,0.98,2.47,eRectangular);
    AddSmdPad('3', 2.30,-2.84,0.98,2.47,eRectangular);
    AddSmdPad('4', 0.00, 2.84,3.60,2.47,eRectangular);
    AddOutline(-3.33,-1.77,3.33,1.77); PinOneMark(-2.75,-1.45); FinishComponent;
End;

Procedure MakeTSSOP20;
Var I : Integer; Y0 : Double;
Begin
    { Top view: pins 1..10 run down the left; pins 11..20 run up the right. }
    { JLCEDA/EasyEDA official library C529330. }
    StartComponent('TSSOP-20_P0.65'); Y0 := 2.925;
    For I := 0 To 9 Do
    Begin
        AddSmdPad(IntToStr(I+1),-2.87,Y0-I*0.65,1.74,0.36,eRounded);
        AddSmdPad(IntToStr(20-I),2.87,Y0-I*0.65,1.74,0.36,eRounded);
    End;
    AddOutline(-1.77,-3.33,1.77,3.33); PinOneMark(-2.05,2.95); FinishComponent;
End;

Procedure MakeSO16;
Var I : Integer; Y0 : Double;
Begin
    { Top view: pins 1..8 run down the left; pins 9..16 run up the right. }
    { JLCEDA/EasyEDA official library C547001. }
    StartComponent('SOIC-16_P1.27'); Y0 := 4.445;
    For I := 0 To 7 Do
    Begin
        AddSmdPad(IntToStr(I+1),-2.77,Y0-I*1.27,2.04,0.57,eRounded);
        AddSmdPad(IntToStr(16-I),2.77,Y0-I*1.27,2.04,0.57,eRounded);
    End;
    AddOutline(-1.52,-5.03,1.52,5.03); PinOneMark(-1.85,4.45); FinishComponent;
End;

Procedure MakeHeader4;
Var I : Integer;
Begin
    StartComponent('HDR_1x4_P2.54');
    For I := 0 To 3 Do AddThPad(IntToStr(I+1),0,3.81-I*2.54,1.70,1.00,eRounded);
    AddOutline(-1.35,-5.15,1.35,5.15); PinOneMark(-0.95,4.60); FinishComponent;
End;

Procedure MakeTerminal2;
Begin
    StartComponent('TB_2P_P5.08');
    AddThPad('1',-2.54,0,2.40,1.20,eRounded); AddThPad('2',2.54,0,2.40,1.20,eRounded);
    AddOutline(-5.10,-4.00,5.10,4.00); AddLine(-5.10,-2.75,5.10,-2.75);
    PinOneMark(-4.45,3.35); FinishComponent;
End;

Procedure MakePPTC;
Begin
    StartComponent('PPTC_RADIAL_P5.10_D8.0');
    { JLCEDA/EasyEDA official library C21025; top view, 5.0 x 2.0 mm stagger. }
    AddThPad('1',-2.50, 1.00,1.60,0.80,eRounded); AddThPad('2',2.50,-1.00,1.60,0.80,eRounded);
    AddOutline(-3.90,-1.50,3.90,1.50); PinOneMark(-3.45,1.05); FinishComponent;
End;

Procedure MakeRadialCap;
Begin
    StartComponent('CP_RADIAL_D8.0_P3.50');
    AddThPad('1',-1.75,0,2.00,0.90,eRounded); AddThPad('2',1.75,0,2.00,0.90,eRounded);
    AddCircle(0,0,4.00); AddLine(-3.00,2.20,-3.00,3.10); AddLine(-3.45,2.65,-2.55,2.65);
    FinishComponent;
End;

Procedure MakeInductor;
Begin
    StartComponent('IND_SMD_6.0x6.0');
    AddSmdPad('1',-3.00,0,2.40,5.40,eRectangular); AddSmdPad('2',3.00,0,2.40,5.40,eRectangular);
    AddOutline(-3.10,-3.10,3.10,3.10); PinOneMark(-2.65,2.65); FinishComponent;
End;

Procedure MakeSMA;
Begin
    { JLCEDA/EasyEDA official library C2481. }
    StartComponent('D_SMA');
    AddSmdPad('1',-2.20,0,2.00,2.00,eRectangular);
    AddSmdPad('2', 2.20,0,2.00,2.00,eRectangular);
    AddOutline(-2.60,-1.43,2.60,1.43); AddLine(-0.88,-1.20,-0.88,1.20);
    PinOneMark(-2.45,1.20); FinishComponent;
End;

Procedure SaveFootprintAudit;
Var It : IPCB_LibraryIterator; Fp : IPCB_LibComponent; Lines : TStringList; Count : Integer;
Begin
    Lines := TStringList.Create; Count := 0;
    It := CurrentLib.LibraryIterator_Create;
    It.SetState_FilterAll;
    Try
        Fp := It.FirstPCBObject;
        While Fp <> Nil Do
        Begin
            Inc(Count); Lines.Add(Fp.Name);
            Fp := It.NextPCBObject;
        End;
    Finally
        CurrentLib.LibraryIterator_Destroy(It);
    End;
    Lines.Sort;
    Lines.Insert(0,'Count=' + IntToStr(Count));
    Lines.Insert(1,'Source=JLCEDA/EasyEDA Official Library for C780769,C529330,C547001,C154901,C20917,C21025,C2481; generic mechanical footprints are project-defined.');
    Lines.SaveToFile('F:\workSapce_PCB\aquarium\schematic_v1_0\footprint-runtime-audit.txt');
    Lines.Free;
    ShowMessage('Aquarium footprints generated and audited: ' + IntToStr(Count));
End;

Procedure MakeTact;
Begin
    StartComponent('SW_TACT_6x6_4P');
    AddThPad('1',-3.25, 2.25,1.80,1.00,eRounded); AddThPad('1',-3.25,-2.25,1.80,1.00,eRounded);
    AddThPad('2', 3.25, 2.25,1.80,1.00,eRounded); AddThPad('2', 3.25,-2.25,1.80,1.00,eRounded);
    AddOutline(-3.10,-3.10,3.10,3.10); AddCircle(0,0,1.75); PinOneMark(-2.65,2.65); FinishComponent;
End;

Procedure GenerateAquariumFootprints;
Begin
    If PCBServer = Nil Then Exit;
    CurrentLib := PCBServer.GetPCBLibraryByPath(
        'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_Footprints_V1_1.PcbLib');
    If CurrentLib = Nil Then Begin
        ShowMessage('Aquarium_ATO_Footprints_V1_1.PcbLib is not open.');
        Exit;
    End;
    FirstComp := True;
    PCBServer.PreProcess;

    MakeTerminal2;
    MakePPTC;
    MakeSOT223;
    MakeChip2('R_0603_1608Metric',0.90,0.95,0.80,1.60,0.80);
    MakeChip2('C_0603_1608Metric',0.90,0.95,0.80,1.60,0.80);
    MakeChip2('C_0805_2012Metric',1.10,1.30,1.00,2.00,1.25);
    MakeChip2('C_1210_3225Metric',1.30,2.60,1.65,3.20,2.50);
    MakeChip2('LED_0603_1608Metric',0.90,0.95,0.80,1.60,0.80);
    MakeChip2('SOD-123',1.20,1.30,1.65,2.70,1.60);
    MakeSMA;
    MakeTSOT6;
    MakeSOT23;
    MakeTSSOP20;
    MakeSO16;
    MakeHeader4;
    MakeRadialCap;
    MakeInductor;
    MakeTact;

    PCBServer.PostProcess;
    CurrentLib.Board.ViewManager_FullUpdate;
    SaveFootprintAudit;
End;

End.
