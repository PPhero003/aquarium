{ Rebuilds Aquarium ATO PCB from an EMPTY new Altium PCB document only. }
{ Uses the footprints extracted from the user's EasyEDA board, but does not }
{ inherit any imported PCB rules.  This integrated script also adds a }
{ hand-defined two-layer copper plan after all pin/net checks pass. }

{ Aquarium ATO - AD19 fixed-path two-layer copper plan.  NO AUTOROUTER.
  Engineering topology and trunk channels are explicitly listed at MR_LoadPlan.
  Runs only after ALL footprints have real pads assigned to the expected nets.
  Unvalidated: DRC + manufacturer footprint pin mapping and load measurements required. }

Const MR_MAXLINK = 200;
      MR_MAXESC = 256;
Type TMRLink = Record
    N, RA, PA, RB, PB : String;
    W, LaneY : Double;
    Bottom : Boolean;
End;
Var MR_Board : IPCB_Board;
    MR_Links : Array[1..MR_MAXLINK] Of TMRLink;
    MR_LinksCount, MR_Traces, MR_Vias, MR_Polys, MR_Errors : Integer;
    MR_EscPads : Array[1..MR_MAXESC] Of IPCB_Pad;
    MR_EscVias : Array[1..MR_MAXESC] Of IPCB_Via;
    MR_EscCount : Integer;
    MR_Success : Boolean;
    MR_Log : TStringList;
    Board : IPCB_Board;
    LoadFailures : Integer;
    AssignFailures : Integer;
    TargetPath : String;
    PcbLibPath : String;
    SchLibPath : String;
    AuditPath : String;
    TracePath : String;
    AssignErrors : TStringList;
    SaveSucceeded : Boolean;
    SL_Board : IPCB_Board;
    SL_Placed, SL_Mechanical, SL_FunctionTexts : Integer;
    SL_Log : TStringList;


Function MR_FindComp(ARef : String) : IPCB_Component;
Var I : IPCB_BoardIterator; C : IPCB_Component;
Begin
    Result := Nil;
    I := MR_Board.BoardIterator_Create;
    I.AddFilter_ObjectSet(MkSet(eComponentObject));
    I.AddFilter_LayerSet(AllLayers); I.AddFilter_Method(eProcessAll);
    C := I.FirstPCBObject;
    While C <> Nil Do Begin
       If C.SourceDesignator = ARef Then Begin Result := C; Break; End;
       C := I.NextPCBObject;
    End;
    MR_Board.BoardIterator_Destroy(I);
End;

Function MR_FindPad(ARef, Pin : String) : IPCB_Pad;
Var C : IPCB_Component; I : IPCB_GroupIterator; P : IPCB_Pad;
Begin
    Result := Nil;
    C := MR_FindComp(ARef); If C = Nil Then Exit;
    I := C.GroupIterator_Create; I.AddFilter_ObjectSet(MkSet(ePadObject));
    P := I.FirstPCBObject;
    While P <> Nil Do Begin
        If P.Name = Pin Then Begin Result := P; Break; End;
        P := I.NextPCBObject;
    End;
    C.GroupIterator_Destroy(I);
End;

Function MR_GetNet(AName : String) : IPCB_Net;
Var I : IPCB_BoardIterator; N : IPCB_Net;
Begin
    Result := Nil;
    I := MR_Board.BoardIterator_Create;
    I.AddFilter_ObjectSet(MkSet(eNetObject));
    I.AddFilter_LayerSet(AllLayers); I.AddFilter_Method(eProcessAll);
    N := I.FirstPCBObject;
    While N <> Nil Do Begin
        If N.Name = AName Then Begin Result := N; Break; End;
        N := I.NextPCBObject;
    End;
    MR_Board.BoardIterator_Destroy(I);
End;

Function MR_Validate(ARef, Pin, Net : String) : Boolean;
Var P : IPCB_Pad;
Begin
    P := MR_FindPad(ARef,Pin);
    Result := False;
    If P = Nil Then Begin
        MR_Log.Add('ERROR|Missing component pad|'+ARef+'.'+Pin); Exit;
    End;
    If P.Net = Nil Then Begin
        MR_Log.Add('ERROR|Pad has no net|'+ARef+'.'+Pin); Exit;
    End;
    If P.Net.Name <> Net Then Begin
        MR_Log.Add('ERROR|Wrong net|'+ARef+'.'+Pin+'|Expected='+Net+'|Found='+P.Net.Name); Exit;
    End;
    Result := True;
End;

Procedure MR_Plan(AN,RA,PA,RB,PB : String; W : Double; ABottom : Boolean; AY : Double);
Begin
    If MR_LinksCount >= MR_MAXLINK Then Begin Inc(MR_Errors); Exit; End;
    Inc(MR_LinksCount);
    MR_Links[MR_LinksCount].N := AN;
    MR_Links[MR_LinksCount].RA := RA;
    MR_Links[MR_LinksCount].PA := PA;
    MR_Links[MR_LinksCount].RB := RB;
    MR_Links[MR_LinksCount].PB := PB;
    MR_Links[MR_LinksCount].W := W;
    MR_Links[MR_LinksCount].Bottom := ABottom;
    MR_Links[MR_LinksCount].LaneY := AY;
End;

Procedure MR_LoadPlan;
Begin
    MR_LinksCount := 0;
    { Top layer: power feed, pump current loop, compact buck BST/SW. }
    { Bottom layer: manually chosen corridor lanes for longer control/data nets. }
    MR_Plan('+12V_IN','J1','1','F1','1',1.40,False,0.00);
    MR_Plan('VIN_FUSED','F1','2','Q1','2',1.40,False,0.00);
    MR_Plan('VIN_FUSED','Q1','2','Q1','4',1.40,False,0.00);
    MR_Plan('Q1_GATE','Q1','1','R1','1',0.23,False,0.00);
    MR_Plan('Q1_GATE','R1','1','D1','2',0.23,False,0.00);
    MR_Plan('VIN_P','Q1','3','D1','1',0.50,False,0.00);
    MR_Plan('VIN_P','D1','1','C1','1',1.40,False,0.00);
    MR_Plan('VIN_P','C1','1','C2','1',1.40,False,0.00);
    MR_Plan('VIN_P','C2','1','C3','1',1.40,False,0.00);
    MR_Plan('VIN_P','C3','1','U1','2',0.23,False,0.00);
    MR_Plan('VIN_P','U1','2','U1','3',0.23,False,0.00);
    MR_Plan('BST','U1','6','C4','1',0.23,False,0.00);
    MR_Plan('SW','U1','5','C4','2',0.30,False,0.00);
    MR_Plan('SW','C4','2','L1','1',0.60,False,0.00);
    MR_Plan('PUMP_NEG','J2','2','D2','2',1.40,False,0.00);
    MR_Plan('PUMP_NEG','D2','2','Q2','3',1.40,False,0.00);
    MR_Plan('PUMP_GATE','Q2','1','R5','1',0.40,False,0.00);
    MR_Plan('PUMP_GATE','R5','1','R4','2',0.40,False,0.00);
    MR_Plan('PUMP_CMD','U3','11','R4','1',0.23,True,40.80);
    MR_Plan('WIFI_RX','U3','1','R18','2',0.23,True,35.50);
    MR_Plan('WIFI_RX','R18','2','R3','1',0.23,False,0.00);
    MR_Plan('MUX_S0','U3','2','U2','10',0.23,True,29.00);
    MR_Plan('MUX_S0','U2','10','R12','1',0.23,False,0.00);
    MR_Plan('MUX_S1','U3','3','U2','9',0.23,True,27.80);
    MR_Plan('MUX_S1','U2','9','R13','1',0.23,False,0.00);
    MR_Plan('NRST','U3','6','C15','1',0.23,False,0.00);
    MR_Plan('NRST','C15','1','R8','2',0.23,False,0.00);
    MR_Plan('NRST','R8','2','SW3','1',0.23,False,0.00);
    MR_Plan('MUX_E','U3','7','U2','6',0.23,True,26.60);
    MR_Plan('MUX_E','U2','6','R11','2',0.23,False,0.00);
    MR_Plan('SENS_TX','U3','9','U2','13',0.23,True,32.00);
    MR_Plan('SENS_RX','U3','10','U2','3',0.23,True,30.60);
    MR_Plan('SENS_RX','U2','3','R14','2',0.23,False,0.00);
    MR_Plan('WIFI_TX','U3','20','R2','1',0.23,True,36.80);
    MR_Plan('SWCLK','U3','19','J5','4',0.23,True,40.00);
    MR_Plan('SWDIO','U3','18','J5','2',0.23,True,41.50);
    MR_Plan('KEY_AUTO','U3','16','C13','1',0.23,True,21.80);
    MR_Plan('KEY_AUTO','C13','1','R6','2',0.23,False,0.00);
    MR_Plan('KEY_AUTO','R6','2','SW1','1',0.23,False,0.00);
    MR_Plan('LED_FAULT','U3','14','R10','1',0.23,True,25.40);
    MR_Plan('LED_STATUS','U3','13','R9','1',0.23,True,24.50);
    MR_Plan('KEY_MANUAL','U3','12','C14','1',0.23,True,23.40);
    MR_Plan('KEY_MANUAL','C14','1','R7','2',0.23,False,0.00);
    MR_Plan('KEY_MANUAL','R7','2','SW2','1',0.23,False,0.00);
    MR_Plan('WIFI_MODULE_RX','R2','2','R25','2',0.23,False,0.00);
    MR_Plan('WIFI_MODULE_RX','R25','2','J7','3',0.23,True,39.00);
    MR_Plan('WIFI_MODULE_TX','R3','2','J7','4',0.23,True,37.80);
    MR_Plan('D3_A','R9','2','D3','2',0.23,False,0.00);
    MR_Plan('D4_A','R10','2','D4','2',0.23,False,0.00);
    MR_Plan('MAIN_TX_MUX','U2','1','R20','1',0.23,True,19.00);
    MR_Plan('RES_TX_MUX','U2','2','R24','1',0.23,True,15.40);
    MR_Plan('AUX_TX_MUX','U2','5','R22','1',0.23,True,17.80);
    MR_Plan('RES_RX_MUX','U2','15','R23','1',0.23,True,14.20);
    MR_Plan('AUX_RX_MUX','U2','14','R21','1',0.23,True,16.60);
    MR_Plan('MAIN_RX_MUX','U2','12','R19','1',0.23,True,20.50);
    MR_Plan('MAIN_RX','J3','3','R15','2',0.23,False,0.00);
    MR_Plan('MAIN_RX','R15','2','R19','2',0.23,False,0.00);
    MR_Plan('MAIN_TX','J3','4','R20','2',0.23,False,0.00);
    MR_Plan('AUX_RX','J4','3','R16','2',0.23,False,0.00);
    MR_Plan('AUX_RX','R16','2','R21','2',0.23,False,0.00);
    MR_Plan('AUX_TX','J4','4','R22','2',0.23,False,0.00);
    MR_Plan('RES_RX','J6','3','R17','2',0.23,False,0.00);
    MR_Plan('RES_RX','R17','2','R23','2',0.23,False,0.00);
    MR_Plan('RES_TX','J6','4','R24','2',0.23,False,0.00);
    MR_Plan('VIN_P','Q1','3','J2','1',1.40,False,58.00);
    MR_Plan('VIN_P','Q1','3','D2','1',1.40,False,57.30);
    MR_Plan('VIN_P','Q1','3','C1','1',0.65,False,0.00);
    MR_Plan('+3V3','L1','2','U1','1',0.23,False,0.00);
    MR_Plan('+3V3','L1','2','C5','1',0.60,False,0.00);
    MR_Plan('+3V3','C5','1','C6','1',0.60,False,0.00);
    MR_Plan('+3V3','C5','1','J5','1',0.60,False,46.50);
End;

Procedure MR_T(X1,Y1,X2,Y2 : TCoord; W : Double; L : TLayer; N : IPCB_Net);
Var T : IPCB_Track;
Begin
    If (X1=X2) And (Y1=Y2) Then Exit;
    T := PCBServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
    T.X1:=X1;T.Y1:=Y1;T.X2:=X2;T.Y2:=Y2;
    T.Width:=MMsToCoord(W);T.Layer:=L;T.Net:=N;
    MR_Board.AddPCBObject(T); Inc(MR_Traces);
End;

{ Straight/45 degree only, no freehand autorouter algorithm. }
Procedure MR_45(X1,Y1,X2,Y2 : TCoord; W : Double; L : TLayer; N : IPCB_Net);
Var DX,DY,Step : TCoord; XMid,YMid : TCoord;
Begin
    DX:=X2-X1;DY:=Y2-Y1;
    If (DX=0) Or (DY=0) Then Begin MR_T(X1,Y1,X2,Y2,W,L,N); Exit; End;
    Step:=Abs(DX); If Abs(DY)<Step Then Step:=Abs(DY);
    XMid:=X1;YMid:=Y1;
    If DX>0 Then XMid:=X1+Step Else XMid:=X1-Step;
    If DY>0 Then YMid:=Y1+Step Else YMid:=Y1-Step;
    MR_T(X1,Y1,XMid,YMid,W,L,N);
    MR_T(XMid,YMid,X2,Y2,W,L,N);
End;

Function MR_FindOwner(P : IPCB_Pad) : IPCB_Component;
Var I : IPCB_BoardIterator; GI : IPCB_GroupIterator;
    C : IPCB_Component; TestPad : IPCB_Pad;
Begin
    Result:=Nil;
    I:=MR_Board.BoardIterator_Create;
    I.AddFilter_ObjectSet(MkSet(eComponentObject));
    I.AddFilter_LayerSet(AllLayers); I.AddFilter_Method(eProcessAll);
    C:=I.FirstPCBObject;
    While C<>Nil Do Begin
        GI:=C.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject));
        TestPad:=GI.FirstPCBObject;
        While TestPad<>Nil Do Begin
            If TestPad=P Then Result:=C;
            TestPad:=GI.NextPCBObject;
        End;
        C.GroupIterator_Destroy(GI);
        If Result<>Nil Then Break;
        C:=I.NextPCBObject;
    End;
    MR_Board.BoardIterator_Destroy(I);
