unit LuaWebsiteModules;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl, lua53, LuaStringsStorage, WebsiteModules, uData,
  uDownloadsManager, xquery, httpsendthread;

type

  TLuaWebsiteModulesContainer = class;

  { TLuaWebsiteModule }

  TLuaWebsiteModule = class
  private
  public
    Module: TModuleContainer;
    OnBeforeUpdateList: String;
    OnAfterUpdateList: String;
    OnGetDirectoryPageNumber: String;
    OnGetNameAndLink: String;
    OnGetInfo: String;
    OnTaskStart: String;
    OnGetPageNumber: String;
    OnGetImageURL: String;
    OnBeforeDownloadImage: String;
    OnDownloadImage: String;
    OnSaveImage: String;
    OnAfterImageSaved: String;
    OnLogin: String;
    Storage: TStringsStorage;
    LastUpdated: String;
    Container: TLuaWebsiteModulesContainer;
    constructor Create;
    destructor Destroy; override;

    procedure LuaPushMe(L: Plua_State);
    function LuaDoMe(L: Plua_State): Integer;
  end;

  TLuaWebsiteModules = specialize TFPGList<TLuaWebsiteModule>;

  { TLuaWebsiteModulesContainer }

  TLuaWebsiteModulesContainer = class
  public
    Modules: TLuaWebsiteModules;
    FileName: String;
    ByteCode: TMemoryStream;
    constructor Create;
    destructor Destroy; override;
  end;

  TLuaWebsiteModulesContainers = specialize TFPGList<TLuaWebsiteModulesContainer>;

  { TLuaWebsiteModulesManager }

  TLuaWebsiteModulesManager = class
  public
    Containers: TLuaWebsiteModulesContainers;
    TempModuleList: TLuaWebsiteModules;
    constructor Create;
    destructor Destroy; override;
  end;

procedure ScanLuaWebsiteModulesFile;

var
  LuaWebsiteModulesManager: TLuaWebsiteModulesManager;
  AlwaysLoadLuaFromFile: Boolean = {$ifdef DEVBUILD}True{$else}False{$endif};

implementation

uses
  FMDOptions, FileUtil, MultiLog, LuaClass, LuaBase, LuaMangaInfo, LuaHTTPSend,
  LuaXQuery, LuaUtils, LuaDownloadTask;

function DoBeforeUpdateList(const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnBeforeUpdateList) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoAfterUpdateList(const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnAfterUpdateList) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoGetDirectoryPageNumber(const MangaInfo: TMangaInformation;
  var Page: Integer; const WorkPtr: Integer; const Module: TModuleContainer): Integer;
var
  l: Plua_State;
begin
  Result := NO_ERROR;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushIntegerGlobal(l, 'page', Page);
      luaPushIntegerGlobal(l, 'workptr', WorkPtr);
      luaPushObject(l, MangaInfo.mangaInfo, 'mangainfo');
      luaPushObject(l, MangaInfo.FHTTP, 'http');

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnGetDirectoryPageNumber) then
      begin
        Result := lua_tointeger(l, -1);
        if lua_getglobal(l, 'page') <> 0 then
          Page := lua_tointeger(l, -1);
      end;
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoGetNameAndLink(const MangaInfo: TMangaInformation;
  const ANames, ALinks: TStringList; const AURL: String;
  const Module: TModuleContainer): Integer;
var
  l: Plua_State;
