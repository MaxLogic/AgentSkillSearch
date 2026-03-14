object ConfigDlg: TConfigDlg
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 276
  ClientWidth = 456
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 17
  object PnlButtons: TPanel
    Left = 0
    Top = 220
    Width = 456
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
    object BtnOK: TBitBtn
      AlignWithMargins = True
      Left = 246
      Top = 10
      Width = 90
      Height = 36
      Margins.Top = 0
      Margins.Right = 8
      Margins.Bottom = 0
      Align = alRight
      Caption = '&OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object BtnCancel: TBitBtn
      AlignWithMargins = True
      Left = 344
      Top = 10
      Width = 96
      Height = 36
      Margins.Top = 0
      Margins.Bottom = 0
      Align = alRight
      Cancel = True
      Caption = '&Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object GrpBehaviour: TPanel
    AlignWithMargins = True
    Left = 16
    Top = 16
    Width = 424
    Height = 188
    Margins.Left = 16
    Margins.Top = 16
    Margins.Right = 16
    Margins.Bottom = 16
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clWhite
    Padding.Bottom = 8
    ParentBackground = False
    TabOrder = 1
    object ChkSearchAsYouType: TCheckBox
      AlignWithMargins = True
      Left = 0
      Top = 101
      Width = 424
      Height = 20
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 12
      Align = alTop
      Caption = 'Run search automatically while we type'
      TabOrder = 3
    end
    object BtnEditSources: TBitBtn
      AlignWithMargins = True
      Left = 0
      Top = 133
      Width = 424
      Height = 36
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alTop
      Caption = 'Edit Sources...'
      Hint = 'Sources|Open the source-folder editor used by Scan and Update.|0'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 4
      OnClick = HandleEditSourcesClick
    end
    object ChkCloseToTray: TCheckBox
      AlignWithMargins = True
      Left = 0
      Top = 69
      Width = 424
      Height = 20
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 12
      Align = alTop
      Caption = 'Minimize to system tray when closing instead of exiting'
      TabOrder = 2
    end
    object LblSection: TStaticText
      AlignWithMargins = True
      Left = 0
      Top = 36
      Width = 424
      Height = 17
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 16
      Align = alTop
      AutoSize = False
      Caption = 'Behavior'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 4473924
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabStop = False
    end
    object LblTitle: TStaticText
      AlignWithMargins = True
      Left = 0
      Top = 0
      Width = 424
      Height = 28
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 8
      Align = alTop
      AutoSize = False
      Caption = 'Settings'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabStop = False
    end
  end
  object BalloonHint: TBalloonHint
    Left = 400
    Top = 16
  end
end