End;

Function MR_ViaFor(P : IPCB_Pad; N : IPCB_Net) : IPCB_Via;
Var I : Integer; C : IPCB_Component; DX,DY,VX,VY,Shift : TCoord; V : IPCB_Via;
Begin
    Result := Nil;
    If P.Layer = eMultiLayer Then Exit; { plated through-hole reaches bottom }
    For I:=1 To MR_EscCount Do If MR_EscPads[I]=P Then Begin
        Result:=MR_EscVias[I]; Exit;
    End;
    If MR_EscCount>=MR_MAXESC Then Begin Inc(MR_Errors); Exit; End;
    { Escape direction follows actual placed pad offset from part centroid. }
    C:=MR_FindOwner(P);
    If C=Nil Then Begin Inc(MR_Errors);Exit;End;
    DX:=P.X-C.X; DY:=P.Y-C.Y;
    Shift:=MMsToCoord(1.25);
    If ((MR_EscCount Mod 2)=0) Then Shift:=MMsToCoord(2.00);
    VX:=P.X;VY:=P.Y;
    If Abs(DX)>=Abs(DY) Then Begin
        If DX<0 Then VX:=P.X-Shift Else VX:=P.X+Shift;
    End Else Begin
        If DY<0 Then VY:=P.Y-Shift Else VY:=P.Y+Shift;
    End;
    { All vias stay safely inside nominal 100 x 60 board perimeter. }
    If VX<MMsToCoord(2) Then VX:=P.X+Shift;
    If VX>MMsToCoord(98) Then VX:=P.X-Shift;
    If VY<MMsToCoord(2) Then VY:=P.Y+Shift;
    If VY>MMsToCoord(58) Then VY:=P.Y-Shift;
    V:=PCBServer.PCBObjectFactory(eViaObject,eNoDimension,eCreate_Default);
    V.X:=VX;V.Y:=VY;V.Size:=MMsToCoord(0.70);
    V.HoleSize:=MMsToCoord(0.30);
    V.LowLayer:=eTopLayer;V.HighLayer:=eBottomLayer;V.Net:=N;
    MR_Board.AddPCBObject(V); Inc(MR_Vias);
    { Thin top escape appropriate for 0.65mm pitch MCU and mux pads. }
    MR_45(P.X,P.Y,VX,VY,0.20,eTopLayer,N);
    Inc(MR_EscCount); MR_EscPads[MR_EscCount]:=P;MR_EscVias[MR_EscCount]:=V;
    Result:=V;
End;

Procedure MR_GndEscape(AR,AP : String);
Var P : IPCB_Pad; N : IPCB_Net;
Begin
    P:=MR_FindPad(AR,AP); N:=MR_GetNet('GND');
    If (P=Nil) Or (N=Nil) Then Begin Inc(MR_Errors); Exit; End;
    If P.Net<>N Then Begin Inc(MR_Errors); Exit; End;
    If P.Layer<>eMultiLayer Then MR_ViaFor(P,N);
End;

Procedure MR_ApplyLink(I : Integer);
Var A,B : IPCB_Pad; N : IPCB_Net; V1,V2 : IPCB_Via;
    X1,Y1,X2,Y2,LY : TCoord; W : Double;
Begin
    A:=MR_FindPad(MR_Links[I].RA,MR_Links[I].PA);
    B:=MR_FindPad(MR_Links[I].RB,MR_Links[I].PB);
    N:=MR_GetNet(MR_Links[I].N);
    If (A=Nil) Or (B=Nil) Or (N=Nil) Then Begin Inc(MR_Errors);Exit;End;
    W:=MR_Links[I].W;
    If MR_Links[I].Bottom Then Begin
        V1:=MR_ViaFor(A,N); V2:=MR_ViaFor(B,N);
        X1:=A.X;Y1:=A.Y;X2:=B.X;Y2:=B.Y;
        If V1<>Nil Then Begin X1:=V1.X; Y1:=V1.Y; End;
        If V2<>Nil Then Begin X2:=V2.X; Y2:=V2.Y; End;
        LY:=MMsToCoord(MR_Links[I].LaneY);
        { Manually set channel Y; path uses two terminal jogs and horizontal trunk. }
        MR_45(X1,Y1,X1,LY,W,eBottomLayer,N);
        MR_T(X1,LY,X2,LY,W,eBottomLayer,N);
        MR_45(X2,LY,X2,Y2,W,eBottomLayer,N);
    End Else If MR_Links[I].LaneY > 0 Then Begin
        LY:=MMsToCoord(MR_Links[I].LaneY);
        MR_45(A.X,A.Y,A.X,LY,W,eTopLayer,N);
        MR_T(A.X,LY,B.X,LY,W,eTopLayer,N);
        MR_45(B.X,LY,B.X,B.Y,W,eTopLayer,N);
    End Else Begin
        MR_45(A.X,A.Y,B.X,B.Y,W,eTopLayer,N);
    End;
End;

Procedure MR_RectPoly(NetName : String; L:TLayer;
                      LeftMM,BottomMM,RightMM,TopMM : Double);
