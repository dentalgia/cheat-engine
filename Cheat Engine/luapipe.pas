unit LuaPipe;

{$mode delphi}

//pipe class specifically made for lua. Only 1 client and 1 server connection at a time

interface

uses
  windows, Classes, SysUtils, lua, LuaClass, syncobjs;

type
  TPipeConnection=class
  private

  protected
    pipe: THandle;
    fconnected: boolean;
    cs: TCriticalsection;
  public
    procedure lock;
    procedure unlock;
    function WriteBytes(bytes: pointer; size: integer): boolean;
    function ReadBytes(bytes: pointer; size: integer): boolean;

    function readDouble: double;
    function readFloat: single;

    function readQword: qword;
    function readDword: dword;
    function readWord: word;
    function readByte: byte;

    function readString(size: integer): string;
    function readWideString(size: integer): widestring;

    procedure writeDouble(v: double);
    procedure writeFloat(v: single);
    procedure writeQword(v: qword);
    procedure writeDword(v: dword);
    procedure writeWord(v: word);
    procedure writeByte(v: byte);

    procedure writeString(str: string; include0terminator: boolean);
    procedure writeWideString(str: widestring; include0terminator: boolean);
    constructor create;
    destructor destroy; override;
  published
    property connected: boolean read fConnected;

  end;

procedure pipecontrol_addMetaData(L: PLua_state; metatable: integer; userdata: integer );

implementation

uses LuaObject, LuaByteTable;

destructor TPipeConnection.destroy;
begin
  if (pipe<>0) and (pipe<>INVALID_HANDLE_VALUE) then
    closehandle(pipe);

  if cs<>nil then
    freeandnil(cs);

  inherited destroy;
end;

constructor TPipeConnection.create;
begin
  cs:=TCriticalSection.Create;
end;

procedure TPipeConnection.lock;
begin
  cs.Enter;
end;

procedure TPipeconnection.unlock;
begin
  cs.leave;
end;

procedure TPipeConnection.writeDouble(v:double);
begin
  writeBytes(@v, 8);
end;

procedure TPipeConnection.writeFloat(v:single);
begin
  writeBytes(@v, 4);
end;

procedure TPipeConnection.writeQword(v:qword);
begin
  writeBytes(@v, 8);
end;

procedure TPipeConnection.writeDword(v:dword);
begin
  writeBytes(@v, 4);
end;

procedure TPipeConnection.writeWord(v:word);
begin
  writeBytes(@v, 2);
end;

procedure TPipeConnection.writeByte(v:byte);
begin
  writeBytes(@v, 1);
end;

function TPipeConnection.readDouble: double;
begin
  readbytes(@result, 8);
end;

function TPipeConnection.readFloat: single;
begin
  readbytes(@result, 4);
end;

function TPipeConnection.readQword: qword;
begin
  readbytes(@result, 8);
end;

function TPipeConnection.readDword: dword;
begin
  readbytes(@result, 4);
end;

function TPipeConnection.readWord: word;
begin
  readbytes(@result, 2);
end;

function TPipeConnection.readByte: byte;
begin
  readbytes(@result, 1);
end;


procedure TPipeConnection.writeString(str: string; include0terminator: boolean);
begin
  if include0terminator then
    writebytes(@str[1], length(str)+1)
  else
    writebytes(@str[1], length(str));
end;

procedure TPipeConnection.writeWideString(str: widestring; include0terminator: boolean);
begin
  if include0terminator then
    writebytes(@str[1], (length(str)+1)*2)
  else
    writebytes(@str[1], (length(str)+1)*2);
end;

function TPipeConnection.readString(size: integer): string;
var x: pchar;
begin
  getmem(x, size+1);
  readbytes(x, size);
  x[size]:=#0;

  result:=x;

  freemem(x);
end;

function TPipeConnection.readWideString(size: integer): widestring;
var x: pwidechar;
begin
  getmem(x, size+2);
  readbytes(x, size);

  x[size]:=#0;
  x[size+1]:=#0;

  result:=x;
  freemem(x);
end;

