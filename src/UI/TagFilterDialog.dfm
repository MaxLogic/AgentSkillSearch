object TagFilterDialog: TTagFilterDialog
  Left = 0
  Top = 0
  ActiveControl = FilterEdit
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Select Tags'
  ClientHeight = 548
  ClientWidth = 520
  Color = clWhite
  Constraints.MinHeight = 460
  Constraints.MinWidth = 420
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 17
  object FooterPanel: TPanel
    Left = 0
    Top = 492
    Width = 520
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    Color = clWhitesmoke
    Padding.Left = 16
    Padding.Top = 10
    Padding.Right = 16
    Padding.Bottom = 10
    ParentBackground = False
    TabOrder = 1
    object BtnOK: TBitBtn
      AlignWithMargins = True
      Left = 304
      Top = 10
      Width = 90
      Height = 36
      Hint = 'Apply tag filter|Use the selected tags in the current search.|0'
      Margins.Top = 0
      Margins.Right = 8
      Margins.Bottom = 0
      Align = alRight
      Caption = '&OK'
      Default = True
      ModalResult = 1
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
    end
    object BtnCancel: TBitBtn
      AlignWithMargins = True
      Left = 405
      Top = 10
      Width = 96
      Height = 36
      Hint = 'Cancel|Close without changing the selected tags.|0'
      Margins.Top = 0
      Margins.Bottom = 0
      Align = alRight
      Cancel = True
      Caption = '&Cancel'
      ModalResult = 2
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
    end
  end
  object ContentPanel: TPanel
    Left = 0
    Top = 0
    Width = 520
    Height = 492
    Align = alClient
    BevelOuter = bvNone
    Color = clWhite
    Padding.Left = 16
    Padding.Top = 16
    Padding.Right = 16
    Padding.Bottom = 16
    ParentBackground = False
    TabOrder = 0
    object TagsPanel: TPanel
      AlignWithMargins = True
      Left = 16
      Top = 168
      Width = 488
      Height = 308
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alClient
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 2
      object TagCheckListBox: TCheckListBox
        Left = 0
        Top = 25
        Width = 488
        Height = 283
        Align = alClient
        ItemHeight = 17
        PopupMenu = PopupMenuTags
        TabOrder = 0
        OnClickCheck = HandleTagClickCheck
      end
      object TagsLabel: TStaticText
        AlignWithMargins = True
        Left = 0
        Top = 0
        Width = 488
        Height = 17
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 8
        Align = alTop
        AutoSize = False
        Caption = 'Tags'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 4473924
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 1
      end
    end
    object FilterPanel: TPanel
      AlignWithMargins = True
      Left = 16
      Top = 100
      Width = 488
      Height = 52
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 16
      Align = alTop
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 1
      object FilterEdit: TEdit
        AlignWithMargins = True
        Left = 0
        Top = 25
        Width = 488
        Height = 25
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alTop
        TabOrder = 0
        TextHint = 'Filter tags'
        OnChange = HandleFilterChange
      end
      object FilterLabel: TStaticText
        AlignWithMargins = True
        Left = 0
        Top = 0
        Width = 488
        Height = 17
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 8
        Align = alTop
        AutoSize = False
        Caption = 'Filter'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 4473924
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 1
      end
    end
    object HeaderPanel: TPanel
      AlignWithMargins = True
      Left = 16
      Top = 16
      Width = 488
      Height = 68
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 16
      Align = alTop
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 0
      object SummaryLabel: TStaticText
        AlignWithMargins = True
        Left = 0
        Top = 36
        Width = 488
        Height = 17
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alTop
        AutoSize = False
        Caption = '0 of 0 tags shown'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 7048739
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
      end
      object TitleLabel: TStaticText
        AlignWithMargins = True
        Left = 0
        Top = 0
        Width = 488
        Height = 28
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 8
        Align = alTop
        AutoSize = False
        Caption = 'Select Tags'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -19
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 1
      end
    end
  end
  object PopupMenuTags: TPopupMenu
    Left = 448
    Top = 24
    object CheckAllMenuItem: TMenuItem
      Caption = 'Check all'
      OnClick = HandleCheckAllClick
    end
    object UncheckAllMenuItem: TMenuItem
      Caption = 'Uncheck all'
      OnClick = HandleUncheckAllClick
    end
  end
  object BalloonHint: TBalloonHint
    Left = 400
    Top = 80
  end
end