Var P : IPCB_Polygon; S : TPolySegment;
Begin
    P:=PCBServer.PCBObjectFactory(ePolyObject,eNoDimension,eCreate_Default);
    P.Layer:=L;P.Net:=MR_GetNet(NetName);
    P.PolyHatchStyle:=ePolySolid;
    P.RemoveDead:=True; P.RemoveIslandsByArea:=True;
    P.SetState_PointCount(4);
    S:=TPolySegment; S.Kind:=ePolySegmentLine;
    S.vx:=MMsToCoord(LeftMM);S.vy:=MMsToCoord(BottomMM);P.SetState_Segments(0,S);
    S.vx:=MMsToCoord(RightMM);S.vy:=MMsToCoord(BottomMM);P.SetState_Segments(1,S);
    S.vx:=MMsToCoord(RightMM);S.vy:=MMsToCoord(TopMM);P.SetState_Segments(2,S);
    S.vx:=MMsToCoord(LeftMM);S.vy:=MMsToCoord(TopMM);P.SetState_Segments(3,S);
    MR_Board.AddPCBObject(P); Inc(MR_Polys);
End;

Procedure MR_WriteReport(AStatus : String);
Var Path : String;
Begin
    MR_Log.Add('Status='+AStatus);
    MR_Log.Add('PlanLinks='+IntToStr(MR_LinksCount));
    MR_Log.Add('CreatedTracks='+IntToStr(MR_Traces));
    MR_Log.Add('CreatedVias='+IntToStr(MR_Vias));
    MR_Log.Add('CreatedPolygonOutlines='+IntToStr(MR_Polys));
    MR_Log.Add('Errors='+IntToStr(MR_Errors));
    MR_Log.Add('NOTICE=Not manufactured/DRC certified; polygon repour and full DRC REQUIRED');
    Path:=ExtractFilePath(MR_Board.FileName);
    If Path<>'' Then MR_Log.SaveToFile(Path+'ATO_AD19_ManualRoute_Report.txt');
End;

Function MR_ExistingCopper : Integer;
Var I : IPCB_BoardIterator; O : IPCB_Primitive;
Begin
    Result:=0;
    I:=MR_Board.BoardIterator_Create;
    I.AddFilter_ObjectSet(MkSet(eTrackObject,eViaObject,ePolyObject));
    I.AddFilter_LayerSet(AllLayers);I.AddFilter_Method(eProcessAll);
    O:=I.FirstPCBObject;
    While O<>Nil Do Begin
        If (O.ObjectId<>eTrackObject) Or
           (O.Layer=eTopLayer) Or (O.Layer=eBottomLayer) Then Inc(Result);
        O:=I.NextPCBObject;
    End;
    MR_Board.BoardIterator_Destroy(I);
End;

Function MR_CheckAllPads : Boolean;
Var I : Integer; OK : Boolean;
Begin
    OK:=True;
    For I:=1 To MR_LinksCount Do Begin
        If Not MR_Validate(MR_Links[I].RA,MR_Links[I].PA,MR_Links[I].N) Then OK:=False;
        If Not MR_Validate(MR_Links[I].RB,MR_Links[I].PB,MR_Links[I].N) Then OK:=False;
    End;
    { All supply and ground component pads are checked before creating copper. }
    If Not MR_Validate('C1','2','GND') Then OK:=False;
    If Not MR_Validate('C10','2','GND') Then OK:=False;
    If Not MR_Validate('C11','2','GND') Then OK:=False;
    If Not MR_Validate('C12','2','GND') Then OK:=False;
    If Not MR_Validate('C13','2','GND') Then OK:=False;
    If Not MR_Validate('C14','2','GND') Then OK:=False;
    If Not MR_Validate('C15','2','GND') Then OK:=False;
    If Not MR_Validate('C16','2','GND') Then OK:=False;
    If Not MR_Validate('C17','2','GND') Then OK:=False;
    If Not MR_Validate('C18','2','GND') Then OK:=False;
    If Not MR_Validate('C2','2','GND') Then OK:=False;
    If Not MR_Validate('C3','2','GND') Then OK:=False;
    If Not MR_Validate('C5','2','GND') Then OK:=False;
    If Not MR_Validate('C6','2','GND') Then OK:=False;
    If Not MR_Validate('C7','2','GND') Then OK:=False;
    If Not MR_Validate('C8','2','GND') Then OK:=False;
    If Not MR_Validate('C9','2','GND') Then OK:=False;
    If Not MR_Validate('D3','1','GND') Then OK:=False;
    If Not MR_Validate('D4','1','GND') Then OK:=False;
    If Not MR_Validate('J1','2','GND') Then OK:=False;
    If Not MR_Validate('J3','2','GND') Then OK:=False;
    If Not MR_Validate('J4','2','GND') Then OK:=False;
    If Not MR_Validate('J5','3','GND') Then OK:=False;
    If Not MR_Validate('J6','2','GND') Then OK:=False;
    If Not MR_Validate('J7','2','GND') Then OK:=False;
    If Not MR_Validate('Q2','2','GND') Then OK:=False;
    If Not MR_Validate('R1','2','GND') Then OK:=False;
    If Not MR_Validate('R12','2','GND') Then OK:=False;
    If Not MR_Validate('R13','2','GND') Then OK:=False;
    If Not MR_Validate('R5','2','GND') Then OK:=False;
    If Not MR_Validate('SW1','2','GND') Then OK:=False;
    If Not MR_Validate('SW2','2','GND') Then OK:=False;
    If Not MR_Validate('SW3','2','GND') Then OK:=False;
    If Not MR_Validate('U1','4','GND') Then OK:=False;
    If Not MR_Validate('U2','7','GND') Then OK:=False;
    If Not MR_Validate('U2','8','GND') Then OK:=False;
    If Not MR_Validate('U3','5','GND') Then OK:=False;
    If Not MR_Validate('C10','1','+3V3') Then OK:=False;
    If Not MR_Validate('C11','1','+3V3') Then OK:=False;
    If Not MR_Validate('C12','1','+3V3') Then OK:=False;
    If Not MR_Validate('C16','1','+3V3') Then OK:=False;
    If Not MR_Validate('C17','1','+3V3') Then OK:=False;
    If Not MR_Validate('C18','1','+3V3') Then OK:=False;
    If Not MR_Validate('C5','1','+3V3') Then OK:=False;
    If Not MR_Validate('C6','1','+3V3') Then OK:=False;
    If Not MR_Validate('C7','1','+3V3') Then OK:=False;
    If Not MR_Validate('C8','1','+3V3') Then OK:=False;
    If Not MR_Validate('C9','1','+3V3') Then OK:=False;
    If Not MR_Validate('J3','1','+3V3') Then OK:=False;
    If Not MR_Validate('J4','1','+3V3') Then OK:=False;
    If Not MR_Validate('J5','1','+3V3') Then OK:=False;
    If Not MR_Validate('J6','1','+3V3') Then OK:=False;
    If Not MR_Validate('J7','1','+3V3') Then OK:=False;
    If Not MR_Validate('L1','2','+3V3') Then OK:=False;
    If Not MR_Validate('R11','1','+3V3') Then OK:=False;
    If Not MR_Validate('R14','1','+3V3') Then OK:=False;
    If Not MR_Validate('R15','1','+3V3') Then OK:=False;
    If Not MR_Validate('R16','1','+3V3') Then OK:=False;
    If Not MR_Validate('R17','1','+3V3') Then OK:=False;
    If Not MR_Validate('R18','1','+3V3') Then OK:=False;
    If Not MR_Validate('R25','1','+3V3') Then OK:=False;
    If Not MR_Validate('R6','1','+3V3') Then OK:=False;
    If Not MR_Validate('R7','1','+3V3') Then OK:=False;
    If Not MR_Validate('R8','1','+3V3') Then OK:=False;
    If Not MR_Validate('U1','1','+3V3') Then OK:=False;
    If Not MR_Validate('U2','16','+3V3') Then OK:=False;
    If Not MR_Validate('U3','4','+3V3') Then OK:=False;
    If MR_GetNet('GND')=Nil Then Begin MR_Log.Add('ERROR|GND missing');OK:=False;End;
    If MR_GetNet('+3V3')=Nil Then Begin MR_Log.Add('ERROR|+3V3 missing');OK:=False;End;
    Result:=OK;
End;

