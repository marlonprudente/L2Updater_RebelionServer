program L2Updater;

uses
  Forms,
  UnitMain in 'UnitMain.pas' {FMain},
  Frm2 in 'Frm2.pas' {Form1},
  Misc in 'Misc.pas',
  GetFilesThr in 'GetFilesThr.pas',
  BZip2 in 'BZip2.pas',
  md5 in 'md5.pas',
  LstFile in 'LstFile.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'L2Updater';
  Application.CreateForm(TFMain, FMain);
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
