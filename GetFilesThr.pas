unit GetFilesThr;

interface

uses
  Classes, Wininet, Windows, SysUtils, Dialogs, Forms;

type
  GFilesThread = class(TThread)
  private
    LTemp : Longword;             // Временная переменная ... точнее так , переменная для временных данных
    STemp : string;               // ---//--- cтроковая
    FilesToGet : TStringList;     // Это будем качать
    FilesSize : Longword;         // Общий размер загружаемых файлов
    CBackup : integer;            // Флаг необходимости бэкапа
    CRevision : integer;          // Текущая ревизия
    CForceCheck : boolean;        // Флаг Принудительной проверки [ Если нажали на фулл чек или при различии ревизий ]
    CSwitch : integer;            // Бестолковый флаг , используется в ф-ии обновления прогресса
    UUrl : string;                // URL каталога с апдейтами
    USelfParam : string;          // Параметры клиента автообновления, используется в ф-ии самообновления
    Dir: string;                  // "Домашняя" папка [ текущий рабочий каталог клиента ]
    FSource: TStream;             // используется архиватором
  protected
    procedure Execute; override;
    procedure UpdateFileProgress;
    procedure SetFileProgressMax;
    procedure UpdateStatusLabel;
    procedure UpdateFileDecompStat;
    procedure UpdateFilesProgress;
    procedure CheckFiles(FList : TStringList);
    procedure BZProgress(Sender: TObject);
    procedure LockFMain;
    procedure UNLockFMain;
    procedure GetFiles;
    procedure SelfUpdate(SelfVal : string);
    procedure UpdateRevision;
    procedure ModHosts(Lines : TStringList);
    procedure DoUncompressStream(ASource, ADest: TStream);
    procedure DoUncompress(const ASource, ADest: TFileName);
    function HTTPGetFile(const fileURL, FileName: string; sh_progress: boolean): boolean;
  public
    property CreateBackup : integer write CBackup;
    property UpdatesUrl : string write UUrl;
    property LocalRevision : integer write CRevision;
    property ForceCheck : boolean write CForceCheck;
  end;

implementation
uses UnitMain, Misc, BZip2, md5, LstFile;

// ---------------- Ужос [ ниже - ф-ии для обновления основной формы ]

procedure GFilesThread.UpdateStatusLabel;
begin
  FMain.Label3.Caption:=STemp;
end;

procedure GFilesThread.SetFileProgressMax;
begin
  if(CSwitch=0) then
    FMain.Gauge1.MaxValue:=LTemp;
  if(CSwitch=1) then
    FMain.Gauge2.MaxValue:=LTemp;
end;

procedure GFilesThread.UpdateFileProgress;
begin
  FMain.Gauge1.Progress:=LTemp;
end;

procedure GFilesThread.UpdateFilesProgress;
begin
  FMain.Gauge2.Progress:=LTemp;
end;

procedure GFilesThread.UpdateRevision;
begin
  FMain.UpdateRevision(IntToStr(CRevision));
end;

procedure GFilesThread.UpdateFileDecompStat;
begin
  FMain.Gauge1.Progress:=LTemp;
end;

procedure GFilesThread.BZProgress(Sender: TObject);
begin
  LTemp:=FSource.Position;
  Synchronize(UpdateFileDecompStat);
end;

procedure GFilesThread.LockFMain;
begin
  Fmain.ImgBtn1.Visible:=False;
  Fmain.ImgBtn2.Visible:=False;
  Fmain.ImgBtn5.Enabled:=False;
end;

procedure GFilesThread.UNLockFMain;
begin
  Fmain.ImgBtn1.Visible:=True;
  Fmain.ImgBtn2.Visible:=True;
  Fmain.ImgBtn5.Enabled:=True;
end;

// ---------------- конец ужоса

function GFilesThread.HTTPGetFile(const fileURL, FileName: string; sh_progress: boolean): boolean;
const
  BufferSize = 1024;
var
  hSession, hURL: HInternet;
  Buffer: array[1..BufferSize] of Byte;
  BufferLen: Longword;
  f: file;
  sAppName: string;