Procedure MR_RunRouteAndPour;
Var I : Integer;
Begin
    MR_LinksCount:=0;MR_Traces:=0;MR_Vias:=0;MR_Polys:=0;MR_Errors:=0;
    MR_Success:=False;
    MR_EscCount:=0;
    MR_Log:=TStringList.Create;
    MR_Log.Add('AQUARIUM ATO AD19 - HAND DEFINED ROUTING + 2L COPPER');
    If MR_Board=Nil Then Begin MR_Log.Free; Exit;End;
    MR_LoadPlan;
    If MR_ExistingCopper>0 Then Begin
        MR_Log.Add('ABORT|existing copper routing or polygon detected; refusing duplicates');
        MR_WriteReport('ABORT_COPPER_EXISTS');MR_Log.Free; Exit;
    End;
    If Not MR_CheckAllPads Then Begin
        MR_WriteReport('ABORT_PIN_NET_PRECHECK');MR_Log.Free; Exit;
    End;
    If MR_Errors>0 Then Begin MR_WriteReport('ABORT_PLAN_LIMIT');MR_Log.Free; Exit; End;
    { The 3.3V copper pour stops south of buck switch/pump; bottom is GND. }
    { Add copper traces BEFORE polygon objects, then repour inside AD19. }
    For I:=1 To MR_LinksCount Do MR_ApplyLink(I);
    { Ground for SMD pads: short top escape plus through-via into bottom plane. }
    MR_GndEscape('C1','2');
    MR_GndEscape('C2','2');
    MR_GndEscape('C3','2');
    MR_GndEscape('C5','2');
    MR_GndEscape('C6','2');
    MR_GndEscape('C7','2');
    MR_GndEscape('C8','2');
    MR_GndEscape('C9','2');
    MR_GndEscape('C10','2');
    MR_GndEscape('C11','2');
    MR_GndEscape('C12','2');
    MR_GndEscape('C13','2');
    MR_GndEscape('C14','2');
    MR_GndEscape('C15','2');
    MR_GndEscape('C16','2');
    MR_GndEscape('C17','2');
    MR_GndEscape('C18','2');
    MR_GndEscape('D3','1');
    MR_GndEscape('D4','1');
    MR_GndEscape('J1','2');
    MR_GndEscape('J3','2');
    MR_GndEscape('J4','2');
    MR_GndEscape('J5','3');
    MR_GndEscape('J6','2');
    MR_GndEscape('J7','2');
    MR_GndEscape('Q2','2');
    MR_GndEscape('R1','2');
    MR_GndEscape('R5','2');
    MR_GndEscape('R12','2');
    MR_GndEscape('R13','2');
    MR_GndEscape('SW1','2');
    MR_GndEscape('SW2','2');
    MR_GndEscape('SW3','2');
    MR_GndEscape('U1','4');
    MR_GndEscape('U2','7');
    MR_GndEscape('U2','8');
    MR_GndEscape('U3','5');
    { 1.25 mm inset from the edge, mounting holes must be checked in DRC. }
    MR_RectPoly('GND',eBottomLayer,1.25,1.25,98.75,58.75);
    MR_RectPoly('+3V3',eTopLayer,1.50,1.50,98.50,47.20);
    MR_Success:=(MR_Errors=0);
    If MR_Success Then MR_WriteReport('PLACED_PENDING_REPOUR_DRC')
    Else MR_WriteReport('PARTIAL_ERRORS_DO_NOT_FABRICATE');
    MR_Log.Free;
End;

Procedure WriteStage(AText : String);
Begin
    { Intentionally empty: AD19 can lock repeatedly rewritten progress files. }
End;

Function FindNet(AName : String) : IPCB_Net;
Var It : IPCB_BoardIterator; N : IPCB_Net;
Begin
    Result := Nil;
    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eNetObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    N := It.FirstPCBObject;
    While N <> Nil Do
    Begin
        If N.Name = AName Then Begin Result := N; Break; End;
        N := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
End;

Function FindComponent(ARef : String) : IPCB_Component;
Var It : IPCB_BoardIterator; C : IPCB_Component;
Begin
    Result := Nil;
    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do
    Begin
        If C.SourceDesignator = ARef Then Begin Result := C; Break; End;
        C := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
End;

Procedure AddNet(AName : String);
Var N : IPCB_Net;
Begin
    N := PCBServer.PCBObjectFactory(eNetObject, eNoDimension, eCreate_Default);
    N.Name := AName;
    Board.AddPCBObject(N);
End;

Procedure AddPart(ARef, AValue, AFootprint, ALibRef, AUID, ASheet : String;
                  Xmm, Ymm, ARotation : Double);
Var C : IPCB_Component; Loaded : Boolean;
Begin
    WriteStage('PART_BEGIN=' + ARef);
    C := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    C.Board := Board;
    { AD19 resolves library primitives against the component reference point
      during LoadFromLibrary.  Set the complete placement first so pads,
      overlay and component origin are created as one coherent group. }
    C.X := MMsToCoord(Xmm);
    C.Y := MMsToCoord(Ymm);
    C.Rotation := ARotation;
    C.Pattern := AFootprint;
    C.SourceFootprintLibrary := PcbLibPath;
    C.SourceComponentLibrary := PcbLibPath;
    C.SourceLibReference := AFootprint;
    Loaded := C.LoadFromLibrary;
    If Not Loaded Then
    Begin
        Inc(LoadFailures);
        Exit;
    End;
    WriteStage('PART_LOADED=' + ARef);
    C.Layer := eTopLayer;
    C.Pattern := AFootprint;
    C.SourceDesignator := ARef;
    C.SourceUniqueId := AUID;
    C.SourceHierarchicalPath := ASheet + '\' + ARef;
    C.SourceFootprintLibrary := PcbLibPath;
    C.SourceComponentLibrary := SchLibPath;
    C.SourceLibReference := ALibRef;
    C.NameOn := True;
    C.Name.Text := ARef;
    C.Name.Layer := eTopOverlay;
    C.Name.Size := MMsToCoord(0.8);
    C.Name.Width := MMsToCoord(0.12);
    { Designator is positioned only AFTER all components are placed. }
    { Avoid fixed origin-based offsets that collide after rotations. }
    C.NameAutoPosition := eAutoPos_Manual;
    C.NameOn := False;
    C.CommentOn := False;
    C.Comment.Text := AValue;
    C.Rebuild;
    C.SetState_xSizeySize;
    Board.AddPCBObject(C);
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast,
        PCBM_BoardRegisteration, C.I_ObjectAddress);
    C.Rebuild;
    C.SetState_xSizeySize;
    WriteStage('PART_DONE=' + ARef);
End;

{ A new PCB can contain rule defaults, but must not already contain any
  placed components, free pads, silkscreen or other graphic primitives.
  Checking components alone misses orphan footprint graphics and can
  produce a second visible set of footprints. }
