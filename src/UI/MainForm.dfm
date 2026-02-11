object AppMainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Agent Skill Search'
  ClientHeight = 821
  ClientWidth = 1384
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnKeyDown = HandleFormKeyDown
  TextHeight = 17
  object fSearchPanel: TPanel
    Left = 0
    Top = 0
    Width = 1384
    Height = 92
    Align = alTop
    BevelOuter = bvNone
    Color = $00F5F5F5
    ParentBackground = False
    Padding.Left = 16
    Padding.Top = 12
    Padding.Right = 16
    Padding.Bottom = 12
    TabOrder = 0
    object fSearchActionsPanel: TPanel
      AlignWithMargins = True
      Left = 855
      Top = 12
      Width = 513
      Height = 68
      Margins.Left = 16
      Align = alRight
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 1
      object fSearchAsYouTypeCheckBox: TCheckBox
        AlignWithMargins = True
        Left = 387
        Top = 22
        Width = 126
        Height = 24
        Margins.Left = 12
        Margins.Top = 10
        Margins.Bottom = 10
        Align = alRight
        Caption = 'Search as you type'
        TabOrder = 3
      end
      object fDiagnosticsButton: TButton
        AlignWithMargins = True
        Left = 255
        Top = 16
        Width = 120
        Height = 36
        Margins.Left = 12
        Margins.Top = 4
        Margins.Bottom = 4
        Align = alRight
        Caption = '&Diagnostics'
        TabOrder = 2
        OnClick = HandleDiagnosticsButtonClick
      end
      object fScanButton: TButton
        AlignWithMargins = True
        Left = 123
        Top = 16
        Width = 120
        Height = 36
        Margins.Left = 12
        Margins.Top = 4
        Margins.Bottom = 4
        Align = alRight
        Caption = 'S&can/Update'
        TabOrder = 1
        OnClick = HandleScanButtonClick
      end
      object fSearchButton: TButton
        AlignWithMargins = True
        Left = 1
        Top = 16
        Width = 110
        Height = 36
        Margins.Top = 4
        Margins.Bottom = 4
        Align = alRight
        Caption = '&Search'
        TabOrder = 0
        OnClick = HandleSearchButtonClick
      end
    end
    object fSearchFieldPanel: TPanel
      AlignWithMargins = True
      Left = 16
      Top = 12
      Width = 823
      Height = 68
      Align = alClient
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 0
      object fSearchEdit: TEdit
        Left = 0
        Top = 34
        Width = 744
        Height = 25
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        TextHint = 'Search skills (supports name:, tag:, path:, has:scripts, limit:)'
        OnChange = HandleSearchEditChange
        OnKeyDown = HandleSearchEditKeyDown
      end
      object fSearchEditLabel: TStaticText
        Left = 0
        Top = 0
        Width = 823
        Height = 17
        Align = alTop
        AutoSize = False
        BorderStyle = sbsNone
        Caption = 'Search query'
        TabStop = False
      end
      object fSearchHelpImage: TImage
        Left = 759
        Top = 2
        Width = 64
        Height = 64
        Cursor = crHandPoint
        Anchors = [akTop, akRight]
        Center = True
        Proportional = True
        Stretch = True
        OnClick = HandleSearchHelpButtonClick
      end
    end
  end
  object fFiltersPanel: TPanel
    Left = 0
    Top = 92
    Width = 1384
    Height = 44
    Align = alTop
    BevelOuter = bvNone
    Color = $00F8F8F8
    ParentBackground = False
    Padding.Left = 16
    Padding.Right = 16
    Padding.Bottom = 8
    TabOrder = 1
    object fHasScriptsCheckBox: TCheckBox
      AlignWithMargins = True
      Left = 16
      Top = 8
      Width = 108
      Height = 28
      Align = alLeft
      Caption = 'Has scripts'
      TabOrder = 0
      OnClick = HandleHasScriptsClick
    end
    object fDockerHealthLabel: TStaticText
      AlignWithMargins = True
      Left = 810
      Top = 8
      Width = 126
      Height = 28
      Margins.Right = 8
      Align = alRight
      AutoSize = False
      BorderStyle = sbsNone
      Caption = 'Docker: checking...'
      TabStop = False
    end
    object fDockerGpuButton: TButton
      AlignWithMargins = True
      Left = 902
      Top = 8
      Width = 128
      Height = 28
      Margins.Right = 8
      Align = alRight
      Caption = 'Start Docker Stack'
      TabOrder = 1
      OnClick = HandleDockerGpuButtonClick
    end
    object fScanProgressBar: TProgressBar
      AlignWithMargins = True
      Left = 1038
      Top = 8
      Width = 330
      Height = 28
      Align = alRight
      MarqueeInterval = 30
      Style = pbstMarquee
      TabOrder = 2
      Visible = False
    end
  end
  object fMainPanel: TPanel
    Left = 0
    Top = 136
    Width = 1384
    Height = 666
    Align = alClient
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    Padding.Left = 12
    Padding.Top = 8
    Padding.Right = 12
    Padding.Bottom = 12
    TabOrder = 2
    object fPreviewHostPanel: TPanel
      Left = 766
      Top = 9
      Width = 606
      Height = 645
      Align = alClient
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 1
      object fDuplicateInfoPanel: TPanel
        Left = 386
        Top = 0
        Width = 220
        Height = 645
        Align = alRight
        BevelOuter = bvNone
        Caption = ''
        TabOrder = 1
        object fDuplicateInfoMemo: TMemo
          Left = 0
          Top = 17
          Width = 220
          Height = 628
          Align = alClient
          BorderStyle = bsNone
          Lines.Strings = (
            'No duplicate details available.')
          ReadOnly = True
          TabOrder = 0
        end
        object fDuplicateInfoLabel: TStaticText
          Left = 0
          Top = 0
          Width = 220
          Height = 17
          Align = alTop
          AutoSize = False
          BorderStyle = sbsNone
          Caption = 'Duplicate details'
          TabStop = False
        end
      end
      object fPreviewInfoSplitter: TSplitter
        Left = 380
        Top = 0
        Width = 6
        Height = 645
        Align = alRight
        ExplicitLeft = 384
        ExplicitTop = 8
        ExplicitHeight = 637
      end
      object fPreviewPanel: TPanel
        Left = 0
        Top = 0
        Width = 380
        Height = 645
        Align = alClient
        BevelOuter = bvNone
        Caption = ''
        TabOrder = 0
        object fPreviewBrowser: TTMSFNCWebBrowser
          Left = 0
          Top = 17
          Width = 380
          Height = 628
          Align = alClient
          TabOrder = 0
        end
        object fPreviewLabel: TStaticText
          Left = 0
          Top = 0
          Width = 380
          Height = 17
          Align = alTop
          AutoSize = False
          BorderStyle = sbsNone
          Caption = 'Skill preview'
          TabStop = False
        end
      end
    end
    object fResultsPreviewSplitter: TSplitter
      Left = 760
      Top = 9
      Width = 6
      Height = 645
      Align = alLeft
      ExplicitTop = 8
      ExplicitHeight = 637
    end
    object fResultsPanePanel: TPanel
      Left = 12
      Top = 9
      Width = 748
      Height = 645
      Align = alLeft
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 0
      object fResultsListView: TListView
        Left = 0
        Top = 17
        Width = 748
        Height = 628
        Align = alClient
        HideSelection = False
        PopupMenu = fPopupMenu
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnDblClick = HandleResultDoubleClick
        OnKeyDown = HandleResultKeyDown
        OnSelectItem = HandleResultSelectItem
      end
      object fResultsListLabel: TStaticText
        Left = 0
        Top = 0
        Width = 748
        Height = 17
        Align = alTop
        AutoSize = False
        BorderStyle = sbsNone
        Caption = 'Search results'
        TabStop = False
      end
    end
  end
  object fStatusBar: TStatusBar
    Left = 0
    Top = 802
    Width = 1384
    Height = 19
    Panels = <
      item
        Text = 'Ready'
        Width = 300
      end
      item
        Text = 'Found: 0'
        Width = 120
      end
      item
        Text = 'Valid: 0'
        Width = 120
      end
      item
        Text = 'Unique: 0'
        Width = 120
      end
      item
        Text = 'Results: 0'
        Width = 120
      end
      item
        Text = 'Last scan: n/a'
        Width = 190
      end
      item
        Text = 'Cache: n/a'
        Width = 414
      end>
    SimplePanel = False
  end
  object fPopupMenu: TPopupMenu
    Left = 392
    Top = 152
    object fOpenFileMenuItem: TMenuItem
      Caption = 'Open Skill File'
      OnClick = HandleOpenFileClick
    end
    object fOpenFolderMenuItem: TMenuItem
      Caption = 'Open Containing Folder'
      OnClick = HandleOpenFolderClick
    end
    object fCopyPathMenuItem: TMenuItem
      Caption = 'Copy Skill Path'
      OnClick = HandleCopyPathClick
    end
  end
end
