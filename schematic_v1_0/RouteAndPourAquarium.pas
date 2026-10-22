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

{ Run this process on a successfully rebuilt PCB, NOT on the orphan-pad board. }
Procedure RouteAndPourAquarium;
Begin
    MR_Board:=PCBServer.GetCurrentPCBBoard;
    If MR_Board=Nil Then Exit;
    PCBServer.PreProcess;
    Try
        MR_RunRouteAndPour;
    Finally
        PCBServer.PostProcess;
    End;
    If MR_Success Then Begin
        ResetParameters;
        AddStringParameter('Action','RepourAllPolygons');
        RunProcess('PCB:ChangeObject');
    End;
    MR_Board.ViewManager_FullUpdate;
    ResetParameters; AddStringParameter('Action','Redraw'); RunProcess('PCB:Zoom');
End;

End.
