object SourcesEditorForm: TSourcesEditorForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSizeable
  Caption = 'Edit Sources'
  ClientHeight = 560
  ClientWidth = 840
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 17
  object fActionsPanel: TPanel
    Left = 0
    Top = 504
    Width = 840
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    Caption = ''
    Color = 16119285
    ParentBackground = False
    Padding.Left = 16
    Padding.Top = 10
    Padding.Right = 16
    Padding.Bottom = 10
    TabOrder = 1
    object fCancelButton: TBitBtn
      AlignWithMargins = True
      Left = 719
      Top = 10
      Width = 105
      Height = 36
      Margins.Top = 0
      Margins.Bottom = 0
      Align = alRight
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
    object fSaveButton: TBitBtn
      AlignWithMargins = True
      Left = 606
      Top = 10
      Width = 105
      Height = 36
      Margins.Right = 8
      Margins.Top = 0
      Margins.Bottom = 0
      Align = alRight
      Caption = 'Save'
      Default = True
      TabOrder = 0
      OnClick = HandleSaveButtonClick
    end
  end
  object fContentPanel: TPanel
    Left = 0
    Top = 0
    Width = 840
    Height = 504
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clWhite
    ParentBackground = False
    Padding.Left = 16
    Padding.Top = 16
    Padding.Right = 16
    Padding.Bottom = 16
    TabOrder = 0
    object fPathsPanel: TPanel
      AlignWithMargins = True
      Left = 16
      Top = 140
      Width = 808
      Height = 348
      Align = alClient
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 3
      object fPathsListBox: TListBox
        Left = 0
        Top = 17
        Width = 808
        Height = 287
        Align = alClient
        ItemHeight = 17
        TabOrder = 0
        OnClick = HandlePathsListBoxClick
      end
      object fPathsListLabel: TStaticText
        Left = 0
        Top = 0
        Width = 808
        Height = 17
        Align = alTop
        AutoSize = False
        BorderStyle = sbsNone
        Caption = 'Configured source paths'
        TabStop = False
      end
      object fListToolsPanel: TPanel
        Left = 0
        Top = 304
        Width = 808
        Height = 44
        Align = alBottom
        BevelOuter = bvNone
        Caption = ''
        TabOrder = 1
        object fRemoveButton: TBitBtn
          AlignWithMargins = True
          Left = 654
          Top = 4
          Width = 151
          Height = 36
          Margins.Top = 4
          Margins.Right = 0
          Margins.Bottom = 4
          Align = alRight
          Caption = 'Remove Selected'
          TabOrder = 0
          OnClick = HandleRemoveButtonClick
        end
      end
    end
    object fInlineMessageLabel: TStaticText
      AlignWithMargins = True
      Left = 16
      Top = 110
      Width = 808
      Height = 18
      Margins.Top = 0
      Margins.Bottom = 4
      Align = alTop
      AutoSize = False
      BorderStyle = sbsNone
      Caption = ''
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabStop = False
    end
    object fEntryPanel: TPanel
      AlignWithMargins = True
      Left = 16
      Top = 52
      Width = 808
      Height = 56
      Margins.Bottom = 4
      Align = alTop
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 2
      object fPathRowPanel: TPanel
        Left = 0
        Top = 20
        Width = 808
        Height = 36
        Align = alBottom
        BevelOuter = bvNone
        Caption = ''
        TabOrder = 0
        object fPathEditHostPanel: TPanel
          Left = 0
          Top = 0
          Width = 578
          Height = 36
          Align = alClient
          BevelOuter = bvNone
          Caption = ''
          TabOrder = 0
          object fPathEdit: TEdit
            AlignWithMargins = True
            Left = 0
            Top = 0
            Width = 570
            Height = 25
            Margins.Left = 0
            Margins.Top = 0
            Margins.Right = 8
            Margins.Bottom = 0
            Align = alTop
            TabOrder = 0
            TextHint = 'C:\projects\MaxLogic'
            OnChange = HandlePathEditChange
          end
        end
        object fPathButtonsPanel: TPanel
          Left = 578
          Top = 0
          Width = 230
          Height = 36
          Align = alRight
          BevelOuter = bvNone
          Caption = ''
          TabOrder = 1
          object fAddButton: TBitBtn
            AlignWithMargins = True
            Left = 126
            Top = 0
            Width = 104
            Height = 36
            Margins.Left = 8
            Margins.Top = 0
            Margins.Bottom = 0
            Align = alRight
            Caption = 'Add'
            TabOrder = 1
            OnClick = HandleAddButtonClick
          end
          object fBrowseButton: TBitBtn
            AlignWithMargins = True
            Left = 0
            Top = 0
            Width = 118
            Height = 36
            Margins.Top = 0
            Margins.Bottom = 0
            Align = alClient
            Caption = 'Browse...'
            TabOrder = 0
            OnClick = HandleBrowseButtonClick
          end
        end
      end
      object fPathLabel: TStaticText
        Left = 0
        Top = 0
        Width = 808
        Height = 17
        Align = alTop
        AutoSize = False
        BorderStyle = sbsNone
        Caption = 'Add source path'
        TabStop = False
      end
    end
    object fHeaderLabel: TStaticText
      AlignWithMargins = True
      Left = 16
      Top = 16
      Width = 808
      Height = 32
      Margins.Bottom = 8
      Align = alTop
      AutoSize = False
      BorderStyle = sbsNone
      Caption = 'Edit Sources'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabStop = False
    end
  end
end