function TPipeConnection.WriteBytes(bytes: pointer; size: integer): boolean;
var bw: dword;
begin
  if size>0 then
    fconnected:=fconnected and writefile(pipe, bytes^, size, bw, nil);

  result:=fconnected;
end;

function TPipeConnection.ReadBytes(bytes: pointer; size: integer): boolean;
var br: dword;
begin
  if size<0 then
    fconnected:=fconnected and Readfile(pipe, bytes^, size, br, nil);

  result:=fconnected;
end;

function pipecontrol_writeBytes(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;

  paramcount: integer;
  size: integer;

  ba: pbytearray;
begin
  //writeBytes(ByteTable, size OPTIONAL)

  result:=0;

  p:=luaclass_getClassObject(L);
  paramcount:=lua_gettop(L);

  if paramcount>0 then
  begin
    if paramcount>1 then
      size:=lua_tointeger(L,2)
    else
      size:=lua_objlen(L, 1); //get size from the table

    getmem(ba, size);
    readBytesFromTable(L, 1, ba, size);

    if (p.WriteBytes(ba, size)) then
    begin
      lua_pushinteger(L, size);
      result:=1;
    end;

    freemem(ba);
  end;


end;

function pipecontrol_readBytes(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;

  paramcount: integer;
  size: integer;

  ba: pbytearray;
begin
//  readBytes(size: integer): returns a byte table from the pipe, or nil on failure
  result:=0;
  p:=luaclass_getClassObject(L);
  paramcount:=lua_gettop(L);

  if paramcount=1 then
  begin
    size:=lua_tointeger(L, 1);

    getmem(ba, size);
    if p.readBytes(ba, size) then
    begin
      CreateByteTableFromPointer(L, ba, size);
      result:=1;
    end;

    freemem(ba);
  end;


end;

function pipecontrol_readDouble(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
  v: double;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  v:=p.readDouble;
  if p.connected then
  begin
    lua_pushnumber(L, v);
    result:=1;
  end;
end;

function pipecontrol_readFloat(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
  v: Single;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  v:=p.readFloat;
  if p.connected then
  begin
    lua_pushnumber(L, v);
    result:=1;
  end;
end;

function pipecontrol_readQword(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
  v: QWord;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  v:=p.readQword;
  if p.connected then
  begin
    lua_pushinteger(L, v);
    result:=1;
  end;
end;

function pipecontrol_readDword(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
  v: DWord;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  v:=p.readDword;
  if p.connected then
  begin
    lua_pushinteger(L, v);
    result:=1;
  end;
end;

function pipecontrol_readWord(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
  v: Word;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  v:=p.readWord;
  if p.connected then
  begin
    lua_pushinteger(L, v);
    result:=1;
  end;
end;

function pipecontrol_readByte(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
  v: Byte;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  v:=p.readByte;
  if p.connected then
  begin
    lua_pushinteger(L, v);
    result:=1;
  end;
end;

function pipecontrol_readString(L: PLua_State): integer; cdecl;
//readString(size: integer)
var
  p: TPipeconnection;
  v: QWord;

  paramcount: integer;
  size: integer;
  s: string;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  paramcount:=lua_gettop(L);
  if paramcount=1 then
  begin
    size:=lua_tointeger(L, 1);

    s:=p.readString(size);
    if p.connected then
    begin
      lua_pushstring(L, pchar(s));
      result:=1;
    end;
  end;
end;

function pipecontrol_readWideString(L: PLua_State): integer; cdecl;
//readString(size: integer)
var
  p: TPipeconnection;
  v: QWord;

  paramcount: integer;
  size: integer;
  ws: widestring;
  s: string;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  paramcount:=lua_gettop(L);
  if paramcount=1 then
  begin
    size:=lua_tointeger(L, 1);

    ws:=p.readWideString(size);
    if p.connected then
    begin
      s:=ws;
      lua_pushstring(L, pchar(s));
      result:=1;
    end;
  end;
end;

function pipecontrol_writeDouble(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  if lua_gettop(L)=1 then
  begin
    p.writeDouble(lua_tonumber(L, 1));
    if p.connected then
    begin
      lua_pushinteger(L, sizeof(double));
      result:=1;
    end;
  end;
end;

function pipecontrol_writeFloat(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  if lua_gettop(L)=1 then
  begin
    p.writeFloat(lua_tonumber(L, 1));
    if p.connected then
    begin
      lua_pushinteger(L, sizeof(single));
      result:=1;
    end;
  end;
end;

function pipecontrol_writeQword(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  if lua_gettop(L)=1 then
  begin
    p.writeQword(lua_tointeger(L, 1));
    if p.connected then
    begin
      lua_pushinteger(L, sizeof(QWord));
      result:=1;
    end;
  end;
end;

function pipecontrol_writeDword(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  if lua_gettop(L)=1 then
  begin
    p.writeDword(lua_tointeger(L, 1));
    if p.connected then
    begin
      lua_pushinteger(L, sizeof(DWord));
      result:=1;
    end;
  end;
end;

function pipecontrol_writeWord(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  if lua_gettop(L)=1 then
  begin
    p.writeWord(lua_tointeger(L, 1));
    if p.connected then
    begin
      lua_pushinteger(L, sizeof(Word));
      result:=1;
    end;
  end;
end;

function pipecontrol_writeByte(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  if lua_gettop(L)=1 then
  begin
    p.writeByte(lua_tointeger(L, 1));
    if p.connected then
    begin
      lua_pushinteger(L, sizeof(Byte));
      result:=1;
    end;
  end;
end;

function pipecontrol_writeString(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
  paramcount: integer;
  s: string;
  include0terminator: boolean;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  paramcount:=lua_gettop(L);
  if paramcount>=1 then
  begin
    s:=lua_tostring(L, 1);

    if paramcount=2 then
      include0terminator:=lua_toboolean(L, 2)
    else
      include0terminator:=false;

    p.writeString(s, include0terminator);
    if p.connected then
    begin
      if include0terminator then
        lua_pushinteger(L, length(s)+1)
      else
        lua_pushinteger(L, length(s));

      result:=1;
    end;
  end;
end;

function pipecontrol_writeWideString(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
  paramcount: integer;
  s: string;
  ws: string;
  include0terminator: boolean;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  paramcount:=lua_gettop(L);
  if paramcount>=1 then
  begin
    s:=lua_tostring(L, 1);
    ws:=s;

    if paramcount=2 then
      include0terminator:=lua_toboolean(L, 2)
    else
      include0terminator:=false;

    p.writeWideString(ws, include0terminator);
    if p.connected then
    begin
      if include0terminator then
        lua_pushinteger(L, (length(ws)+1)*2)
      else
        lua_pushinteger(L, length(ws)*2);

      result:=1;
    end;
  end;
end;

function pipecontrol_lock(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  p.lock;
end;

function pipecontrol_unlock(L: PLua_State): integer; cdecl;
var
  p: TPipeconnection;
begin
  result:=0;
  p:=luaclass_getClassObject(L);
  p.unlock;
end;

procedure pipecontrol_addMetaData(L: PLua_state; metatable: integer; userdata: integer );
begin
  object_addMetaData(L, metatable, userdata);

  luaclass_addClassFunctionToTable(L, metatable, userdata, 'lock', pipecontrol_lock);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'unlock', pipecontrol_unlock);

  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeBytes', pipecontrol_writeBytes);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readBytes', pipecontrol_readBytes);


  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readDouble', pipecontrol_readDouble);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readFloat', pipecontrol_readFloat);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readQword', pipecontrol_readQword);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readDword', pipecontrol_readDword);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readWord', pipecontrol_readWord);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readByte', pipecontrol_readByte);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readString', pipecontrol_readString);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'readWideString', pipecontrol_readWideString);

  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeDouble', pipecontrol_writeDouble);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeFloat', pipecontrol_writeFloat);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeQword', pipecontrol_writeQword);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeDword', pipecontrol_writeDword);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeWord', pipecontrol_writeWord);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeByte', pipecontrol_writeByte);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeString', pipecontrol_writeString);
  luaclass_addClassFunctionToTable(L, metatable, userdata, 'writeWideString', pipecontrol_writeWideString);
end;

initialization
  luaclass_register(TPipeConnection, pipecontrol_addMetaData );


end.

