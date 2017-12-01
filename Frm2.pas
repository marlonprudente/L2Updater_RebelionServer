unit Frm2;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, IniFiles;

type
  TForm1 = class(TForm)
    ComboBox1: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    ComboBox2: TComboBox;
    Label3: TLabel;
    ComboBox3: TComboBox;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    ComboBox4: TComboBox;
    Label4: TLabel;
    Image1: TImage;
    CheckBox3: TCheckBox;
    Label5: TLabel;
    Label6: TLabel;
    procedure SpeedButton2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure SpeedButton1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  Draging: Boolean;
  X0, Y0: integer;
  end;

var
  Form1: TForm1;
  option:TIniFile;
implementation

uses UnitMain;

{$R *.dfm}

procedure TForm1.SpeedButton2Click(Sender: TObject);
begin
Form1.Hide;
FMain.Enabled:= True;
end;

procedure GetGameSettings;
var
Res, x,y :cardinal;
begin
Option:=TInifile.Create(GetCurrentDir+'\system\option.ini');
x := Option.ReadInteger('Video','GamePlayViewportX',0);
y := Option.ReadInteger('Video','GamePlayViewportY',0);
Res := X + Y;
case Res of
   1120 : Form1.ComboBox1.ItemIndex:=0;
   1400 : Form1.ComboBox1.ItemIndex:=1;
   1792 : Form1.ComboBox1.ItemIndex:=2;
   2240 : Form1.ComboBox1.ItemIndex:=3;
   2304 : Form1.ComboBox1.ItemIndex:=4;
end;
case Option.ReadInteger('Video','ColorBits',0) of
   32 : Form1.ComboBox2.ItemIndex:=0;
   16 : Form1.ComboBox2.ItemIndex:=1;
end;
case Option.ReadInteger('Video','RefreshRate',0) of
   60  : Form1.ComboBox3.ItemIndex:=0;
   75  : Form1.ComboBox3.ItemIndex:=1;
   85  : Form1.ComboBox3.ItemIndex:=2;
   100 : Form1.ComboBox3.ItemIndex:=3;
end;
Form1.CheckBox1.Checked:=StrToBool(Option.ReadString('Video','IsKeepMinFrameRate','true'));
Form1.CheckBox2.Checked:=StrToBool(Option.ReadString('Video','StartupFullScreen','false'));
Form1.ComboBox4.ItemIndex:=Option.ReadInteger('Game','PartyLooting',0);
Option.Free;
if USettings[5] = '1' then Form1.CheckBox3.Checked:=True;
end;

procedure SaveGameSettings;
var
RR,X,Y:String;
Settings: TIniFile;
begin
Option:=TInifile.Create(GetCurrentDir+'\system\option.ini');
  case Form1.ComboBox1.ItemIndex of
    0 : begin x:='640'; y:='480'; end;
    1 : begin x:='800'; y:='600'; end;
    2 : begin x:='1024'; y:='768'; end;
    3 : begin x:='1280'; y:='960'; end;
    4 : begin x:='1280'; y:='1024'; end;
  end;
  case Form1.ComboBox3.ItemIndex of
    0 : RR:= '60';
    1 : RR:= '75';
    2 : RR:= '85';
    3 : RR:= '100';
  end;
Option.WriteString('Video','GamePlayViewportX',X);
Option.WriteString('Video','GamePlayViewportY',Y);
if(Form1.ComboBox2.ItemIndex=0) then
    Option.WriteInteger('Video','ColorBits',32)
else
   Option.WriteInteger('Video','ColorBits',16);
Option.WriteString('Video','RefreshRate',RR);
if(Form1.CheckBox1.Checked) then
   Option.WriteString('Video','IsKeepMinFrameRate','true')
else
   Option.WriteString('Video','IsKeepMinFrameRate','false');
if(Form1.CheckBox2.Checked) then
   Option.WriteString('Video','StartupFullScreen','true')
else
   Option.WriteString('Video','StartupFullScreen','false');
Option.WriteInteger('Game','PartyLooting',Form1.ComboBox4.ItemIndex);
Option.Free;

if (Form1.CheckBox3.Checked) then USettings[5]:='1'
else USettings[5]:='0';

  Settings := TInifile.Create(USettings[0]+'_settings.ini');
  Settings.WriteString('main','CreateBackup',USettings[5]);
  Settings.Free;

end;

procedure TForm1.FormCreate(Sender: TObject);
var
  regn, tmpRegn, x, y: integer;
  nullClr: TColor;
begin
Form1.brush.bitmap:=image1.picture.bitmap;
  nullClr := image1.picture.Bitmap.Canvas.Pixels[0, 0];
  regn := CreateRectRgn(0, 0, image1.picture.Graphic.Width,
    image1.picture.Graphic.Height);
  for x := 1 to image1.picture.Graphic.Width do
    for y := 1 to image1.picture.Graphic.Height do
      if image1.picture.Bitmap.Canvas.Pixels[x - 1, y - 1] = nullClr then
      begin
        tmpRegn := CreateRectRgn(x - 1, y - 1, x, y);
        CombineRgn(regn, regn, tmpRegn, RGN_DIFF);
        DeleteObject(tmpRegn);
      end;
  SetWindowRgn(Form1.handle, regn, true);
  GetGameSettings;
end;

procedure TForm1.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if Draging = true then
  begin
    Form1.Left := Form1.Left + X - X0;
    Form1.top := Form1.top + Y - Y0;
  end;
end;

procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Draging := true;
  x0 := x;
  y0 := y;
end;

procedure TForm1.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Draging := false;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
if(FileExists(GetCurrentDir+'\system\option.ini')) then
  SaveGameSettings;
Form1.Hide;
FMain.Enabled:= True;
end;

end.
