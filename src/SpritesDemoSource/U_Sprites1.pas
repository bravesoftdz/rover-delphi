unit U_Sprites1;
{Copyright 2002, Gary Darby, Intellitech Systems Inc., www.DelphiForFun.org

 This program may be used or modified for any non-commercial purpose
 so long as this original notice remains in place.
 All other rights are reserved
 }

{First, and the simplest, of 4 sprite drawing demos - It redraws the background
 and all of the currently defined sprites for each frame.}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Spin, ComCtrls, ImgList;

type

  TSpriteRec=record
    w,h: integer; {width & height of sprite rectangle}
    theta:single;  {angle to move}
    speed:single;  {pixels to move for each frame}
    x,y:single; {use floating x,y values to allow fractional pixel moves}
    prevrect:Trect;
    Sprite:TBitmap;
  end;

  TManspriteRec=record
    index:integer; {index of current image being displayed}
    w,h:integer;
    ispeed:integer;  {thi h=guys moves slowly so integer speed and coordinates are OK}
    ix,iy:integer;
    prevrect:Trect;
    manpics: array[0..5] of TBitmap;
  end;

  TForm1 = class(TForm)
    StopBtn: TButton;
    DrawBtn: TButton;
    TimeLbl: TLabel;
    Spritecount: TSpinEdit;
    Label3: TLabel;
    Speedbar: TTrackBar;
    Label1: TLabel;
    StatusBar1: TStatusBar;
    Image1: TImage;
    ManSpeedBar: TTrackBar;
    Label2: TLabel;
    DoubleBufBox: TCheckBox;
    MemLbl: TLabel;
    procedure StopBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure SpritePaint(Sender: TObject);
    procedure DrawBtnClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure SpeedbarChange(Sender: TObject);
    procedure SpritecountChange(Sender: TObject);
    procedure ManSpeedBarChange(Sender: TObject);
    procedure DoubleBufBoxClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    {procedure Button1Click(Sender: TObject);}
public
    { Public declarations }
    spriterec:array[1..20] of TSpriterec;
    mansprite:TManSpriterec;
    bg:TBitmap;  {Bitmap to hold background image}
    perffreq:int64;
    loopcount:integer;
    manrest:integer;
    startcount:int64;  {1st counter value frame rate calculation}
    procedure setupsprite(n:integer);
    procedure setupmansprites;
    procedure MoveSprite(N:integer);
    procedure Movemansprite;
    procedure animate;
  end;

var  Form1: TForm1;

implementation

{$R *.DFM}
{$R Sprites.res}

 (*
{******************** FormCreate ***************}
procedure TForm1.FormCreate(Sender: TObject);
begin
  bg:=TBitmap.create; {holds background}
  QueryPerformanceFrequency(perffreq);
  {load background picture }
  bg.loadfromfile('cloudbg8.bmp');
  stopbtn.bringtofront;
  doublebuffered:=doublebufbox.checked;
end;
*)


{******************** FormCreate ***************}
procedure TForm1.FormCreate(Sender: TObject);
var
  Context:HDC;
  Bitsperpixel:integer;
  pixelformat:TPixelFormat;
begin
  Context:=getdc(application.handle);
  BitsPerPixel:=GetDeviceCaps(Context,BitsPixel);
  case BitsPerPixel of
    8: pixelformat:=pf8bit;
    16:pixelformat:=pf16bit;
    24:pixelformat:=pf24bit;
    else pixelformat:=pf32bit;
  end;

  releaseDC(application.handle,context);
  bg:=TBitmap.create; {holds background}
  QueryPerformanceFrequency(perffreq);
  bg.handle:=loadBitmap(Hinstance, 'cloudbg8'); {load background picture}
  bg.pixelformat:=pixelformat;
  {bg.loadfromfile('cloudbg8.bmp');}
  stopbtn.bringtofront;
  doublebuffered:=false;
  pixelformat:=bg.pixelformat;
end;