Function CountExistingDesignObjects : Integer;
Var It : IPCB_BoardIterator; Obj : IPCB_Primitive;
Begin
    Result := 0;
    It := Board.BoardIterator_Create;
    { AD19 retains one internal board-shape region in an otherwise empty
      PcbDoc.  It is not a placed design primitive and CreateBoardOutline
      replaces the actual board outline below. }
    It.AddFilter_ObjectSet(MkSet(eComponentObject, ePadObject, eTrackObject,
        eViaObject, eArcObject, eTextObject, eFillObject,
        ePolyObject, eComponentBodyObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    Obj := It.FirstPCBObject;
    While Obj <> Nil Do
    Begin
        Inc(Result);
        Obj := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
End;

Procedure AnalyzeAllNets;
Var It : IPCB_BoardIterator; N : IPCB_Net;
Begin
    It := Board.BoardIterator_Create;
    It.AddFilter_ObjectSet(MkSet(eNetObject));
    It.AddFilter_LayerSet(AllLayers);
    It.AddFilter_Method(eProcessAll);
    N := It.FirstPCBObject;
    While N <> Nil Do
    Begin
        N.Rebuild;
        N.ShowNetConnects;
        Board.CleanNet(N);
        Board.AnalyzeNet(N);
        N := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);
    Board.ConnectivelyValidateNets;
End;

Procedure AssignPad(ARef, APin, ANet : String);
Var C : IPCB_Component; N : IPCB_Net; It : IPCB_GroupIterator;
    P : IPCB_Pad; Hits : Integer;
Begin
    C := FindComponent(ARef); N := FindNet(ANet); Hits := 0;
    If C = Nil Then
    Begin
        Inc(AssignFailures); AssignErrors.Add('ASSIGN_FAIL|' + ARef + '|' + APin + '|' + ANet + '|component_missing'); Exit;
    End;
    If N = Nil Then
    Begin
        Inc(AssignFailures); AssignErrors.Add('ASSIGN_FAIL|' + ARef + '|' + APin + '|' + ANet + '|net_missing'); Exit;
    End;
    It := C.GroupIterator_Create;
    It.AddFilter_ObjectSet(MkSet(ePadObject));
    P := It.FirstPCBObject;
    While P <> Nil Do
    Begin
        If P.Name = APin Then
        Begin
            PCBServer.SendMessageToRobots(P.I_ObjectAddress, c_Broadcast,
                PCBM_BeginModify, c_NoEventData);
            P.Net := N;
            N.ConnectivelyInvalidate;
            PCBServer.SendMessageToRobots(P.I_ObjectAddress, c_Broadcast,
                PCBM_EndModify, c_NoEventData);
            Inc(Hits);
        End;
        P := It.NextPCBObject;
    End;
    C.GroupIterator_Destroy(It);
    If Hits = 0 Then
    Begin
        Inc(AssignFailures); AssignErrors.Add('ASSIGN_FAIL|' + ARef + '|' + APin + '|' + ANet + '|pad_missing');
    End;
End;

Procedure AddClass(AName, AMembers : String; IsNetClass : Boolean);
Var Cls : IPCB_ObjectClass; P, K : Integer; S : String;
Begin
    If IsNetClass Then
        Cls := PCBServer.PCBClassFactoryByClassMember(eClassMemberKind_Net)
    Else
        Cls := PCBServer.PCBClassFactoryByClassMember(eClassMemberKind_Component);
    Cls.SuperClass := False; Cls.Name := AName;
    S := AMembers;
    While S <> '' Do
    Begin
        P := Pos(',', S);
        If P = 0 Then Begin Cls.AddMemberByName(S); S := ''; End
        Else Begin Cls.AddMemberByName(Copy(S,1,P-1)); Delete(S,1,P); End;
    End;
    Board.AddPCBObject(Cls);
End;

Procedure AddRuleSet;
Var Clearance : IPCB_ClearanceConstraint;
    Width : IPCB_MaxMinWidthConstraint;
    RailWidth : IPCB_MaxMinWidthConstraint;
    HighCurrentWidth : IPCB_MaxMinWidthConstraint;
    SwitchWidth : IPCB_MaxMinWidthConstraint;
    ViaRule : IPCB_RoutingViaStyleRule;
    CompGap : IPCB_ComponentClearanceConstraint;
Begin
    Clearance := PCBServer.PCBRuleFactory(eRule_Clearance);
    Clearance.Name := 'Clearance_0_20mm';
    Clearance.Scope1Expression := 'All'; Clearance.Scope2Expression := 'All';
    Clearance.Gap := MMsToCoord(0.20); Board.AddPCBObject(Clearance);

    RailWidth := PCBServer.PCBRuleFactory(eRule_MaxMinWidth);
    RailWidth.Name := 'ATO_3V3_0_60mm';
    RailWidth.Scope1Expression := 'InNet(''+3V3'')';
    RailWidth.MinWidth[eTopLayer] := MMsToCoord(0.40);
    RailWidth.FavoredWidth[eTopLayer] := MMsToCoord(0.60);
    RailWidth.MaxWidth[eTopLayer] := MMsToCoord(1.00);
    RailWidth.MinWidth[eBottomLayer] := MMsToCoord(0.40);
    RailWidth.FavoredWidth[eBottomLayer] := MMsToCoord(0.60);
    RailWidth.MaxWidth[eBottomLayer] := MMsToCoord(1.00);
    Board.AddPCBObject(RailWidth);

    HighCurrentWidth := PCBServer.PCBRuleFactory(eRule_MaxMinWidth);
    HighCurrentWidth.Name := 'ATO_12V_PUMP_1_20mm';
    HighCurrentWidth.Scope1Expression := 'InNetClass(''PWR_HIGH'')';
    HighCurrentWidth.MinWidth[eTopLayer] := MMsToCoord(0.80);
    HighCurrentWidth.FavoredWidth[eTopLayer] := MMsToCoord(1.20);
    HighCurrentWidth.MaxWidth[eTopLayer] := MMsToCoord(2.00);
    HighCurrentWidth.MinWidth[eBottomLayer] := MMsToCoord(0.80);
    HighCurrentWidth.FavoredWidth[eBottomLayer] := MMsToCoord(1.20);
    HighCurrentWidth.MaxWidth[eBottomLayer] := MMsToCoord(2.00);
    Board.AddPCBObject(HighCurrentWidth);

    SwitchWidth := PCBServer.PCBRuleFactory(eRule_MaxMinWidth);
    SwitchWidth.Name := 'ATO_BUCK_SW_0_80mm';
    SwitchWidth.Scope1Expression := 'InNet(''SW'')';
    SwitchWidth.MinWidth[eTopLayer] := MMsToCoord(0.60);
    SwitchWidth.FavoredWidth[eTopLayer] := MMsToCoord(0.80);
    SwitchWidth.MaxWidth[eTopLayer] := MMsToCoord(1.50);
    SwitchWidth.MinWidth[eBottomLayer] := MMsToCoord(0.60);
    SwitchWidth.FavoredWidth[eBottomLayer] := MMsToCoord(0.80);
    SwitchWidth.MaxWidth[eBottomLayer] := MMsToCoord(1.50);
    Board.AddPCBObject(SwitchWidth);

    { Keep the generic width last: in AD19 the earlier, more-specific width }
    { constraints retain priority over the catch-all signal rule. }
    Width := PCBServer.PCBRuleFactory(eRule_MaxMinWidth);
    Width.Name := 'ATO_SIGNAL_0_25mm'; Width.Scope1Expression := 'All';
    Width.MinWidth[eTopLayer] := MMsToCoord(0.20);
    Width.FavoredWidth[eTopLayer] := MMsToCoord(0.25);
    Width.MaxWidth[eTopLayer] := MMsToCoord(0.40);
    Width.MinWidth[eBottomLayer] := MMsToCoord(0.20);
    Width.FavoredWidth[eBottomLayer] := MMsToCoord(0.25);
    Width.MaxWidth[eBottomLayer] := MMsToCoord(0.40);
    Board.AddPCBObject(Width);

    ViaRule := PCBServer.PCBRuleFactory(eRule_RoutingViaStyle);
    ViaRule.Name := 'Via_0_60_0_30'; ViaRule.Scope1Expression := 'All';
    ViaRule.MinWidth := MMsToCoord(0.50); ViaRule.PreferedWidth := MMsToCoord(0.60);
    ViaRule.MaxWidth := MMsToCoord(1.00); ViaRule.MinHoleWidth := MMsToCoord(0.25);
    ViaRule.PreferedHoleWidth := MMsToCoord(0.30); ViaRule.MaxHoleWidth := MMsToCoord(0.50);
    Board.AddPCBObject(ViaRule);

    CompGap := PCBServer.PCBRuleFactory(eRule_ComponentClearance);
    CompGap.Name := 'Component_Clearance_0_50mm';
    CompGap.Scope1Expression := 'All'; CompGap.Scope2Expression := 'All';
    CompGap.Gap := MMsToCoord(0.50); CompGap.VerticalGap := MMsToCoord(0.50);
    Board.AddPCBObject(CompGap);
End;

Procedure AddMountingHole(AName : String; Xmm, Ymm : Double);
Var P : IPCB_Pad;
Begin
    P := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    P.Name := AName;
    P.X := MMsToCoord(Xmm); P.Y := MMsToCoord(Ymm);
    P.Layer := eMultiLayer; P.Mode := ePadMode_Simple;
    P.HoleSize := MMsToCoord(3.20);
    P.TopShape := eRounded;
    P.TopXSize := MMsToCoord(3.20); P.TopYSize := MMsToCoord(3.20);
    P.Plated := False;
    Board.AddPCBObject(P);
End;

Procedure AddTrack(X1, Y1, X2, Y2, AWidth : Double; ALayer : TLayer; Selected : Boolean);
Var T : IPCB_Track;
Begin
    T := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    T.X1 := MMsToCoord(X1); T.Y1 := MMsToCoord(Y1);
    T.X2 := MMsToCoord(X2); T.Y2 := MMsToCoord(Y2);
    T.Width := MMsToCoord(AWidth); T.Layer := ALayer; T.Selected := Selected;
    Board.AddPCBObject(T);
End;

Procedure AddText(AText : String; Xmm, Ymm, ASize : Double);
Var T : IPCB_Text;
Begin
    T := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
    T.Text := AText; T.XLocation := MMsToCoord(Xmm); T.YLocation := MMsToCoord(Ymm);
    { Area legends are on Mechanical2, not fabrication silkscreen. }
    T.Layer := eMechanical2; T.Size := MMsToCoord(ASize); T.Width := MMsToCoord(0.15);
    Board.AddPCBObject(T);
End;

Procedure CreateBoardOutline;
Var O : IPCB_BoardOutline; S : TPolySegment;
Begin
    O := Board.BoardOutline;
    PCBServer.SendMessageToRobots(O.I_ObjectAddress, c_Broadcast, PCBM_BeginModify, c_NoEventData);
    O.SetState_PointCount(4);
    S := TPolySegment; S.Kind := ePolySegmentLine; S.vx := MMsToCoord(0); S.vy := MMsToCoord(0); O.SetState_Segments(0,S);
    S := TPolySegment; S.Kind := ePolySegmentLine; S.vx := MMsToCoord(100); S.vy := MMsToCoord(0); O.SetState_Segments(1,S);
    S := TPolySegment; S.Kind := ePolySegmentLine; S.vx := MMsToCoord(100); S.vy := MMsToCoord(60); O.SetState_Segments(2,S);
    S := TPolySegment; S.Kind := ePolySegmentLine; S.vx := MMsToCoord(0); S.vy := MMsToCoord(60); O.SetState_Segments(3,S);
    O.Invalidate; O.Rebuild; O.Validate;
    PCBServer.SendMessageToRobots(O.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
    Board.UpdateBoardOutline;

    AddTrack(0,0,100,0,0.20,eMechanical1,False);
    AddTrack(100,0,100,60,0.20,eMechanical1,False);
    AddTrack(100,60,0,60,0.20,eMechanical1,False);
    AddTrack(0,60,0,0,0.20,eMechanical1,False);
    AddMountingHole('MH1',4,56);
    AddMountingHole('MH2',96,56);
    AddMountingHole('MH3',4,4);
    AddMountingHole('MH4',96,4);
End;

Procedure WriteAudit;
Var Lines : TStringList; It : IPCB_BoardIterator; C : IPCB_Component;
    N : IPCB_Net; R : IPCB_Rule; GI : IPCB_GroupIterator; P : IPCB_Pad;
    CompCount, NetCount, RuleCount, PadCount, Unassigned : Integer;
Begin
    Lines := TStringList.Create; CompCount := 0; NetCount := 0; RuleCount := 0;
    PadCount := 0; Unassigned := 0;
    Lines.Add('PCB layout audit');
    Lines.Add('Board=100x60 mm');
    Lines.Add('LoadFailures=' + IntToStr(LoadFailures));
    Lines.Add('AssignFailures=' + IntToStr(AssignFailures));
    If SaveSucceeded Then Lines.Add('SaveSucceeded=1') Else Lines.Add('SaveSucceeded=0');

    It := Board.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eComponentObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    C := It.FirstPCBObject;
    While C <> Nil Do
    Begin
        Inc(CompCount);
        GI := C.GroupIterator_Create; GI.AddFilter_ObjectSet(MkSet(ePadObject));
        P := GI.FirstPCBObject;
        While P <> Nil Do Begin Inc(PadCount); If P.Net = Nil Then Inc(Unassigned); P := GI.NextPCBObject; End;
        C.GroupIterator_Destroy(GI);
        Lines.Add('COMP|' + C.SourceDesignator + '|' + C.Pattern + '|' +
            FloatToStr(CoordToMMs(C.X)) + '|' + FloatToStr(CoordToMMs(C.Y)) + '|' +
            FloatToStr(C.Rotation));
        C := It.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(It);

    It := Board.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eNetObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    N := It.FirstPCBObject; While N <> Nil Do Begin Inc(NetCount); N := It.NextPCBObject; End;
    Board.BoardIterator_Destroy(It);
    It := Board.BoardIterator_Create; It.AddFilter_ObjectSet(MkSet(eRuleObject));
    It.AddFilter_LayerSet(AllLayers); It.AddFilter_Method(eProcessAll);
    R := It.FirstPCBObject; While R <> Nil Do Begin Inc(RuleCount); R := It.NextPCBObject; End;
    Board.BoardIterator_Destroy(It);
    Lines.Insert(5,'Components=' + IntToStr(CompCount));
    Lines.Insert(6,'Nets=' + IntToStr(NetCount));
    Lines.Insert(7,'Rules=' + IntToStr(RuleCount));
    Lines.Insert(8,'Pads=' + IntToStr(PadCount));
    Lines.Insert(9,'UnassignedPads=' + IntToStr(Unassigned));
    Lines.AddStrings(AssignErrors);
    Lines.SaveToFile(AuditPath); Lines.Free;
End;

Procedure WriteFinalStatus;
Var Lines : TStringList;
Begin
    Lines := TStringList.Create;
    If (LoadFailures = 0) And (AssignFailures = 0) And
       (SL_Mechanical = 0) And MR_Success And SaveSucceeded Then
        Lines.Add('STAGE=GENERATED_LAYOUT_DRC_PENDING')
    Else
        Lines.Add('STAGE=ABORTED_NOT_SAVED');
    If MR_Success Then Lines.Add('ROUTE=POLYGONS_ADDED_CHECK_DRC')
    Else Lines.Add('ROUTE=FAILED_OR_INCOMPLETE');
    If SaveSucceeded Then Lines.Add('SAVE=PASS') Else Lines.Add('SAVE=FAIL');
    Lines.Add('LOAD_FAILURES=' + IntToStr(LoadFailures));
    Lines.Add('ASSIGN_FAILURES=' + IntToStr(AssignFailures));
    Lines.AddStrings(AssignErrors);
    Lines.SaveToFile(TracePath);
    Lines.Free;
End;

{ ----- AD19 silkscreen relocation core ----- }
{ Conservative rectangle-based clearance; no pad, track or component is moved. }

{ The former record-field locator was removed because AD19's external }
{ DelphiScript entry point does not expose those record fields reliably. }

Procedure SL_PlaceName(ARef : String; Xmm, Ymm : Double);
Var C : IPCB_Component; Dsg : IPCB_Text;
Begin
    C := FindComponent(ARef);
    If C = Nil Then
    Begin
        Inc(SL_Mechanical);
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
    SL_Placed := 0; SL_Mechanical := 0; SL_FunctionTexts := 7;
    SL_Log := TStringList.Create;
    SL_Log.Add('AD19 deterministic designator placement; no record-field access');
    SL_PlaceName('J1',8.21,52.50); SL_PlaceName('F1',23.04,57.45);
    SL_PlaceName('Q1',33.04,58.00); SL_PlaceName('R1',31.04,45.36);
    SL_PlaceName('D1',26.04,49.60); SL_PlaceName('C1',42.04,57.88);
    SL_PlaceName('C2',47.05,51.64); SL_PlaceName('C3',50.05,45.31);
    SL_PlaceName('U1',51.04,56.40); SL_PlaceName('C4',55.54,54.37);
    SL_PlaceName('L1',60.04,57.23); SL_PlaceName('C5',67.04,51.12);
    SL_PlaceName('C6',71.04,51.12); SL_PlaceName('Q2',81.10,56.20);
    SL_PlaceName('R4',79.04,49.34); SL_PlaceName('R5',84.04,49.34);
    SL_PlaceName('D2',87.54,56.04); SL_PlaceName('J2',95.54,48.27);
    SL_PlaceName('U3',56.82,37.39); SL_PlaceName('C7',51.54,38.64);
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
    SL_Log.Add('COMPONENTS=' + IntToStr(SL_Placed + SL_Mechanical));
    SL_Log.Add('PLACED_TOP_OVERLAY=' + IntToStr(SL_Placed));
    SL_Log.Add('NAME_ERRORS=' + IntToStr(SL_Mechanical));
    SL_Log.Add('AREA_TEXTS_ON_MECHANICAL2=' + IntToStr(SL_FunctionTexts));
End;

Procedure SL_SaveReport;
Var P : String;
Begin
    P := ExtractFilePath(SL_Board.FileName);
    If P <> '' Then
        SL_Log.SaveToFile(P + 'silkscreen-report.txt');
    SL_Log.Free;
End;
{ ----- end relocation core ----- }

Procedure GenerateAquariumPCB;
Var PcbDocument : IServerDocument;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0_New.PcbDoc';
    PcbLibPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0.PcbLib';
    SchLibPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_PhysicalPin_V1_1.SchLib';
    AuditPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\pcb-layout-audit.txt';
    TracePath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\pcb-layout-trace.txt';
    WriteStage('START');
    LoadFailures := 0; AssignFailures := 0; SaveSucceeded := False;
    MR_Success := False;
    AssignErrors := TStringList.Create;
    PcbDocument := Client.OpenDocument('PCB', TargetPath);
    If PcbDocument = Nil Then
    Begin
        AssignErrors.Add('ABORT|cannot_open_target_document');
        WriteFinalStatus;
        AssignErrors.Free;
        Exit;
    End;
    Client.ShowDocument(PcbDocument);
    Board := PCBServer.GetPCBBoardByPath(TargetPath);
    If Board = Nil Then
    Begin
        AssignErrors.Add('ABORT|cannot_get_target_board');
        WriteFinalStatus;
        AssignErrors.Free;
        Exit;
    End;
    { Audit files follow the active PCB document rather than a fixed drive. }
    If ExtractFilePath(PcbDocument.FileName) <> '' Then
    Begin
        AuditPath := ExtractFilePath(PcbDocument.FileName) + 'pcb-layout-audit.txt';
        TracePath := ExtractFilePath(PcbDocument.FileName) + 'pcb-layout-trace.txt';
    End;
    If CountExistingDesignObjects <> 0 Then
    Begin
        AssignErrors.Add('ABORT|target_document_contains_objects_use_NEW_blank_PcbDoc');
        WriteFinalStatus;
        AssignErrors.Free;
        Exit;
    End;
    WriteStage('BOARD_OK');
    Board.DisplayUnit := eMetric;
    PCBServer.PreProcess;
    Try
    CreateBoardOutline;
    Board.XOrigin := MMsToCoord(0);
    Board.YOrigin := MMsToCoord(60);
    WriteStage('OUTLINE_OK');

    AddNet('+12V_IN');
    AddNet('+3V3');
    AddNet('AUX_RX');
    AddNet('AUX_RX_MUX');
    AddNet('AUX_TX');
    AddNet('AUX_TX_MUX');
    AddNet('BST');
    AddNet('D3_A');
    AddNet('D4_A');
    AddNet('GND');
    AddNet('KEY_AUTO');
    AddNet('KEY_MANUAL');
    AddNet('LED_FAULT');
    AddNet('LED_STATUS');
    AddNet('MAIN_RX');
    AddNet('MAIN_RX_MUX');
    AddNet('MAIN_TX');
    AddNet('MAIN_TX_MUX');
    AddNet('MUX_E');
    AddNet('MUX_S0');
    AddNet('MUX_S1');
    AddNet('NRST');
    AddNet('PUMP_CMD');
    AddNet('PUMP_GATE');
    AddNet('PUMP_NEG');
    AddNet('Q1_GATE');
    AddNet('RES_RX');
    AddNet('RES_RX_MUX');
    AddNet('RES_TX');
    AddNet('RES_TX_MUX');
    AddNet('SENS_RX');
    AddNet('SENS_TX');
    AddNet('SW');
    AddNet('SWCLK');
    AddNet('SWDIO');
    AddNet('VIN_FUSED');
    AddNet('VIN_P');
    AddNet('WIFI_MODULE_RX');
    AddNet('WIFI_MODULE_TX');
    AddNet('WIFI_RX');
    AddNet('WIFI_TX');
    WriteStage('NETS_OK');

    { Board-edge I/O and high-current path across the upper band. }
    AddPart('J1','DC IN 12V','DC-IN-TH_DC-005-20A-1','DC_INPUT_2P','ATO1XXXX','01_Power_Pump',12.5,45,0);
    AddPart('F1','RL60-050 / 0.5A','FUSE-TH_L7.8-W3.0-P5.10-D0.5-S2.00','PTC_RESETTABLE_FUSE','ATO5XXXX','01_Power_Pump',24,55,0);
    AddPart('Q1','DMP6023LE-13','SOT-223-4_L6.5-W3.5-P2.30-LS7.0-BR','PMOS_DMP6023LE','ATO9XXXX','01_Power_Pump',34,54,0);
    AddPart('R1','47k','R0805','RESISTOR_0805','ATODXXXX','01_Power_Pump',32,48,0);
    AddPart('D1','BZT52C10','SOD-123_L2.7-W1.6-LS3.7-RD','ZENER_DIODE','ATOHXXXX','01_Power_Pump',27,48,0);
    AddPart('C1','47u/50V','CAP-TH_BD6.3-P2.50-D0.6-FD','CAPACITOR_POLARIZED_RADIAL','ATOPXXXX','01_Power_Pump',43,54,0);
    AddPart('C2','10u/50V X7R','C0805','CAPACITOR_C0805','ATO13XXX','01_Power_Pump',48,49,90);
    AddPart('C3','100n/50V','C0805','CAPACITOR_C0805','ATO17XXX','01_Power_Pump',51,49,90);
    AddPart('U1','AP63203WU-7','TSOT-26_L2.9-W1.6-P0.95-LS2.8-BL','AP63203WU_7','ATOLXXXX','01_Power_Pump',52,54,0);
    AddPart('C4','100n','C0805','CAPACITOR_C0805','ATO1BXXX','01_Power_Pump',56.5,57,0);
    AddPart('L1','3.9uH / Isat 4A','IND-SMD_L5.0-W5.0_FNR50XXS','INDUCTOR_5X5','ATO1FXXX','01_Power_Pump',61,54,0);
    AddPart('C5','22u/10V X7R','C0603','CAPACITOR_C0603','ATO1JXXX','01_Power_Pump',68,49,90);
    AddPart('C6','22u/10V X7R','C0603','CAPACITOR_C0603','ATO1NXXX','01_Power_Pump',72,49,90);
    AddPart('Q2','AO3400A','SOT-23-3_L2.9-W1.3-P1.90-LS2.4-BR','NMOS_AO3400A','ATO21XXX','01_Power_Pump',82,54,0);
    AddPart('R4','1k','R0603','RESISTOR_0603','ATO25XXX','01_Power_Pump',80,48,0);
    AddPart('R5','100k','R0603','RESISTOR_0603','ATO29XXX','01_Power_Pump',85,48,0);
    AddPart('D2','SS16 / 60V','SMA_L4.3-W2.6-LS5.0-RD','DIODE','ATO2HXXX','01_Power_Pump',88.5,54,0);
    AddPart('J2','PUMP 12V','CONN-TH_LAIL-PZ2.54-2P-L','PUMP_OUTPUT_2P','ATO2DXXX','01_Power_Pump',96.5,45,90);

    { MCU centered between sensor, power, debug and user-interface fanout. }
    AddPart('U3','STM32G030F6P6','TSSOP-20_L6.5-W4.4-P0.65-LS6.4-BL','STM32G030F6P6','ATO2LXXX','02_Controller_IO',58,33,0);
    AddPart('C7','100n','C0805','CAPACITOR_C0805','ATO2PXXX','02_Controller_IO',52.5,36,90);
    AddPart('C8','4.7u / 10V','C0603','CAPACITOR_C0603','ATO33XXX','02_Controller_IO',52.5,31,90);
    AddPart('R8','10k','R0805','RESISTOR_0805','ATO37XXX','02_Controller_IO',52.5,27,90);
    AddPart('C15','100n','C0805','CAPACITOR_C0805','ATO3BXXX','02_Controller_IO',58,26,0);
    AddPart('SW3','RESET','SW-SMD_L3.9-W3.0-P4.45','SWITCH_TACT','ATO3FXXX','02_Controller_IO',68,32,0);
    AddPart('J5','SWD 4PIN','HDR-TH_4P-P2.54-V-M','SWD_4P','ATO3JXXX','02_Controller_IO',58,44,0);

    { Right-edge WiFi connector, local bulk decoupling and user controls. }
    AddPart('J7','WIFI UART','HDR-TH_4P-P2.54-V-M','WIFI_UART_4P','ATO3NXXX','02_Controller_IO',96.5,34,90);
    AddPart('C16','100n','C0805','CAPACITOR_C0805','ATO41XXX','02_Controller_IO',90.5,30,90);
    AddPart('C17','10u / 10V','C0603','CAPACITOR_C0603','ATO45XXX','02_Controller_IO',87,30,90);
    AddPart('C18','220u / 6.3V','C1206','CAPACITOR_C1206','ATO49XXX','02_Controller_IO',88,38,0);
    AddPart('R2','1k','R0603','RESISTOR_0603','ATO4DXXX','02_Controller_IO',72,38,0);
    AddPart('R3','1k','R0603','RESISTOR_0603','ATO4HXXX','02_Controller_IO',73.5,34,0);
    AddPart('R25','10k','R0805','RESISTOR_0805','ATO4LXXX','02_Controller_IO',78,38,0);
    AddPart('R18','10k','R0805','RESISTOR_0805','ATO4PXXX','02_Controller_IO',78,34,0);
    AddPart('R6','10k','R0805','RESISTOR_0805','ATO53XXX','02_Controller_IO',75,18,90);
    AddPart('SW1','AUTO / PAUSE','SW-SMD_L3.9-W3.0-P4.45','SWITCH_TACT','ATO57XXX','02_Controller_IO',78,8,0);
    AddPart('C13','100n','C0805','CAPACITOR_C0805','ATO5BXXX','02_Controller_IO',81,18,90);
    AddPart('R7','10k','R0805','RESISTOR_0805','ATO5FXXX','02_Controller_IO',85,18,90);
    AddPart('SW2','MANUAL HOLD','SW-SMD_L3.9-W3.0-P4.45','SWITCH_TACT','ATO5JXXX','02_Controller_IO',88,8,0);
    AddPart('C14','100n','C0805','CAPACITOR_C0805','ATO5NXXX','02_Controller_IO',91,18,90);
    AddPart('R9','1k','R0603','RESISTOR_0603','ATO61XXX','02_Controller_IO',75,24,0);
    AddPart('D3','STATUS','LED0603-RD','LED_0603','ATO65XXX','02_Controller_IO',80,24,0);
    AddPart('R10','1k','R0603','RESISTOR_0603','ATO69XXX','02_Controller_IO',86,24,0);
    AddPart('D4','FAULT','LED0603-RD_RED','LED_0603','ATO6DXXX','02_Controller_IO',91,24,0);

    { Bottom-edge sensor headers, protection parts above them, mux toward board center. }
    AddPart('U2','74HC4052D,652','SO-16_L9.9-W3.9-P1.27-LS6.0-BL','74HC4052D','ATO6HXXX','03_Sensors',36,27,90);
    AddPart('C12','100n','C0805','CAPACITOR_C0805','ATO6LXXX','03_Sensors',29,27,90);
    AddPart('R14','10k','R0805','RESISTOR_0805','ATO6PXXX','03_Sensors',30,34.5,0);
    AddPart('R11','10k','R0805','RESISTOR_0805','ATO73XXX','03_Sensors',35,34.5,0);
    AddPart('R12','100k','R0603','RESISTOR_0603','ATO77XXX','03_Sensors',40,34.5,0);
    AddPart('R13','100k','R0603','RESISTOR_0603','ATO7BXXX','03_Sensors',45,34.5,0);
    AddPart('J3','MAIN LEVEL','HDR-TH_4P-P2.54-V-M','SENSOR_UART_4P','ATO7FXXX','03_Sensors',14,3,0);
    AddPart('C9','100n','C0805','CAPACITOR_C0805','ATO7JXXX','03_Sensors',9,10,90);
    AddPart('R19','1k','R0603','RESISTOR_0603','ATO7NXXX','03_Sensors',12,15,90);
    AddPart('R20','1k','R0603','RESISTOR_0603','ATO81XXX','03_Sensors',16,15,90);
    AddPart('R15','10k','R0805','RESISTOR_0805','ATO85XXX','03_Sensors',20,10,90);
    AddPart('J4','AUX LEVEL','HDR-TH_4P-P2.54-V-M','SENSOR_UART_4P','ATO89XXX','03_Sensors',38,3,0);
    AddPart('C10','100n','C0805','CAPACITOR_C0805','ATO8DXXX','03_Sensors',33,10,90);
    AddPart('R21','1k','R0603','RESISTOR_0603','ATO8HXXX','03_Sensors',36,15,90);
    AddPart('R22','1k','R0603','RESISTOR_0603','ATO8LXXX','03_Sensors',40,15,90);
    AddPart('R16','10k','R0805','RESISTOR_0805','ATO8PXXX','03_Sensors',44,10,90);
    AddPart('J6','RESERVOIR','HDR-TH_4P-P2.54-V-M','SENSOR_UART_4P','ATO93XXX','03_Sensors',62,3,0);
    AddPart('C11','100n','C0805','CAPACITOR_C0805','ATO97XXX','03_Sensors',57,10,90);
    AddPart('R23','1k','R0603','RESISTOR_0603','ATO9BXXX','03_Sensors',60,15,90);
    AddPart('R24','1k','R0603','RESISTOR_0603','ATO9FXXX','03_Sensors',64,15,90);
    AddPart('R17','10k','R0805','RESISTOR_0805','ATO9JXXX','03_Sensors',68,10,90);

    AssignPad('J1','1','+12V_IN');
    AssignPad('J1','2','GND');
    AssignPad('F1','1','+12V_IN');
    AssignPad('F1','2','VIN_FUSED');
    AssignPad('Q1','4','VIN_FUSED');
    AssignPad('Q1','1','Q1_GATE');
    AssignPad('Q1','2','VIN_FUSED');
    AssignPad('Q1','3','VIN_P');
    AssignPad('R1','1','Q1_GATE');
    AssignPad('R1','2','GND');
    AssignPad('D1','1','VIN_P');
    AssignPad('D1','2','Q1_GATE');
    AssignPad('U1','1','+3V3');
    AssignPad('U1','2','VIN_P');
    AssignPad('U1','3','VIN_P');
    AssignPad('U1','6','BST');
    AssignPad('U1','5','SW');
    AssignPad('U1','4','GND');
    AssignPad('C1','1','VIN_P');
    AssignPad('C1','2','GND');
    AssignPad('C2','1','VIN_P');
    AssignPad('C2','2','GND');
    AssignPad('C3','1','VIN_P');
    AssignPad('C3','2','GND');
    AssignPad('C4','1','BST');
    AssignPad('C4','2','SW');
    AssignPad('L1','1','SW');
    AssignPad('L1','2','+3V3');
    AssignPad('C5','1','+3V3');
    AssignPad('C5','2','GND');
    AssignPad('C6','1','+3V3');
    AssignPad('C6','2','GND');
    AssignPad('Q2','3','PUMP_NEG');
    AssignPad('Q2','1','PUMP_GATE');
    AssignPad('Q2','2','GND');
    AssignPad('R4','1','PUMP_CMD');
    AssignPad('R4','2','PUMP_GATE');
    AssignPad('R5','1','PUMP_GATE');
    AssignPad('R5','2','GND');
    AssignPad('J2','1','VIN_P');
    AssignPad('J2','2','PUMP_NEG');
    AssignPad('D2','1','VIN_P');
    AssignPad('D2','2','PUMP_NEG');
    AssignPad('U3','1','WIFI_RX');
    AssignPad('U3','2','MUX_S0');
    AssignPad('U3','3','MUX_S1');
    AssignPad('U3','4','+3V3');
    AssignPad('U3','5','GND');
    AssignPad('U3','6','NRST');
    AssignPad('U3','7','MUX_E');
    AssignPad('U3','9','SENS_TX');
    AssignPad('U3','10','SENS_RX');
    AssignPad('U3','20','WIFI_TX');
    AssignPad('U3','19','SWCLK');
    AssignPad('U3','18','SWDIO');
    AssignPad('U3','16','KEY_AUTO');
    AssignPad('U3','14','LED_FAULT');
    AssignPad('U3','13','LED_STATUS');
    AssignPad('U3','12','KEY_MANUAL');
    AssignPad('U3','11','PUMP_CMD');
    AssignPad('C7','1','+3V3');
    AssignPad('C7','2','GND');
    AssignPad('C8','1','+3V3');
    AssignPad('C8','2','GND');
    AssignPad('R8','1','+3V3');
    AssignPad('R8','2','NRST');
    AssignPad('C15','1','NRST');
    AssignPad('C15','2','GND');
    AssignPad('SW3','1','NRST');
    AssignPad('SW3','2','GND');
    AssignPad('J5','1','+3V3');
    AssignPad('J5','2','SWDIO');
    AssignPad('J5','3','GND');
    AssignPad('J5','4','SWCLK');
    AssignPad('J7','1','+3V3');
    AssignPad('J7','2','GND');
    AssignPad('J7','3','WIFI_MODULE_RX');
    AssignPad('J7','4','WIFI_MODULE_TX');
    AssignPad('C16','1','+3V3');
    AssignPad('C16','2','GND');
    AssignPad('C17','1','+3V3');
    AssignPad('C17','2','GND');
    AssignPad('C18','1','+3V3');
    AssignPad('C18','2','GND');
    AssignPad('R2','1','WIFI_TX');
    AssignPad('R2','2','WIFI_MODULE_RX');
    AssignPad('R3','1','WIFI_RX');
    AssignPad('R3','2','WIFI_MODULE_TX');
    AssignPad('R25','1','+3V3');
    AssignPad('R25','2','WIFI_MODULE_RX');
    AssignPad('R18','1','+3V3');
    AssignPad('R18','2','WIFI_RX');
    AssignPad('R6','1','+3V3');
    AssignPad('R6','2','KEY_AUTO');
    AssignPad('SW1','1','KEY_AUTO');
    AssignPad('SW1','2','GND');
    AssignPad('C13','1','KEY_AUTO');
    AssignPad('C13','2','GND');
    AssignPad('R7','1','+3V3');
    AssignPad('R7','2','KEY_MANUAL');
    AssignPad('SW2','1','KEY_MANUAL');
    AssignPad('SW2','2','GND');
    AssignPad('C14','1','KEY_MANUAL');
    AssignPad('C14','2','GND');
    AssignPad('R9','1','LED_STATUS');
    AssignPad('R9','2','D3_A');
    AssignPad('D3','2','D3_A');
    AssignPad('D3','1','GND');
    AssignPad('R10','1','LED_FAULT');
    AssignPad('R10','2','D4_A');
    AssignPad('D4','2','D4_A');
    AssignPad('D4','1','GND');
    AssignPad('U2','1','MAIN_TX_MUX');
    AssignPad('U2','2','RES_TX_MUX');
    AssignPad('U2','3','SENS_RX');
    AssignPad('U2','5','AUX_TX_MUX');
    AssignPad('U2','6','MUX_E');
    AssignPad('U2','7','GND');
    AssignPad('U2','8','GND');
    AssignPad('U2','16','+3V3');
    AssignPad('U2','15','RES_RX_MUX');
    AssignPad('U2','14','AUX_RX_MUX');
    AssignPad('U2','13','SENS_TX');
    AssignPad('U2','12','MAIN_RX_MUX');
    AssignPad('U2','10','MUX_S0');
    AssignPad('U2','9','MUX_S1');
    AssignPad('C12','1','+3V3');
    AssignPad('C12','2','GND');
    AssignPad('R14','1','+3V3');
    AssignPad('R14','2','SENS_RX');
    AssignPad('R11','1','+3V3');
    AssignPad('R11','2','MUX_E');
    AssignPad('R12','1','MUX_S0');
    AssignPad('R12','2','GND');
    AssignPad('R13','1','MUX_S1');
    AssignPad('R13','2','GND');
    AssignPad('J3','1','+3V3');
    AssignPad('J3','2','GND');
    AssignPad('J3','3','MAIN_RX');
    AssignPad('J3','4','MAIN_TX');
    AssignPad('C9','1','+3V3');
    AssignPad('C9','2','GND');
    AssignPad('R19','1','MAIN_RX_MUX');
    AssignPad('R19','2','MAIN_RX');
    AssignPad('R20','1','MAIN_TX_MUX');
    AssignPad('R20','2','MAIN_TX');
    AssignPad('R15','1','+3V3');
    AssignPad('R15','2','MAIN_RX');
    AssignPad('J4','1','+3V3');
    AssignPad('J4','2','GND');
    AssignPad('J4','3','AUX_RX');
    AssignPad('J4','4','AUX_TX');
    AssignPad('C10','1','+3V3');
    AssignPad('C10','2','GND');
    AssignPad('R21','1','AUX_RX_MUX');
    AssignPad('R21','2','AUX_RX');
    AssignPad('R22','1','AUX_TX_MUX');
    AssignPad('R22','2','AUX_TX');
    AssignPad('R16','1','+3V3');
    AssignPad('R16','2','AUX_RX');
    AssignPad('J6','1','+3V3');
    AssignPad('J6','2','GND');
    AssignPad('J6','3','RES_RX');
    AssignPad('J6','4','RES_TX');
    AssignPad('C11','1','+3V3');
    AssignPad('C11','2','GND');
    AssignPad('R23','1','RES_RX_MUX');
    AssignPad('R23','2','RES_RX');
    AssignPad('R24','1','RES_TX_MUX');
    AssignPad('R24','2','RES_TX');
    AssignPad('R17','1','+3V3');
    AssignPad('R17','2','RES_RX');
    AnalyzeAllNets;
    WriteStage('CONNECTIVITY_OK');

    AddClass('PWR_HIGH','+12V_IN,VIN_FUSED,VIN_P,PUMP_NEG,GND',True);
    AddClass('POWER_INPUT_BUCK','J1,F1,Q1,R1,D1,C1,C2,C3,U1,C4,L1,C5,C6',False);
    AddClass('PUMP_DRIVER','Q2,R4,R5,D2,J2',False);
    AddClass('MCU_DEBUG','U3,C7,C8,R8,C15,SW3,J5',False);
    AddClass('WIFI_UI','J7,C16,C17,C18,R2,R3,R25,R18,R6,SW1,C13,R7,SW2,C14,R9,D3,R10,D4',False);
    AddClass('SENSORS_MUX','U2,C12,R14,R11,R12,R13,J3,C9,R19,R20,R15,J4,C10,R21,R22,R16,J6,C11,R23,R24,R17',False);
    WriteStage('CLASSES_OK');
    AddRuleSet;
    WriteStage('RULES_OK');

    AddText('AQUARIUM ATO V1.0',2,58,1.0);
    AddText('POWER / BUCK',18,58,0.8);
    AddText('PUMP',82,58,0.8);
    AddText('SENSORS',2,20,0.8);
    AddText('MCU / SWD',51,43,0.8);
    AddText('WIFI / USER',77,28,0.8);
    AddText('MANUAL COPPER - CHECK DRC',69,2,0.7);
    { Set name positions only after ALL real packages and zones are placed. }
    SL_Board := Board;
    SL_Layout;
    MR_Board := Board;
    MR_RunRouteAndPour;
    Finally
        PCBServer.PostProcess;
    End;
    If MR_Success Then Begin
        ResetParameters; AddStringParameter('Action','RepourAllPolygons');
        RunProcess('PCB:ChangeObject');
    End;

    Board.ViewManager_FullUpdate;
    ResetParameters; AddStringParameter('Action','All'); RunProcess('PCB:Zoom');
    If (LoadFailures = 0) And (AssignFailures = 0) And
       (SL_Mechanical = 0) And MR_Success Then
    Begin
        PcbDocument.Modified := True;
        SaveSucceeded := PcbDocument.DoFileSave('');
    End
    Else
        SaveSucceeded := False;
    SL_SaveReport;
    WriteStage('SAVE1_OK');
    WriteAudit;
    WriteStage('AUDIT_OK');
    WriteFinalStatus;
    AssignErrors.Free;
End;

End.

