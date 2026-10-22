Var
    Board : IPCB_Board;

Procedure AddRoutingRules;
Var
    Clearance : IPCB_ClearanceConstraint;
    SignalWidth : IPCB_MaxMinWidthConstraint;
    PowerWidth : IPCB_MaxMinWidthConstraint;
    ViaRule : IPCB_RoutingViaStyleRule;
Begin
    { The imported EasyEDA board contains broad defaults.  These named rules
      make the first routing pass predictable; the specific power rule takes
      priority over the generic signal rule. }
    Clearance := PCBServer.PCBRuleFactory(eRule_Clearance);
    Clearance.Name := 'ATO_Clearance_0_20mm';
    Clearance.Scope1Expression := 'All';
    Clearance.Scope2Expression := 'All';
    Clearance.Gap := MMsToCoord(0.20);
    Board.AddPCBObject(Clearance);

    PowerWidth := PCBServer.PCBRuleFactory(eRule_MaxMinWidth);
    PowerWidth.Name := 'ATO_Power_Width';
    PowerWidth.Scope1Expression :=
        'InNet(''VIN_P'') Or InNet(''+3V3'') Or InNet(''GND'')';
    PowerWidth.MinWidth[eTopLayer] := MMsToCoord(0.50);
    PowerWidth.FavoredWidth[eTopLayer] := MMsToCoord(0.80);
    PowerWidth.MaxWidth[eTopLayer] := MMsToCoord(1.50);
    PowerWidth.MinWidth[eBottomLayer] := MMsToCoord(0.50);
    PowerWidth.FavoredWidth[eBottomLayer] := MMsToCoord(0.80);
    PowerWidth.MaxWidth[eBottomLayer] := MMsToCoord(1.50);
    Board.AddPCBObject(PowerWidth);

    SignalWidth := PCBServer.PCBRuleFactory(eRule_MaxMinWidth);
    SignalWidth.Name := 'ATO_Signal_Width';
    SignalWidth.Scope1Expression := 'All';
    SignalWidth.MinWidth[eTopLayer] := MMsToCoord(0.20);
    SignalWidth.FavoredWidth[eTopLayer] := MMsToCoord(0.25);
    SignalWidth.MaxWidth[eTopLayer] := MMsToCoord(0.50);
    SignalWidth.MinWidth[eBottomLayer] := MMsToCoord(0.20);
    SignalWidth.FavoredWidth[eBottomLayer] := MMsToCoord(0.25);
    SignalWidth.MaxWidth[eBottomLayer] := MMsToCoord(0.50);
    Board.AddPCBObject(SignalWidth);

    ViaRule := PCBServer.PCBRuleFactory(eRule_RoutingViaStyle);
    ViaRule.Name := 'ATO_Via_0_70_0_35';
    ViaRule.Scope1Expression := 'All';
    ViaRule.MinWidth := MMsToCoord(0.60);
    ViaRule.PreferedWidth := MMsToCoord(0.70);
    ViaRule.MaxWidth := MMsToCoord(1.00);
    ViaRule.MinHoleWidth := MMsToCoord(0.30);
    ViaRule.PreferedHoleWidth := MMsToCoord(0.35);
    ViaRule.MaxHoleWidth := MMsToCoord(0.50);
    Board.AddPCBObject(ViaRule);
End;

Procedure PrepareInitialRouting;
Var
    TargetPath : String;
    Doc : IServerDocument;
    Status : TStringList;
Begin
    TargetPath := 'F:\workSapce_PCB\aquarium\schematic_v1_0\Aquarium_ATO_V1_0.PcbDoc';
    Doc := Client.OpenDocument('PCB', TargetPath);
    If Doc <> Nil Then Client.ShowDocument(Doc);
    Board := PCBServer.GetPCBBoardByPath(TargetPath);
    If Board = Nil Then Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    PCBServer.PreProcess;
    AddRoutingRules;
    PCBServer.PostProcess;
    Board.ViewManager_FullUpdate;
    Doc.DoFileSave('');
    Status := TStringList.Create;
    Status.Add('OK');
    Status.SaveToFile('F:\workSapce_PCB\aquarium\schematic_v1_0\routing-rules-status.txt');
    Status.Free;
End;

End.
