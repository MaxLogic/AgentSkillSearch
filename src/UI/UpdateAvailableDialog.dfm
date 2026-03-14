object UpdateAvailableDialog: TUpdateAvailableDialog
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Update available'
  ClientHeight = 376
  ClientWidth = 752
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  TextHeight = 17
  object ButtonsPanel: TPanel
    Left = 0
    Top = 320
    Width = 752
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    Color = 16119285
    ParentBackground = False
    Padding.Left = 16
    Padding.Top = 10
    Padding.Right = 16
    Padding.Bottom = 10
    TabOrder = 0
    object BtnLater: TBitBtn
      AlignWithMargins = True
      Left = 617
      Top = 10
      Width = 119
      Height = 36
      Margins.Top = 0
      Margins.Bottom = 0
      Align = alRight
      Cancel = True
      Caption = 'Maybe later'
      ModalResult = 2
      TabOrder = 1
    end
    object BtnOpenRelease: TBitBtn
      AlignWithMargins = True
      Left = 475
      Top = 10
      Width = 134
      Height = 36
      Margins.Top = 0
      Margins.Right = 8
      Margins.Bottom = 0
      Align = alRight
      Caption = 'Open GitHub'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
  end
  object VisualShellPanel: TPanel
    AlignWithMargins = True
    Left = 20
    Top = 20
    Width = 260
    Height = 280
    Margins.Left = 20
    Margins.Top = 20
    Margins.Right = 12
    Margins.Bottom = 20
    Align = alLeft
    BevelOuter = bvNone
    Caption = ''
    Color = 16643571
    Padding.Left = 12
    Padding.Top = 12
    Padding.Right = 12
    Padding.Bottom = 12
    ParentBackground = False
    TabOrder = 1
    object VisualPanel: TPanel
      Left = 12
      Top = 12
      Width = 236
      Height = 256
      Align = alClient
      BevelOuter = bvNone
      Caption = ''
      Color = clWhite
      ParentBackground = False
      TabOrder = 0
      object VisualBrowser: TTMSFNCWebBrowser
        AlignWithMargins = True
        Left = 0
        Top = 0
        Width = 236
        Height = 256
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        TabOrder = 0
        OnInitialized = VisualBrowserInitialized
      end
    end
  end
  object CopyPanel: TPanel
    AlignWithMargins = True
    Left = 292
    Top = 20
    Width = 440
    Height = 280
    Margins.Left = 0
    Margins.Top = 20
    Margins.Right = 20
    Margins.Bottom = 20
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clWhite
    Padding.Left = 8
    Padding.Top = 8
    Padding.Right = 8
    Padding.Bottom = 8
    ParentBackground = False
    TabOrder = 2
    object VersionCardPanel: TPanel
      AlignWithMargins = True
      Left = 8
      Top = 194
      Width = 424
      Height = 78
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alTop
      BevelOuter = bvNone
      Caption = ''
      Color = 16644855
      Padding.Left = 14
      Padding.Top = 12
      Padding.Right = 14
      Padding.Bottom = 12
      ParentBackground = False
      TabOrder = 0
      object ReleaseNameText: TStaticText
        AlignWithMargins = True
        Left = 14
        Top = 12
        Width = 396
        Height = 20
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 6
        Align = alTop
        AutoSize = False
        Caption = 'Release:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 3158064
        Font.Height = -13
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
        TabStop = False
      end
      object VersionText: TStaticText
        AlignWithMargins = True
        Left = 14
        Top = 38
        Width = 396
        Height = 28
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alTop
        AutoSize = False
        Caption = 'Current:'#13#10'Latest:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 5526357
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabStop = False
      end
    end
    object DetailText: TStaticText
      AlignWithMargins = True
      Left = 8
      Top = 160
      Width = 424
      Height = 26
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alTop
      AutoSize = False
      Caption = 'Want me to open GitHub so we can take a look?'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 5526357
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabStop = False
    end
    object PromptText: TStaticText
      AlignWithMargins = True
      Left = 8
      Top = 94
      Width = 424
      Height = 58
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 8
      Align = alTop
      AutoSize = False
      Caption = 'Good news: there is a newer Agent Skill Search release waiting for us.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 5526357
      Font.Height = -15
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabStop = False
    end
    object TitleText: TStaticText
      AlignWithMargins = True
      Left = 8
      Top = 30
      Width = 424
      Height = 56
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 8
      Align = alTop
      AutoSize = False
      Caption = 'A fresh build just landed.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -29
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      TabStop = False
    end
    object EyebrowText: TStaticText
      AlignWithMargins = True
      Left = 8
      Top = 8
      Width = 424
      Height = 14
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 8
      Align = alTop
      AutoSize = False
      Caption = 'UPDATE AVAILABLE'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 13134377
      Font.Height = -11
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      TabStop = False
    end
  end
end