begin
  Result := NO_ERROR;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushObject(l, MangaInfo.mangaInfo, 'mangainfo');
      luaPushObject(l, MangaInfo.FHTTP, 'http');
      luaPushStringGlobal(L, 'url', AURL);
      luaPushObject(l, ANames, 'names');
      luaPushObject(l, ALinks, 'links');

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnGetNameAndLink) then
        Result := lua_tointeger(L, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoGetInfo(const MangaInfo: TMangaInformation; const AURL: String;
  const Module: TModuleContainer): Integer;
var
  l: Plua_State;
begin
  Result := NO_ERROR;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushStringGlobal(l, 'url', AURL);
      luaPushObject(l, MangaInfo.mangaInfo, 'mangainfo');
      luaPushObject(l, MangaInfo.FHTTP, 'http');

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      LuaCallFunction(l, OnGetInfo);
    except
      Logger.SendError(lua_tostring(L, -1));
    end;
    lua_close(l);
  end;
end;

function DoTaskStart(const Task: TTaskContainer; const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushObject(l, Task, 'task');

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnTaskStart) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoGetPageNumber(const DownloadThread: TDownloadThread;
  const AURL: String; const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushObject(L, DownloadThread.Task.Container, 'task');
      luaPushObject(l, DownloadThread.FHTTP, 'http');
      luaPushStringGlobal(l, 'url', AURL);

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnGetPageNumber) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoGetImageURL(const DownloadThread: TDownloadThread; const AURL: String;
  const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushObject(L, DownloadThread.Task.Container, 'task');
      luaPushObject(l, DownloadThread.FHTTP, 'http');
      luaPushIntegerGlobal(l, 'workid', DownloadThread.WorkId);
      luaPushStringGlobal(l, 'url', AURL);

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnGetImageURL) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoBeforeDownloadImage(const DownloadThread: TDownloadThread;
  var AURL: String; const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushObject(L, DownloadThread.Task.Container, 'task');
      luaPushObject(l, DownloadThread.FHTTP, 'http');
      luaPushStringGlobal(l, 'url', AURL);

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnBeforeDownloadImage) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoDownloadImage(const DownloadThread: TDownloadThread;
  const AURL: String; const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushObject(L, DownloadThread.Task.Container, 'task');
      luaPushObject(l, DownloadThread.FHTTP, 'http');
      luaPushStringGlobal(l, 'url', AURL);

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnDownloadImage) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoSaveImage(const AHTTP: THTTPSendThread; const APath, AName: String;
  const Module: TModuleContainer): String;
var
  l: Plua_State;
begin
  Result := '';
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushObject(l, AHTTP, 'http');
      luaPushStringGlobal(l, 'path', APath);
      luaPushStringGlobal(l, 'name', AName);

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnSaveImage) then
        Result := lua_tostring(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoAfterImageSaved(const AFilename: String; const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushStringGlobal(l, 'filename', AFilename);

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnAfterImageSaved) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function DoLogin(const AHTTP: THTTPSendThread; const Module: TModuleContainer): Boolean;
var
  l: Plua_State;
begin
  Result := False;
  with TLuaWebsiteModule(Module.TagPtr) do
  begin
    l := LuaNewBaseState;
    try
      LuaPushMe(l);
      luaPushObject(l, AHTTP, 'http');

      if LuaDoMe(l) <> 0 then
        raise Exception.Create('');
      if LuaCallFunction(l, OnTaskStart) then
        Result := lua_toboolean(l, -1);
    except
      Logger.SendError(lua_tostring(l, -1));
    end;
    lua_close(l);
  end;
end;

function LoadLuaToWebsiteModules(AFilename: String): Boolean;
var
  l: Plua_State;
  c: TLuaWebsiteModulesContainer;
  m: TMemoryStream;
  i: Integer;
  s: String;
begin
  Result := False;
  Logger.Send('Load lua website module', AFilename);
  try
    l := LuaNewBaseState;
    try
      m := LuaDumpFileToStream(l, AFilename);
      if m <> nil then
      begin
        if lua_pcall(l, 0, 0, 0) <> 0 then
          raise Exception.Create('');
        LuaCallFunction(l, 'Init');
      end;
    except
      Logger.SendError('Error load lua website module. ' + lua_tostring(L, -1));
    end;
  finally
    lua_close(l);
  end;

  if LuaWebsiteModulesManager.TempModuleList.Count <> 0 then
    with LuaWebsiteModulesManager do
    begin
      c := TLuaWebsiteModulesContainer.Create;
      c.FileName := AFilename;
      c.ByteCode := m;
      m := nil;
      s := '';
      Containers.Add(c);
      for i := 0 to TempModuleList.Count - 1 do
        with TempModuleList[i] do
        begin
          s += Module.Website + ', ';
          c.Modules.Add(TempModuleList[i]);
          Container := c;
          if OnBeforeUpdateList <> '' then
            Module.OnBeforeUpdateList := @DoBeforeUpdateList;
          if OnAfterUpdateList <> '' then
            Module.OnAfterUpdateList := @DoAfterUpdateList;
          if OnGetDirectoryPageNumber <> '' then
            Module.OnGetDirectoryPageNumber := @DoGetDirectoryPageNumber;
          if OnGetNameAndLink <> '' then
            Module.OnGetNameAndLink := @DoGetNameAndLink;
          if OnGetInfo <> '' then
            Module.OnGetInfo := @DoGetInfo;
          if OnTaskStart <> '' then
            Module.OnTaskStart := @DoTaskStart;
          if OnGetPageNumber <> '' then
            Module.OnGetPageNumber := @DoGetPageNumber;
          if OnGetImageURL <> '' then
            Module.OnGetImageURL := @DoGetImageURL;
          if OnBeforeDownloadImage <> '' then
            Module.OnBeforeDownloadImage := @DoBeforeDownloadImage;
          if OnDownloadImage <> '' then
            Module.OnDownloadImage := @DoDownloadImage;
          if OnSaveImage <> '' then
            Module.OnSaveImage := @DoSaveImage;
          if OnAfterImageSaved <> '' then
            Module.OnAfterImageSaved := @DoAfterImageSaved;
          if OnLogin <> '' then
            Module.OnLogin := @DoLogin;
        end;
      TempModuleList.Clear;
      SetLength(s, Length(s) - 2);
      Logger.Send('Loaded modules from ' + ExtractFileName(AFilename), s);
      s := '';
    end;
  if m <> nil then
    m.Free;
end;

procedure ScanLuaWebsiteModulesFile;
var
  d: String;
  f: TStringList;
  i: Integer;
begin
  d := LUA_WEBSITEMODULE_FOLDER;
  try
    f := FindAllFiles(d, '*.lua', False, faAnyFile);
    if f.Count > 0 then
      for i := 0 to f.Count - 1 do
        LoadLuaToWebsiteModules(f[i]);
  finally
    f.Free;
  end;
end;

{ TLuaWebsiteModulesManager }

constructor TLuaWebsiteModulesManager.Create;
begin
  Containers := TLuaWebsiteModulesContainers.Create;
  TempModuleList := TLuaWebsiteModules.Create;
end;

destructor TLuaWebsiteModulesManager.Destroy;
var
  i: Integer;
begin
  for i := 0 to TempModuleList.Count - 1 do
    TempModuleList[i].Free;
  TempModuleList.Free;
  for i := 0 to Containers.Count - 1 do
    Containers[i].Free;
  Containers.Free;
  inherited Destroy;
end;

{ TLuaWebsiteModulesContainer }

constructor TLuaWebsiteModulesContainer.Create;
begin
  Modules := TLuaWebsiteModules.Create;
  ByteCode := nil;
end;

destructor TLuaWebsiteModulesContainer.Destroy;
var
  i: Integer;
begin
  if Assigned(ByteCode) then
    ByteCode.Free;
  for i := 0 to Modules.Count - 1 do
    Modules[i].Free;
  Modules.Free;
  inherited Destroy;
end;


{ TLuaWebsiteModule }

constructor TLuaWebsiteModule.Create;
begin
  LuaWebsiteModulesManager.TempModuleList.Add(Self);
  Storage := TStringsStorage.Create;
  Module := Modules.AddModule;
  Module.TagPtr := Self;
end;

destructor TLuaWebsiteModule.Destroy;
begin
  Storage.Free;
  inherited Destroy;
end;

procedure TLuaWebsiteModule.LuaPushMe(L: Plua_State);
begin
  luaPushObject(L, Self, 'module');
  luaPushIntegerGlobal(L, 'no_error', NO_ERROR);
  luaPushIntegerGlobal(L, 'net_problem', NET_PROBLEM);
  luaPushIntegerGlobal(L, 'information_not_found', INFORMATION_NOT_FOUND);
end;

function TLuaWebsiteModule.LuaDoMe(L: Plua_State): Integer;
begin
  if AlwaysLoadLuaFromFile then
    Result := luaL_loadfile(L, PChar(Container.FileName))
  else
    Result := LuaLoadFromStream(L, Container.ByteCode, PChar(Container.FileName));
  if Result = 0 then
    Result := lua_pcall(L, 0, 0, 0);
end;

procedure luaWebsiteModuleAddMetaTable(L: Plua_State; Obj: Pointer;
  MetaTable, UserData: Integer; AutoFree: Boolean = False);
begin
  with TLuaWebsiteModule(Obj) do
  begin
    luaClassAddStringProperty(L, MetaTable, 'Website', @Module.Website);
    luaClassAddStringProperty(L, MetaTable, 'RootURL', @Module.RootURL);
    luaClassAddIntegerProperty(L, MetaTable, 'MaxTaskLimit', @Module.MaxTaskLimit);
    luaClassAddIntegerProperty(L, MetaTable, 'MaxConnectionLimit',
      @Module.MaxConnectionLimit);
    luaClassAddIntegerProperty(L, MetaTable, 'ActiveTaskCount', @Module.ActiveTaskCount);
    luaClassAddIntegerProperty(L, MetaTable, 'ActiveConnectionCount',
      @Module.ActiveConnectionCount);
    luaClassAddBooleanProperty(L, MetaTable, 'AccountSupport', @Module.AccountSupport);
    luaClassAddBooleanProperty(L, MetaTable, 'SortedList', @Module.SortedList);
    luaClassAddBooleanProperty(L, MetaTable, 'InformationAvailable',
      @Module.InformationAvailable);
    luaClassAddBooleanProperty(L, MetaTable, 'FavoriteAvailable',
      @Module.FavoriteAvailable);
    luaClassAddBooleanProperty(L, MetaTable, 'DynamicPageLink', @Module.DynamicPageLink);
    luaClassAddBooleanProperty(L, MetaTable, 'DynamicPageLink',
      @Module.CloudflareEnabled);
    luaClassAddStringProperty(L, MetaTable, 'OnBeforeUpdateList', @OnBeforeUpdateList);
    luaClassAddStringProperty(L, MetaTable, 'OnAfterUpdateList', @OnAfterUpdateList);
    luaClassAddStringProperty(L, MetaTable, 'OnGetDirectoryPageNumber',
      @OnGetDirectoryPageNumber);
    luaClassAddStringProperty(L, MetaTable, 'OnGetNameAndLink', @OnGetNameAndLink);
    luaClassAddStringProperty(L, MetaTable, 'OnGetInfo', @OnGetInfo);
    luaClassAddStringProperty(L, MetaTable, 'OnTaskStart', @OnTaskStart);
    luaClassAddStringProperty(L, MetaTable, 'OnGetPageNumber', @OnGetPageNumber);
    luaClassAddStringProperty(L, MetaTable, 'OnGetImageURL', @OnGetImageURL);
    luaClassAddStringProperty(L, MetaTable, 'OnBeforeDownloadImage',
      @OnBeforeDownloadImage);
    luaClassAddStringProperty(L, MetaTable, 'OnDownloadImage', @OnDownloadImage);
    luaClassAddStringProperty(L, MetaTable, 'OnSaveImage', @OnSaveImage);
    luaClassAddStringProperty(L, MetaTable, 'OnAfterImageSaved', @OnAfterImageSaved);
    luaClassAddStringProperty(L, MetaTable, 'OnLogin', @OnLogin);
    luaClassAddStringProperty(L, MetaTable, 'LastUpdated', @LastUpdated);
    luaClassAddObject(L, MetaTable, Storage, 'Storage');
  end;
end;

function _create(L: Plua_State): Integer; cdecl;
begin
  luaClassPushObject(L, TLuaWebsiteModule.Create, '', False,
    @luaWebsiteModuleAddMetaTable);
  Result := 1;
end;

procedure luaWebsiteModuleRegister(L: Plua_State);
begin
  lua_register(L, 'NewModule', @_create);
end;

initialization
  luaClassRegister(TLuaWebsiteModule, @luaWebsiteModuleAddMetaTable,
    @luaWebsiteModuleRegister);
  LuaWebsiteModulesManager := TLuaWebsiteModulesManager.Create;

finalization
  LuaWebsiteModulesManager.Free;

end.