{**********************  FormActivate ************}
procedure TForm1.FormActivate(Sender: TObject);
begin
  windowstate:=wsmaximized;
  setupmansprites; {only need to do this once}
end;

{****************** FormCloseQuesry ************}
procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  StopBtnClick(sender);
  canclose:=true;
end;

{*********** FormResize ************}
procedure TForm1.FormResize(Sender: TObject);
begin
  tag:=1; {stop if running}
  with image1 do
  begin
    width:=form1.clientwidth-2*left;
    height:=stopbtn.top-top-10;
    picture.bitmap.width:=width;
    picture.bitmap.height:=height;
    canvas.stretchdraw(rect(0,0,width,height),bg);
  end;
  setupmansprites; {only need to do this once (or on resize)}
end;

{******************** StopBtnClick **************}
procedure TForm1.StopBtnClick(Sender: TObject);
begin   tag:=1; end;

{***************** DrawPartBtnClick ************}
procedure TForm1.DrawBtnClick(Sender: TObject);
begin   animate;  end;

{*************** SpeedBarChange *************}
procedure TForm1.SpeedbarChange(Sender: TObject);
begin
   queryperformancecounter(startcount);
   loopcount:=0;
end;

{****************** SpriteCountChange *************}
procedure TForm1.SpritecountChange(Sender: TObject);
begin
  tag:=1; {stop it if running}
  {animate;} {start it up again}
end;

{***************** ManSpeedBarChange ************}
procedure TForm1.ManSpeedBarChange(Sender: TObject);
begin
  manrest:=manspeedbar.max-manspeedbar.position+1;
end;

{***************** DoubleBufBoxClick ***********}
procedure TForm1.DoubleBufBoxClick(Sender: TObject);
{There seem to be a difference in canvase buffer handling between Delphi
 versions 5 and 6 - D6 has flicker during redraws unluess double buffering is
 turned on.  D5 should have but does not. }
begin doublebuffered:=doublebufbox.checked;  end;

{****************** SetupSprite *****************}
procedure TForm1.setupsprite(n:integer);
{Make an ellipse (or load a letter image) with random location, color size
 and initial angle of movement}
