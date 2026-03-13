object ConfigDlg: TConfigDlg
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 194
  ClientWidth = 412
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 17
  object PnlButtons: TPanel
    Left = 0
    Top = 157
    Width = 412
    Height = 37
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object BtnOK: TButton
      Left = 244
      Top = 6
      Width = 76
      Height = 25
      Anchors = [akTop, akRight]
      Caption = '&OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object BtnCancel: TButton
      Left = 328
      Top = 6
      Width = 76
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = '&Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object GrpBehaviour: TGroupBox
    AlignWithMargins = True
    Left = 8
    Top = 8
    Width = 396
    Height = 141
    Margins.Left = 8
    Margins.Top = 8
    Margins.Right = 8
    Margins.Bottom = 8
    Align = alClient
    Caption = 'Application behaviour'
    TabOrder = 0
    object ChkCloseToTray: TCheckBox
      AlignWithMargins = True
      Left = 14
      Top = 24
      Width = 368
      Height = 20
      Margins.Left = 6
      Margins.Top = 8
      Margins.Right = 6
      Margins.Bottom = 4
      Align = alTop
      Caption = 'Minimize to system tray when closing instead of exiting'
      TabOrder = 0
    end
  end
end