begin
  Result := False;
  sAppName := 'L2ClientUpdater';
  LTemp:=0;
  hSession := InternetOpen(PChar(sAppName),
  INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  try
    hURL := InternetOpenURL(hSession, PChar(fileURL), nil, 0, 0, 0);
    if (hURL <> nil) then  begin
    try
      DeleteUrlCacheEntry(PChar(fileURL));
      AssignFile(f, FileName);
      Rewrite(f,1);
      repeat
        InternetReadFile(hURL, @Buffer, SizeOf(Buffer), BufferLen);
        BlockWrite(f, Buffer, BufferLen);
        if (sh_progress) then
        begin
          LTemp:=LTemp+BufferLen;
          Synchronize(UpdateFileProgress);
        end;
      until
        BufferLen = 0;
      CloseFile(f);
      Result := True;
    finally
      InternetCloseHandle(hURL);
    end;
  end;
  finally
    InternetCloseHandle(hSession);
  end;
  LTemp:=0;
  Synchronize(UpdateFileProgress);
end;

procedure GFilesThread.DoUncompress(const ASource, ADest: TFileName);
var
  Source, Dest: TStream;
begin
  Source := TFileStream.Create(ASource, fmOpenRead + fmShareDenyWrite);
  try
    Dest := TFileStream.Create(ADest, fmCreate);
    try
      DoUncompressStream(Source, Dest);
    finally
      Dest.Free;
    end;
  finally
    Source.Free;
    DeleteFile(ASource);
  end;
end;

procedure GFilesThread.DoUncompressStream(ASource, ADest: TStream);
const
  BufferSize = 65536;
var
  Count: Integer;
  Decomp: TBZDecompressionStream;
  Buffer: array[0..BufferSize - 1] of Byte;
begin
  FSource := ASource;
  LTemp:=FSource.Size;
  CSwitch:=0;
  Synchronize(SetFileProgressMax);
  Decomp := TBZDecompressionStream.Create(ASource);
  try
    Decomp.OnProgress := BZProgress;
    while True do
    begin
      Count := Decomp.Read(Buffer, BufferSize);
      if Count <> 0 then ADest.WriteBuffer(Buffer, Count) else Break;
    end;
  finally
    Decomp.Free;
    FSource := nil;
    LTemp:=0;
    Synchronize(UpdateFileDecompStat);
  end;
end;


procedure GFilesThread.CheckFiles(FList : TStringList);
var
  i: integer;
  FParam: TStringList;
  FNameLocal: string;
begin
  if(FList.Count>0) and (FList[0]<>'FAIL') and (not terminated) then
  begin
    STemp:='Checking files';
    Synchronize(UpdateStatusLabel);
    CSwitch:=1;
    LTemp:=FList.Count-1;
    Synchronize(SetFileProgressMax);
    FParam:=TStringList.Create;
    for i:=0 to FList.Count-1 do
    begin
      LTemp:=i;
      Synchronize(UpdateFilesProgress);
      FParam:=Tokenize(FList[i],'|');
      FNameLocal:=Dir+FParam[2];
      STemp:='Checking '+FParam[2];
      Synchronize(UpdateStatusLabel);
      if (not FileExists(FNameLocal)) then
      begin
        FilesToGet.Add(FList[i]);
        FilesSize:=FilesSize+StrToInt(FParam[0]);
      end
      else
      begin
        if (MD5Print(MD5File(FNameLocal))<>FParam[1]) then
        begin
          FilesToGet.Add(FList[i]);
          FilesSize:=FilesSize+StrToInt(FParam[0]);
        end;
      end;
    end;
    FParam.Free;
    LTemp:=0;
    Synchronize(UpdateFilesProgress);
    STemp:='';
    Synchronize(UpdateStatusLabel);
  end;
end;

procedure GFilesThread.SelfUpdate(SelfVal : string);
var
  FParam: TStringList;
  FNameLocal: string;
  F:boolean;
begin
  if(SelfVal<>'') then
  begin
    FParam:=TStringList.Create;
    FParam:=Tokenize(SelfVal,'|');
      FNameLocal:=Dir+FParam[2];
      if (MD5Print(MD5File(FNameLocal))<>FParam[1]) then
      begin
        FilesSize:=FilesSize+StrToInt(FParam[0]);
        F:=HTTPGetFile(UUrl+FParam[2]+'.bz2',FNameLocal+'.bz2',True);
        if(F) then begin
          try
           DoUncompress(FNameLocal+'.bz2',Dir+FParam[2]+'.New');
           GenKillerBat(FParam[2]);
           RunApp(Dir+'Update.bat');
          except
            STemp:='Update Failed';
            DeleteFile(FNameLocal);
          end;
        end;
      end;
    FParam.Free;
  end;
end;

procedure GFilesThread.ModHosts(Lines : TStringList);
var
 Hosts : textfile;
 H, HostsStrings, HostLineParam : TStringList;
 HostsPath, temp : string;
 i, z, funnyFlag : integer;
 WindirP : PChar;
 Res : cardinal;
begin
  WinDirP := StrAlloc(MAX_PATH);
  Res := GetWindowsDirectory(WinDirP, MAX_PATH);
  if Res > 0 then
  begin
    // если в системе установлен MSN , хосты в hosts.msn
    if(FileExists(StrPas(WinDirP)+'\system32\drivers\etc\hosts.msn')) then
      HostsPath := StrPas(WinDirP)+'\system32\drivers\etc\hosts.msn'
    else
      HostsPath := StrPas(WinDirP)+'\system32\drivers\etc\hosts';
    AssignFile(Hosts,HostsPath);
    Reset(Hosts);
    HostsStrings:= TStringList.Create;
    H:= TStringList.Create;
    H.Add('#-------- Added by L2Updater --------');
    // читаем хост в строковый массив\список
    while (not Eof(Hosts)) do
    begin
      ReadLn(Hosts, temp);
      HostsStrings.Add(Trim(temp));
    end ;
    Reset(Hosts);
    for i:=0 to Lines.Count-1 do
    begin
      funnyFlag:=0;
      HostLineParam:=Tokenize(Lines[i],'|');
      for z:=0 to HostsStrings.Count-1 do
      begin
       if (StrSearch(1,HostsStrings[z],HostLineParam[0])>0) and (HostsStrings[z][1]<>'#') then
       begin
          if (StrSearch(1,HostsStrings[z],HostLineParam[1]+#9)= 0) and (StrSearch(1,HostsStrings[z],HostLineParam[1]+' ')= 0 ) then
          begin
           HostsStrings[z]:= '#'+HostsStrings[z];
           funnyFlag:=1;
          end
          else funnyFlag:=2;
       end;
      end;
      if (funnyFlag=1) or (funnyFlag=0)  then
        H.Add(HostLineParam[1]+#9+HostLineParam[0]);
    end;
    H.Add('#-----------------');
    if H.Count>2 then
    begin
      Rewrite(Hosts);
      STemp:='Applying changes to Hosts';
      Synchronize(UpdateStatusLabel);
      for i:=0 to HostsStrings.Count-1 do
      begin
        WriteLn(Hosts,HostsStrings[i]);
      end;

      for i:=0 to H.Count-1 do
      begin
       WriteLn(Hosts,H[i]);
      end;
      STemp:='Hosts file chamged';
      Synchronize(UpdateStatusLabel);
    end;
      H.Free; HostsStrings.Free; HostLineParam.Free;
  CloseFile(Hosts);
  end;
end;

procedure GFilesThread.GetFiles;
var
  FParam : TStringList;
  i : integer;
  F,  error : boolean;
  LocalFile, BakFile: string;
begin
  error := False;
  if (FilesToGet.Count>0) then
  begin
    FParam:=TStringList.Create;
    LTemp:=FilesToGet.Count-1;
    CSwitch:=1;
    Synchronize(SetFileProgressMax);
    i:=0;
    while (i < FilesToGet.Count) and (not terminated) do
    begin
      // Отображаем прогресс загрузки файлов
      FParam:=Tokenize(FilesToGet[i],'|');
      LocalFile:= Dir+FParam[2];
      STemp:='Downloading '+ FParam[2];
      Synchronize(UpdateStatusLabel);

      // Устанавливаем Макс. Значения для прогресса загрузки файла
      CSwitch:=0;
      LTemp:= StrToInt(FParam[0]);
      Synchronize(SetFileProgressMax);

      if (not DirectoryExists(ExtractFilePath(LocalFile))) then
        ForceDirectories(ExtractFilePath(LocalFile));
      F:=HTTPGetFile(UUrl+ReplaceStr(FParam[2],'\','/')+'.bz2',LocalFile+'.bz2',True);
      if (F) then
      begin
        try
          if (CBackup=1) then
          begin
            BakFile:=Dir+'backup\'+FParam[2];
            if (not DirectoryExists(ExtractFilePath(BakFile))) then
              ForceDirectories(ExtractFilePath(BakFile));
            CopyFile(PChar(LocalFile),PChar(BakFile),false);
          end;
          STemp:='Extracting '+ FParam[2];
          Synchronize(UpdateStatusLabel);
          DoUncompress(LocalFile+'.bz2',Dir+FParam[2]);
        except
          STemp:='Update Failed';
          error := True;
        end;
      end
      else
      begin
        STemp:='Update Failed';
        error := True;
        Break;
      end;
    inc(i);
    LTemp:=i;
    CSwitch:=1;
    Synchronize(UpdateFilesProgress);
  end;
  LTemp:=0;
  Synchronize(UpdateFilesProgress);
  FParam.Free;
  if (not error) then
    STemp:='All the files have been updated';
  end
  else STemp:='';
end;

procedure GFilesThread.Execute;
var
  List: TListFile;
  CFiles, NFiles, HostsLines : TStringList;
  TRev, IsModHosts : integer;
  F : boolean;
begin
  Dir:=GetCurrentDir+'\';
  FilesSize:=0;
  Synchronize(LockFMain);
  STemp:='Downloading updates list';
  Synchronize(UpdateStatusLabel);
  if(UUrl[length(UUrl)]<>'/') then UUrl:=UUrl+'/';
  F:=HTTPGetFile(UUrl+'files.lst.bz2',Dir+'files.lst.bz2', True);
  if (F) then
  begin
    STemp:='';
    Synchronize(UpdateStatusLabel);
    try
      DoUncompress(Dir+'files.lst.bz2',Dir+'files.lst');
    except
      STemp:='Update Failed';
      Synchronize(UpdateStatusLabel);
      DeleteFile(Dir+'files.lst');
    end;
    if(FileExists(Dir+'files.lst')) then
    begin
      FilesToGet := TStringList.Create;
      List := TListFile.Create(Dir+'files.lst');
      CFiles:=TStringList.Create;
      TRev:=StrToInt(List.GetKeyValue('settings','Rev'));
      IsModHosts:=StrToInt(List.GetKeyValue('settings','ModHosts'));
      if (IsModHosts = 1) then
      begin
        HostsLines:= TStringList.Create;
        HostsLines:= List.GetFSection('hosts');
        try
          ModHosts(HostsLines);
        finally
          HostsLines.Free;
        end;
      end;
      USelfParam:= List.GetFSection('self')[0];
      if(USelfParam<>'FAIL') then SelfUpdate(USelfParam); // сначала проверяем себя :)
      CFiles:=List.GetFSection('files_critical');
      CheckFiles(CFiles); // проверяем критические файлы
      CFiles.Free;
      if (CForceCheck) or (TRev>CRevision) then // если полная проверка или несоответствие ревизий, проверяем все файлы
      begin
        if (CBackup=1) then
        begin
          DelDir(Dir+'backup');
          MkDir(Dir+'backup');
        end;
        NFiles:=TStringList.Create;
        NFiles:=List.GetFSection('files_normal');
        CheckFiles(NFiles);
        NFiles.Free;
      end;
      GetFiles;
      List.Destroy;
      FilesToGet.Free;
      DeleteFile(Dir+'files.lst');
      if TRev>CRevision then
      begin
        CRevision:=TRev;
        Synchronize(UpdateRevision);
      end;
    end;
  end
  else
  begin
    STemp:='Update Failed';
    DeleteFile(Dir+'files.lst');
  end;
  Synchronize(UpdateStatusLabel);
  Synchronize(UNLockFMain);
end;

end.