begin
  with spriterec[n] do
  begin
    theta:=0.1+random*2*pi; {initial direction-  make sure it never hits in a corner}
    speed:=2+random(6);
    if not assigned(sprite) then  sprite:=TBitmap.create;
    {make sprite image}
    with sprite, canvas  do
    begin
      transparent:=true;
      transparentcolor:=clblack;
      transparent:=true;
      case n of
        1,2,4,6,8,10,12,14:  {ellipses}
          begin
            width:=20+random(20); {from 20 to 40 pixels wide}
            height:=20+random(20); {from 20 to 40 pixels high}
            brush.color:=clblack;
            rectangle(0,0,width,height);
            { set sprite color - make sure that it's not black (0,0,0) since
              that's  our transparent color}
            brush.color:=rgb(1+random(254),1+random(254),1+random(254));
            ellipse(0,0,width,height);
          end;
        {letters}
        3: Sprite.handle:=loadbitmap(Hinstance,'LETTERD'); {loadfromfile('D.bmp');}
        5: Sprite.handle:=loadbitmap(Hinstance,'LETTERE');
        7: Sprite.handle:=loadbitmap(Hinstance,'LETTERL');
        9: Sprite.handle:=loadbitmap(Hinstance,'LETTERP');
        11:Sprite.handle:=loadbitmap(Hinstance,'LETTERH');
        13:Sprite.handle:=loadbitmap(Hinstance,'LETTERI');
      end;
      w:=width;
      h:=height;
      x:=w+random(image1.width-3*w);  {initial position}
      y:=h+random(image1.height-3*h);
    end;
  end;
end;

{**************  setupmansprites **********}
procedure TForm1.setupmansprites;
var
  i:integer;
begin
  with mansprite do
  begin
    for i:=0 to 5 do {load "walking man" images}
    begin
      If  not assigned(manpics[i]) then manpics[i]:=TBitmap.create;
      with manpics[i] do
      begin
        handle:=loadbitmap(Hinstance,pchar('ManSprite'+inttostr(i)));
        transparent:=true;
        transparentcolor:=clblack;
      end;
    end;
    w:=manpics[0].width;
    h:=manpics[0].height;
    index:=0;
    ispeed:=8;
    ix:=0;
    iy:=image1.height-h;
  end;
end;

{******************* MoveSprite ***********}
procedure TForm1.MoveSprite(n:integer);
{Set next sprite coordinates - called from the "Animate" procedure loop}
var
  trycount:integer;
  tryx,tryy:single;
begin
  with spriterec[n] do
  begin  {random bounce}
    if (x<0) or (x+w>image1.width) or (y<0) or (y+h>image1.height) then
    begin  {If we're off the edge, get a new random direction that keeps us in sight}
      trycount:=0;
      repeat
        theta:=2*pi*random;
        tryx:=x+speed*cos(theta);
        tryy:=y+speed*sin(theta);
        inc(trycount)
      until (trycount>100) or
      ((tryx>=0) and (tryx+w<=image1.width) and (tryy>=0)
                 and (tryy+h<=image1.height));
      x:=tryx;
      y:=tryy;
    end
    else
    begin
      x:=x+speed*cos(theta);
      y:=y+speed*sin(theta);
    end;
  end;
end;

{*************** MovemanSprite *********}
procedure TForm1.MoveManSprite;
{Set next sprite coordinates}
begin
  with mansprite do
  begin
    if  (ix>image1.width) then ix:=0;
    ix:=ix+ispeed;
  end;
end;

{********************** Animate *********************}
procedure TForm1.animate;
{Loop moving all sprites until user clicks  Stop button}
var i:integer;
    r:Trect;
    stopcount:int64;
    avgrate:single;
begin
  {Set things up}
  stopbtn.visible:=true;
  manrest:=manspeedbar.max-manspeedbar.position+1;
  loopcount:=0;
  for i:=1 to spritecount.value do setupsprite(i); {make some sprites}
  tag:=0;
  {copy background image bg image to work canvas}
  r:=rect(0,0,image1.width,image1.height);
  image1.picture.bitmap.width:=image1.width;
  image1.picture.bitmap.height:=image1.height;
  image1.canvas.stretchdraw(r,bg);
  bg.width:=image1.width; bg.height:=image1.height;
  bg.canvas.draw(0,0,image1.picture.bitmap);
  update;
  QueryPerformanceCounter(startcount);

  {Start things moving}
  while tag=0 do
  begin
    for i:=1 to spritecount.value do MoveSprite(i); {move the sprites}
    if loopcount mod manrest = 0 then movemansprite;
    SpritePaint(self);  {repaint}
    inc(loopcount);
    if loopcount mod 64=0 then
    begin
      queryperformancecounter(stopcount);
      avgrate:=loopcount*perffreq/(stopcount-startcount);
      TimeLbl.caption:=format('Avg. frames/sec %6.0f',[avgrate]);
      {MemLbl.caption:=inttostr(allocmemsize); checking for memory leaks}
    end;
    application.processmessages;
    sleep(10-speedbar.position); {control speed by waiting a few milliseconds}
  end;
  stopbtn.visible:=false;
end;

{******************* SpritePaint **************}
procedure TForm1.SpritePaint(Sender: TObject);
{Redraw background and all of the sprites}
var i:integer;
begin
  if not assigned(spriterec[1].sprite) then exit;
  with image1, canvas do
  begin
    draw(0,0,bg);
    for i:=1 to spritecount.value do
    with spriterec[i] do canvas.draw(trunc(x), trunc(y), sprite);
    with mansprite do
    begin
      i:=(loopcount div manrest) mod 6;
      draw(ix,iy,manpics[i]);
    end;
  end;
end;

(*
procedure TForm1.Button1Click(Sender: TObject);
begin
  image1.picture.bitmap.savetofile(extractfilepath(application.exename)
          +'Spritepic'+ inttostr(trunc(now*secsperday))+'.bmp');
end;
*)


end.
