unit UnitMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Gauges, Buttons, IniFiles, StdCtrls, OleCtrls, SHDocVw, ExtCtrls,
  Wininet, ImgBtn, ComCtrls, ShlObj, ComObj, ActiveX, jpeg;


type
  TFMain = class(TForm)
    Gauge1: TGauge;
    Gauge2: TGauge;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    ImgBtn1: TImgBtn;
    ImgBtn2: TImgBtn;
    ImgBtn3: TImgBtn;
    ImgBtn4: TImgBtn;
    Panel1: TPanel;
    WebBrowser1: TWebBrowser;
    Image2: TImage;
    Image3: TImage;
    Image4: TImage;
    Label4: TLabel;
    ImgBtn5: TImgBtn;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ImgBtn4Click(Sender: TObject);
    procedure ImgBtn3Click(Sender: TObject);
    procedure ImgBtn2Click(Sender: TObject);
    procedure ImgBtn1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ImgBtn5Click(Sender: TObject);
    procedure WebBrowser1NavigateComplete2(Sender: TObject;
      const pDisp: IDispatch; var URL: OleVariant);
    procedure Timer1Timer(Sender: TObject);
    procedure UpdateRevision(Rev: string);
  private
    { Private declarations }
  public
  Draging: Boolean;
  X0, Y0: integer;
  end;

var
  FMain: TFMain;
  USettings : TStrings;
  
implementation

uses Frm2, GetFilesThr, Misc;

{$R *.dfm}

procedure TFmain.UpdateRevision(Rev: string);
var
  Settings: TInifile;
begin
  Settings := TInifile.Create(USettings[0]+'_settings.ini');
  Settings.WriteString('main','AtRevision',Rev);
  Settings.Free;
end;


function LoadSettings(): bool;
var
  Settings: TInifile;
begin
  Result:=False;
  USettings := TStringlist.Create;
  USettings.Add(GetCurrentDir+'\');
  if(FileExists(USettings[0]+'_settings.ini')) then
  begin
    Settings := TInifile.Create(USettings[0]+'_settings.ini');
    USettings.Add(Settings.ReadString('main','NewsUrl',''));
    USettings.Add(Settings.ReadString('main','UpdatesUrl',''));
    USettings.Add(Settings.ReadString('main','LinkName','Lineage II'));
    USettings.Add(Settings.ReadString('main','Installed','0'));
    USettings.Add(Settings.ReadString('main','CreateBackup','0'));
    USettings.Add(Settings.ReadString('main','AtRevision','0'));
    USettings.Add(Settings.ReadString('main','RunCustom','system\l2.exe'));
    Settings.Free;
    Result:=True;
  end
end;

// создает ярлык на себя на рабочем столе
procedure CreateDesktopIcon(ilname, WorkDir, desc : string);
var
  IObj : IUnknown;
  SLink : IShellLink;
  PFile : IPersistFile;
  desk : string;
  lnkpath : WideString;
begin
  if(ilname<>'') then begin
  SetLength(desk, MAX_PATH+1);
  SHGetSpecialFolderPath(0, PAnsiChar(desk),CSIDL_DESKTOPDIRECTORY,False);
  lnkpath:= PChar(desk)+'\'+ilname+'.lnk';
  IObj := CreateComObject(CLSID_ShellLink);
  SLink := IObj as IShellLink;
  PFile := IObj as IPersistFile;
  with SLink do
  begin
    SetDescription(PChar(desc));
    SetPath(PChar(Application.ExeName));
    SetWorkingDirectory(PAnsiChar(WorkDir));
  end;
  PFile.Save(PWChar(WideString(lnkpath)), FALSE);
  end;
end;




procedure TFMain.FormCreate(Sender: TObject);
var
  regn, tmpRegn, x, y: integer;
  nullClr: TColor;
  s_load: bool;
  Settings: TInifile;
begin
  s_load:=LoadSettings();
  if (s_load) then
  begin
    if (USettings[4]='0') then
    begin
      Settings := TInifile.Create(USettings[0]+'_settings.ini');
      Settings.WriteString('main','Installed','1');
      Settings.Free;
      CreateDesktopIcon(USettings[3],USettings[0],'Play Lineage II');
    end;
  end
  else
  begin
    FMain.Timer1.Enabled:=False;
    ShowMessage('ERROR: _settings.ini Not Found !');
    Application.Terminate; // .close здесь не пройдет 
  end;

  // Наводим красивость на форму ...
  FMain.brush.bitmap:=Image1.picture.bitmap;
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
  SetWindowRgn(FMain.handle, regn, true);
end;

procedure TFMain.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Draging := true;
  x0 := x;
  y0 := y;
end;

procedure TFMain.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Draging := false;
end;

procedure TFMain.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if Draging = true then
  begin
    FMain.Left := FMain.Left + X - X0;
    FMain.top := FMain.top + Y - Y0;
  end;
end;

procedure TFMain.ImgBtn4Click(Sender: TObject);
begin
  FMain.Close;
end;

procedure TFMain.ImgBtn3Click(Sender: TObject);
begin
  FMain.Close;
end;

procedure TFMain.ImgBtn2Click(Sender: TObject);
var
  WThread : GFilesThread;
begin
  Label3.Caption:='';
  WThread:=GFilesThread.Create(True);
  WThread.FreeOnTerminate:=True;
  WThread.UpdatesUrl:=USettings[2];
  WThread.ForceCheck:=True;
  WThread.CreateBackup:=StrToInt(USettings[5]);
  WThread.LocalRevision:=StrToInt(USettings[6]);
  WThread.Resume;
end;

procedure TFMain.ImgBtn1Click(Sender: TObject);
begin
  RunApp(USettings[0]+Usettings[7]);
  FMain.Close;
end;

procedure TFMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
 USettings.Free;
end;

procedure TFMain.ImgBtn5Click(Sender: TObject);
begin
 FMain.Enabled:=False;
 Form1.Show;
end;

procedure TFMain.WebBrowser1NavigateComplete2(Sender: TObject;
  const pDisp: IDispatch; var URL: OleVariant);
begin
 FMain.Panel1.Visible:=True;
 FMain.Image2.Visible:=True;
 FMain.Image3.Visible:=True;
 FMain.Image4.Visible:=True;
end;

procedure TFMain.Timer1Timer(Sender: TObject);
var
  WThread : GFilesThread;
begin
  FMain.Timer1.Enabled:=False;
  WebBrowser1.Navigate(USettings[1]);
  Label3.Caption:='';
  WThread:=GFilesThread.Create(True);
  WThread.FreeOnTerminate:=True;
  WThread.UpdatesUrl:=USettings[2];
  WThread.ForceCheck:=False;
  WThread.CreateBackup:=StrToInt(USettings[5]);
  WThread.LocalRevision:=StrToInt(USettings[6]);
  WThread.Resume;
end;

end.
