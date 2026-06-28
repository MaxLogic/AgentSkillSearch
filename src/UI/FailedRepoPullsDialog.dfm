object FailedRepoPullsDialog: TFailedRepoPullsDialog
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSizeable
  Caption = 'Resolve Failed Pulls'
  ClientHeight = 620
  ClientWidth = 860
  Color = clWindow
  Constraints.MinHeight = 520
  Constraints.MinWidth = 720
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 17
  object FooterPanel: TPanel
    Left = 0
    Top = 564
    Width = 860
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    Padding.Left = 16
    Padding.Top = 10
    Padding.Right = 16
    Padding.Bottom = 10
    ParentBackground = False
    TabOrder = 2
    object BtnClose: TBitBtn
      AlignWithMargins = True
      Left = 744
      Top = 10
      Width = 100
      Height = 36
      Margins.Left = 8
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alRight
      Cancel = True
      Caption = 'Close'
      Default = True
      TabOrder = 0
      OnClick = HandleCloseClick
    end
  end
  object HeaderPanel: TPanel
    Left = 0
    Top = 0
    Width = 860
    Height = 92
    Align = alTop
    BevelOuter = bvNone
    Color = clWindow
    Padding.Left = 16
    Padding.Top = 16
    Padding.Right = 16
    Padding.Bottom = 8
    ParentBackground = False
    TabOrder = 0
    object SummaryText: TStaticText
      AlignWithMargins = True
      Left = 16
      Top = 53
      Width = 828
      Height = 20
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alTop
      AutoSize = False
      Caption = '0 failed repo pull(s).'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabStop = False
    end
    object TitleText: TStaticText
      AlignWithMargins = True
      Left = 16
      Top = 16
      Width = 828
      Height = 29
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 8
      Align = alTop
      AutoSize = False
      Caption = 'Resolve failed repo pulls'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabStop = False
    end
  end
  object ContentPanel: TPanel
    Left = 0
    Top = 92
    Width = 860
    Height = 472
    Align = alClient
    BevelOuter = bvNone
    Color = clWindow
    Padding.Left = 16
    Padding.Right = 16
    Padding.Bottom = 8
    ParentBackground = False
    TabOrder = 1
    object StatusText: TStaticText
      AlignWithMargins = True
      Left = 16
      Top = 444
      Width = 828
      Height = 20
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alBottom
      AutoSize = False
      Caption = ''
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabStop = False
    end
    object RepoScrollBox: TScrollBox
      Left = 16
      Top = 0
      Width = 828
      Height = 436
      Align = alClient
      BorderStyle = bsNone
      TabOrder = 0
      object RepoHostPanel: TPanel
        Left = 0
        Top = 0
        Width = 811
        Height = 1
        Align = alTop
        BevelOuter = bvNone
        Caption = ''
        Color = clWindow
        ParentBackground = False
        TabOrder = 0
      end
    end
  end
end
