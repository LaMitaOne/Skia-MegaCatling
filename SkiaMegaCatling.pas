{*******************************************************************************
  MegaCatling (Sci-Fi Shooter/Platformer Prototype)
********************************************************************************
  A procedural platformer built with Delphi FMX and Skia4Delphi.

  Author:  Lara Miriam Tamy Reschke
  License: MIT

  Latest changes:
    v0.1
   - Advanced Player Physics: Implemented Double Jump, Wall Sliding, and Wall Jumping. Reworked gravity for better air control. Added "Squash & Stretch" animations for jumping and landing.
   - New Enemy AI System:
     Walkers: Now detect ledges (won't walk off cliffs) and shoot projectiles at the player.
     Dogs: New aggressive charger enemy that lunges when the player is in range.
     Flyers: Reworked drone AI. They maintain distance, break aggro if the player jumps too high, and leash back to their spawn point.
   - Level Generation Overhaul: Added Moving Platforms (spawn over pits), Conveyor Belts, and floating "Sky Islands" containing pickups.
   - Items & Upgrades: Added collectible crates that grant temporary Damage Boosts or restore HP.

*******************************************************************************}

unit SkiaMegaCatling;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math,
  System.Generics.Collections, System.UITypes, System.SyncObjs, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Skia, Winapi.MMSystem, System.Skia;

const
  TILE_SIZE = 32;
  RENDER_WIDTH = 1280;
  RENDER_HEIGHT = 720;
  MAX_PARTICLES = 60;

  GRAVITY = 45.0;
  ACCEL = 80.0;
  MAX_SPEED = 8.0;
  JUMP_FORCE = -17.0;
  FRICTION = 60.0;
  VK_SHOOT = 200;

type
  TBodyState = (bsGround, bsAir, bsWall);
  TGameState = (gsTitle, gsPlaying, gsDead, gsWin, gsLoading);
  TTileType = (ttEmpty, ttGround, ttGrass, ttStone, ttConveyorLeft, ttConveyorRight);
  TAudioEffect = (afNone, afJump, afExplosion, afCrate, afPortal, afWin, afDie, afShoot, afUpgrade);

  TTile = record
    TileType: TTileType;
    Solid: Boolean;
  end;

  TActor = record
    Pos: TPointF;
    Vel: TPointF;
    Width: Single;
    Height: Single;
    State: TBodyState;
    JumpCount: Integer;
    Squash: Single;
    JumpCooldown: Single;
  end;

  TParticle = record
    Pos: TPointF;
    Vel: TPointF;
    Life: Single;
    Color: TAlphaColor;
    Size: Single;
  end;

  TDecorType = (dtCrate, dtUpgradeDmg, dtUpgradeHP);
  TDecorItem = record
    Pos: TPointF;
    Kind: TDecorType;
  end;

  TEnemyType = (etWalker, etFlyer, etDog);
  TEnemy = record
    Pos: TPointF;
    Vel: TPointF;
    Width: Single;
    Height: Single;
    Phase: Single;
    Health: Integer;
    MaxHealth: Integer;
    EnemyType: TEnemyType;
    ShootCooldown: Single;
    HitFlash: Single;
    Origin: TPointF;
  end;

  TBullet = record
    Pos: TPointF;
    Vel: TPointF;
    Life: Single;
    IsPlayerBullet: Boolean;
    Damage: Integer;
  end;

  TGate = record
    Pos: TPointF;
    Width: Single;
    Height: Single;
    Phase: Single;
  end;

  TMovingPlatform = record
    Pos: TPointF;
    StartX: Single;
    EndX: Single;
    Width: Single;
    Height: Single;
    Speed: Single;
    Direction: Integer;
  end;

  TMegaCatlingGame = class(TSkCustomControl)
  private
    FThread: TThread;
    FActive: Boolean;
    FLock: TCriticalSection;
    FKeys: set of Byte;
    FGameState: TGameState;

    FScore: Integer;
    FLevel: Integer;
    FDeadTime: Single;
    FWinTime: Single;
    FLoadingTimer: Single;
    FAnimPhase: Single;

    FLookDir: Integer;
    FBraking: Boolean;
    FCrouching: Boolean;
    FPlayer: TActor;
    FFireCooldown: Single;
    FDamageBoostTimer: Single;
    FPlayerHP: Integer;
    FInvincibilityTimer: Single;
    FCheckpointPos: TPointF;
    FCheckpointTimer: Single;
    FJumpPressed: Boolean;

    FTitleAlpha: Single;
    FTitleFadingOut: Boolean;
    FMenuAlpha: Single;
    FMenuTargetActive: Boolean;

    FTiles: TArray<TTile>;
    FDecor: TList<TDecorItem>;
    FEnemies: TList<TEnemy>;
    FBullets: TList<TBullet>;
    FPlatforms: TList<TMovingPlatform>;
    FGate: TGate;
    FMapCols: Integer;
    FMapRows: Integer;
    FCameraX: Single;
    FCameraY: Single;

    FParticles: TList<TParticle>;
    FBgPlanets: TArray<TPointF>;
    FBgDrones: TArray<TPointF>;
    FBgRings: TArray<TPointF>;

    FGrassShader: ISkShader;
    FDirtShader: ISkShader;
    FStoneShader: ISkShader;

    procedure PlayEffect(Effect: TAudioEffect);
    procedure DoPhysicsUpdate(DeltaSec: Double);
    procedure UpdateCamera;
    procedure SafeInvalidate;
    procedure StartThread;
    procedure StopThread;

    procedure GenerateProceduralMap;
    procedure GenerateBackgroundElements;
    procedure InitProceduralTextures;

    procedure CheckCrateCollisions;
    procedure CheckEnemyCollisions;
    procedure CheckGateCollision;
    procedure UpdateEnemies(DeltaSec: Double);
    procedure UpdateBullets(DeltaSec: Double);
    procedure CheckBulletCollisions;
    procedure SpawnExplosion(const X, Y: Single; Color: TAlphaColor);
    procedure UpdateParticles(DeltaTime: Single);
    procedure UpdatePlatforms(DeltaSec: Double);

    procedure DrawBackgrounds(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawTileMap(const ACanvas: ISkCanvas);
    procedure DrawDecorations(const ACanvas: ISkCanvas);
    procedure DrawEnemies(const ACanvas: ISkCanvas);
    procedure DrawBullets(const ACanvas: ISkCanvas);
    procedure DrawPlatforms(const ACanvas: ISkCanvas);
    procedure DrawGate(const ACanvas: ISkCanvas);
    procedure DrawParticles(const ACanvas: ISkCanvas);
    procedure DrawUI(const ACanvas: ISkCanvas);
    procedure DrawMenu(const ACanvas: ISkCanvas; const ADest: TRectF; const Alpha: Single);
    procedure DrawTitleScreen(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawLoadingScreen(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure DrawCyberCatlingAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
  protected
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
  end;

implementation

// Checks if a world coordinate intersects a solid tile
function IsSolidTile(const Tiles: TArray<TTile>; Cols, Rows: Integer; const AX, AY: Single): Boolean;
var
  Col, Row: Integer;
begin
  Col := Trunc(AX / TILE_SIZE);
  Row := Trunc(AY / TILE_SIZE);
  if (Col < 0) or (Col >= Cols) then Exit(True);
  if (Row < 0) or (Row >= Rows) then Exit(False);
  Result := Tiles[Row * Cols + Col].Solid;
end;

// Returns the type of tile at a specific world coordinate
function GetTileType(const Tiles: TArray<TTile>; Cols, Rows: Integer; const AX, AY: Single): TTileType;
var
  Col, Row: Integer;
begin
  Col := Trunc(AX / TILE_SIZE);
  Row := Trunc(AY / TILE_SIZE);
  if (Col < 0) or (Col >= Cols) or (Row < 0) or (Row >= Rows) then
    Exit(ttEmpty);
  Result := Tiles[Row * Cols + Col].TileType;
end;

// Generates procedural textures using Skia surfaces to avoid external image files
procedure TMegaCatlingGame.InitProceduralTextures;
var
  LSurface: ISkSurface;
  LCanvas: ISkCanvas;
  LPaint: ISkPaint;
  I, VariantX: Integer;
begin
  Randomize;
  LPaint := TSkPaint.Create(TSkPaintStyle.Fill);
  LPaint.AntiAlias := True;

  LSurface := TSkSurface.MakeRaster(256, 32);
  LCanvas := LSurface.Canvas;
  LCanvas.Clear($FF000000);

  for VariantX := 0 to 7 do
  begin
    LPaint.Style := TSkPaintStyle.Fill;
    LPaint.Color := $FF111118;
    LCanvas.DrawRect(RectF(VariantX * 32, 0, (VariantX + 1) * 32, 32), LPaint);

    LPaint.StrokeWidth := 1.5;
    LPaint.Style := TSkPaintStyle.Stroke;
    if VariantX mod 2 = 0 then
      LPaint.Color := $FFFF00FF
    else
      LPaint.Color := $FF00FFFF;

    for I := 0 to 3 do
      LCanvas.DrawLine(PointF(VariantX * 32 + Random(32), Random(32)), PointF(VariantX * 32 + Random(32), Random(32)), LPaint);
  end;

  FGrassShader := LSurface.MakeImageSnapshot.MakeShader(TSkTileMode.Repeat, TSkTileMode.Repeat);
  FDirtShader := FGrassShader;
  FStoneShader := FGrassShader;
end;

// Generates the level layout, platforms, gaps, enemies, and pickups
procedure TMegaCatlingGame.GenerateProceduralMap;
var
  C, R, GapLen, PLen: Integer;
  FloorLevel, LastGapEnd, PlatformY, PlatformX: Integer;
  Item: TDecorItem;
  Enemy: TEnemy;
  IsAboveGap: Boolean;
  Plat: TMovingPlatform;
begin
  for R := 0 to FMapRows - 1 do
    for C := 0 to FMapCols - 1 do
    begin
      FTiles[R * FMapCols + C].TileType := ttEmpty;
      FTiles[R * FMapCols + C].Solid := False;
    end;

  FDecor.Clear;
  FEnemies.Clear;
  FBullets.Clear;
  FPlatforms.Clear;
  FParticles.Clear;

  FloorLevel := FMapRows - 4;
  LastGapEnd := -10;
  C := 0;

  while C < FMapCols do
  begin
    // Safe starting area
    if C < 10 then
    begin
      FTiles[FloorLevel * FMapCols + C].TileType := ttGrass;
      FTiles[FloorLevel * FMapCols + C].Solid := True;
      Inc(C); Continue;
    end;

    // Create gap with moving platform
    if (C > LastGapEnd + 10) and (Random(30) = 0) then
    begin
      GapLen := 6 + Random(4);
      for var GL := 0 to GapLen do
        if (C + GL) < FMapCols then
        begin
          FTiles[FloorLevel * FMapCols + C + GL].TileType := ttEmpty;
          FTiles[FloorLevel * FMapCols + C + GL].Solid := False;
        end;

      Plat.StartX := C * TILE_SIZE;
      Plat.EndX := Plat.StartX + (GapLen * TILE_SIZE) - 96;
      if Plat.EndX < Plat.StartX then Plat.EndX := Plat.StartX + 20;

      PlatformY := FloorLevel - 3;
      if PlatformY < 2 then PlatformY := 2;

      Plat.Pos := PointF(Plat.StartX, PlatformY * TILE_SIZE);
      Plat.Width := 96;
      Plat.Height := 16;
      Plat.Speed := 50 + Random(30);
      Plat.Direction := 1;
      FPlatforms.Add(Plat);

      LastGapEnd := C + GapLen;
      C := C + GapLen;
    end
    else
    begin
      // Solid ground
      FTiles[FloorLevel * FMapCols + C].TileType := ttGrass;
      FTiles[FloorLevel * FMapCols + C].Solid := True;

      if (C > 15) and (Random(20) = 0) then
      begin
        Enemy.Pos := PointF(C * TILE_SIZE, (FloorLevel - 1) * TILE_SIZE);
        Enemy.Origin := Enemy.Pos;
        Enemy.Vel := PointF(20 + Random(20), 0);
        Enemy.Width := 28; Enemy.Height := 28;
        Enemy.Phase := Random(100);
        Enemy.EnemyType := etWalker;
        Enemy.MaxHealth := 2; Enemy.Health := 2;
        Enemy.ShootCooldown := 2.0 + Random(20) / 10;
        Enemy.HitFlash := 0;
        FEnemies.Add(Enemy);
      end;

      if (C > 20) and (Random(40) = 0) then
      begin
        Enemy.Pos := PointF(C * TILE_SIZE, (FloorLevel - 1) * TILE_SIZE);
        Enemy.Origin := Enemy.Pos;
        Enemy.Vel := PointF(0, 0);
        Enemy.Width := 32; Enemy.Height := 20;
        Enemy.Phase := Random(100);
        Enemy.EnemyType := etDog;
        Enemy.MaxHealth := 3; Enemy.Health := 3;
        Enemy.ShootCooldown := 0;
        Enemy.HitFlash := 0;
        FEnemies.Add(Enemy);
      end;

      // Conveyor belts
      if (C > 20) and (Random(40) = 0) then
      begin
        var BeltLen := 3 + Random(4);
        var BeltDir: TTileType;
        if Random(2) = 0 then BeltDir := ttConveyorLeft else BeltDir := ttConveyorRight;
        for var BL := 0 to BeltLen do
        begin
          if (C + BL < FMapCols) then
          begin
            FTiles[FloorLevel * FMapCols + C + BL].TileType := BeltDir;
            FTiles[FloorLevel * FMapCols + C + BL].Solid := True;
          end;
        end;
        C := C + BeltLen;
      end;

      Inc(C);
    end;
  end;

  // Floating platforms, pickups, flyers
  PlatformX := 15;
  while PlatformX < FMapCols - 10 do
  begin
    PlatformX := PlatformX + 5 + Random(5);
    PlatformY := FloorLevel - (3 + Random(3));
    if PlatformY < 2 then PlatformY := 2;
    PLen := 2 + Random(2);
    IsAboveGap := False;

    for var P := 0 to PLen do
      if (PlatformX + P < FMapCols) and not FTiles[FloorLevel * FMapCols + PlatformX + P].Solid then
      begin
        IsAboveGap := True; Break;
      end;

    if not IsAboveGap then
    begin
      for var P := 0 to PLen do
        if (PlatformX + P < FMapCols) then
        begin
          FTiles[PlatformY * FMapCols + PlatformX + P].TileType := ttStone;
          FTiles[PlatformY * FMapCols + PlatformX + P].Solid := True;
        end;

      if Random(3) = 0 then
      begin
        Item.Pos := PointF((PlatformX + 1) * TILE_SIZE, (PlatformY - 1) * TILE_SIZE);
        if Random(4) = 0 then Item.Kind := dtUpgradeDmg
        else if Random(5) = 0 then Item.Kind := dtUpgradeHP
        else Item.Kind := dtCrate;
        FDecor.Add(Item);
      end;

      if Random(4) = 0 then
      begin
        Enemy.Pos := PointF((PlatformX + 1) * TILE_SIZE, (PlatformY - 3) * TILE_SIZE);
        Enemy.Origin := Enemy.Pos;
        Enemy.Vel := PointF(0, 0);
        Enemy.Width := 24; Enemy.Height := 24;
        Enemy.Phase := Random(100);
        Enemy.EnemyType := etFlyer;
        Enemy.MaxHealth := 1; Enemy.Health := 1;
        Enemy.ShootCooldown := 0;
        Enemy.HitFlash := 0;
        FEnemies.Add(Enemy);
      end;
    end;
  end;

  FGate.Pos := PointF((FMapCols - 15) * TILE_SIZE, (FloorLevel - 2) * TILE_SIZE);
  FGate.Width := 64; FGate.Height := 96; FGate.Phase := 0;
  FPlayer.Pos := PointF(100, (FloorLevel - 1) * TILE_SIZE - FPlayer.Height);
  FCheckpointPos := FPlayer.Pos;
end;

procedure TMegaCatlingGame.GenerateBackgroundElements;
var
  I: Integer;
begin
  SetLength(FBgPlanets, 4);
  for I := 0 to High(FBgPlanets) do
    FBgPlanets[I] := PointF(Random(1500) + 200, Random(250) + 50);

  SetLength(FBgRings, 2);
  for I := 0 to High(FBgRings) do
    FBgRings[I] := PointF(Random(1500) + 300, Random(200) + 50);

  SetLength(FBgDrones, 10);
  for I := 0 to High(FBgDrones) do
    FBgDrones[I] := PointF(Random(FMapCols * TILE_SIZE * 2), Random(400));
end;

procedure TMegaCatlingGame.UpdateCamera;
var
  ScreenWidth, ScreenHeight, TargetX, TargetY: Single;
begin
  if FDeadTime > 0 then Exit;

  ScreenWidth := RENDER_WIDTH;
  ScreenHeight := RENDER_HEIGHT;

  TargetX := FPlayer.Pos.X - (ScreenWidth * 0.4);
  FCameraX := FCameraX + (TargetX - FCameraX) * 0.15; // Smoother scroll

  if FCameraX < 0 then FCameraX := 0;
  if FCameraX > (FMapCols * TILE_SIZE) - ScreenWidth then
    FCameraX := (FMapCols * TILE_SIZE) - ScreenWidth;

  TargetY := FPlayer.Pos.Y - (ScreenHeight * 0.6);
  FCameraY := FCameraY + (TargetY - FCameraY) * 0.08; // Smoother scroll

  if FCameraY < 0 then FCameraY := 0;
  if FCameraY > (FMapRows * TILE_SIZE) - ScreenHeight then
    FCameraY := (FMapRows * TILE_SIZE) - ScreenHeight;
end;

procedure TMegaCatlingGame.SpawnExplosion(const X, Y: Single; Color: TAlphaColor);
var
  I: Integer;
  P: TParticle;
begin
  if FParticles.Count >= MAX_PARTICLES then Exit;

  for I := 0 to 12 do
  begin
    if FParticles.Count >= MAX_PARTICLES then Break;
    P.Pos := PointF(X, Y);
    P.Vel := PointF((Random - 0.5) * 400, (Random - 0.5) * 400 - 100);
    P.Life := 0.8;
    P.Color := Color;
    P.Size := 4 + Random * 4;
    FParticles.Add(P);
  end;
end;

procedure TMegaCatlingGame.UpdatePlatforms(DeltaSec: Double);
var
  I: Integer;
  Plat: TMovingPlatform;
begin
  for I := 0 to FPlatforms.Count - 1 do
  begin
    Plat := FPlatforms[I];
    Plat.Pos.X := Plat.Pos.X + (Plat.Speed * Plat.Direction * DeltaSec);

    if Plat.Pos.X > Plat.EndX then Plat.Direction := -1;
    if Plat.Pos.X < Plat.StartX then Plat.Direction := 1;

    FPlatforms[I] := Plat;
  end;
end;

procedure TMegaCatlingGame.CheckCrateCollisions;
var
  I: Integer;
  Item: TDecorItem;
  R: TRectF;
begin
  if FGameState <> gsPlaying then Exit;
  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y, FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);

  for I := FDecor.Count - 1 downto 0 do
  begin
    Item := FDecor[I];
    if R.IntersectsWith(TRectF.Create(Item.Pos.X + 2, Item.Pos.Y + 2, Item.Pos.X + 30, Item.Pos.Y + 30)) then
    begin
      case Item.Kind of
        dtCrate: begin
            SpawnExplosion(Item.Pos.X + 16, Item.Pos.Y + 16, TAlphaColors.Orange);
            Inc(FScore, 10);
            PlayEffect(afCrate);
          end;
        dtUpgradeDmg: begin
            SpawnExplosion(Item.Pos.X + 16, Item.Pos.Y + 16, TAlphaColors.Lime);
            FDamageBoostTimer := 10.0;
            Inc(FScore, 50);
            PlayEffect(afUpgrade);
          end;
        dtUpgradeHP: begin
            SpawnExplosion(Item.Pos.X + 16, Item.Pos.Y + 16, TAlphaColors.Red);
            if FPlayerHP < 3 then Inc(FPlayerHP);
            Inc(FScore, 50);
            PlayEffect(afUpgrade);
          end;
      end;
      FDecor.Delete(I);
    end;
  end;
end;

procedure TMegaCatlingGame.CheckGateCollision;
var
  R, R2: TRectF;
begin
  if FGameState <> gsPlaying then Exit;
  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y, FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);
  R2 := TRectF.Create(FGate.Pos.X, FGate.Pos.Y, FGate.Pos.X + FGate.Width, FGate.Pos.Y + FGate.Height);

  if R.IntersectsWith(R2) then
  begin
    FGameState := gsWin;
    FWinTime := 2.0;
    SpawnExplosion(FGate.Pos.X + FGate.Width / 2, FGate.Pos.Y + FGate.Height / 2, TAlphaColors.Cyan);
    PlayEffect(afPortal);
  end;
end;

procedure TMegaCatlingGame.CheckEnemyCollisions;
var
  I: Integer;
  E: TEnemy;
  R, R2: TRectF;
begin
  if (FGameState <> gsPlaying) or (FInvincibilityTimer > 0) then Exit;

  R := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y, FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);

  for I := FEnemies.Count - 1 downto 0 do
  begin
    E := FEnemies[I];
    R2 := TRectF.Create(E.Pos.X, E.Pos.Y, E.Pos.X + E.Width, E.Pos.Y + E.Height);

    if R.IntersectsWith(R2) then
    begin
      Dec(FPlayerHP);
      FInvincibilityTimer := 1.5;
      SpawnExplosion((R.Left + R.Right) / 2, (R.Top + R.Bottom) / 2, TAlphaColors.Red);
      PlayEffect(afDie);

      if FPlayerHP <= 0 then
      begin
        FGameState := gsDead;
        FDeadTime := 1.5;
        FPlayer.Pos.X := -1000; // Move player off-screen
        FPlayer.Vel.X := 0;
        FPlayer.Vel.Y := 0;

        for var J := 0 to FEnemies.Count - 1 do
        begin
          var ResetEnemy := FEnemies[J];
          ResetEnemy.Vel := PointF(0,0);
          ResetEnemy.ShootCooldown := 5.0;
          FEnemies[J] := ResetEnemy;
        end;
      end;
      Exit;
    end;
  end;
end;

// Enemy AI logic for Walkers, Flyers, and Dogs
procedure TMegaCatlingGame.UpdateEnemies(DeltaSec: Double);
var
  I: Integer;
  E: TEnemy;
  FloorLevel: Integer;
  B: TBullet;
  DistX, DistY: Single;
  CullLeft, CullRight, AggroRange: Single;
begin
  FloorLevel := FMapRows - 4;

  // Culling bounds for performance
  CullLeft := FCameraX - RENDER_WIDTH * 0.75;
  CullRight := FCameraX + RENDER_WIDTH * 1.75;
  AggroRange := 600;

  for I := FEnemies.Count - 1 downto 0 do
  begin
    E := FEnemies[I];
    if (E.Pos.X < CullLeft) or (E.Pos.X > CullRight) then Continue;

    E.Phase := E.Phase + DeltaSec * 5;
    if E.HitFlash > 0 then E.HitFlash := E.HitFlash - DeltaSec * 5;

    DistX := FPlayer.Pos.X - E.Pos.X;
    DistY := FPlayer.Pos.Y - E.Pos.Y;

    if E.EnemyType = etWalker then
    begin
      E.Pos.X := E.Pos.X + E.Vel.X * DeltaSec;
      E.Pos.Y := E.Pos.Y + 15 * DeltaSec; // Slight gravity

      if IsSolidTile(FTiles, FMapCols, FMapRows, E.Pos.X + E.Width / 2, E.Pos.Y + E.Height) then
      begin
        E.Pos.Y := Trunc((E.Pos.Y + E.Height) / TILE_SIZE) * TILE_SIZE - E.Height;

        // Turn around at walls or ledges
        if IsSolidTile(FTiles, FMapCols, FMapRows, E.Pos.X + E.Width / 2 + Sign(E.Vel.X) * (E.Width/2 + 2), E.Pos.Y + E.Height / 2) then
          E.Vel.X := -E.Vel.X;
        if not IsSolidTile(FTiles, FMapCols, FMapRows, E.Pos.X + E.Width / 2 + Sign(E.Vel.X) * (E.Width/2 + 5), E.Pos.Y + E.Height + 5) then
          E.Vel.X := -E.Vel.X;
      end;

      // Shooting logic
      if (Abs(DistX) < 400) and (Abs(DistX) < AggroRange) and (Sign(DistX) = Sign(E.Vel.X)) then
      begin
        E.ShootCooldown := E.ShootCooldown - DeltaSec;
        if E.ShootCooldown <= 0 then
        begin
          E.ShootCooldown := 2.5 + Random(10) / 10;
          B.Pos := PointF(E.Pos.X + E.Width/2, E.Pos.Y + E.Height/2);
          B.Vel := PointF(Sign(E.Vel.X) * 300, 0);
          B.Life := 3.0;
          B.IsPlayerBullet := False;
          B.Damage := 1;
          FBullets.Add(B);
        end;
      end;
    end
    else if E.EnemyType = etFlyer then
    begin
      // Passive AI: Maintains distance
      if (Abs(DistY) < 30) and (Abs(DistX) < 200) and (Abs(DistX) < AggroRange) then
      begin
        if Abs(DistX) > 50 then
        begin
          if DistX > 0 then E.Pos.X := E.Pos.X + 20 * DeltaSec
          else E.Pos.X := E.Pos.X - 20 * DeltaSec;
        end;
        E.Pos.Y := E.Origin.Y + Sin(E.Phase * 2) * 5; // Hover effect
      end
      else
      begin
        // Return to spawn if player escapes
        if E.Pos.X < E.Origin.X - 5 then E.Pos.X := E.Pos.X + 10 * DeltaSec
        else if E.Pos.X > E.Origin.X + 5 then E.Pos.X := E.Pos.X - 10 * DeltaSec;
        E.Pos.Y := E.Origin.Y + Sin(E.Phase * 1.5) * 10;
      end;
    end
    else if E.EnemyType = etDog then
    begin
      // Aggressive charger
      if (Abs(DistX) < 300) and (Abs(DistX) < AggroRange) then
      begin
        E.Vel.X := Sign(DistX) * 120;
        if E.Vel.X > 0 then E.Pos.X := E.Pos.X + 2; // Lunge animation offset
      end
      else
        E.Vel.X := 0;

      E.Pos.X := E.Pos.X + E.Vel.X * DeltaSec;
      E.Pos.Y := E.Pos.Y + 15 * DeltaSec;

      if IsSolidTile(FTiles, FMapCols, FMapRows, E.Pos.X + E.Width / 2, E.Pos.Y + E.Height) then
        E.Pos.Y := Trunc((E.Pos.Y + E.Height) / TILE_SIZE) * TILE_SIZE - E.Height;
    end;

    // Despawn if falling out of bounds
    if E.Pos.Y > (FMapRows * TILE_SIZE) then
    begin
      SpawnExplosion(E.Pos.X + E.Width / 2, E.Pos.Y, TAlphaColors.Purple);
      FEnemies.Delete(I);
      Continue;
    end;

    FEnemies[I] := E;
  end;
end;

procedure TMegaCatlingGame.UpdateBullets(DeltaSec: Double);
var
  I: Integer;
  B: TBullet;
begin
  for I := FBullets.Count - 1 downto 0 do
  begin
    B := FBullets[I];
    B.Pos.X := B.Pos.X + B.Vel.X * DeltaSec;
    B.Pos.Y := B.Pos.Y + B.Vel.Y * DeltaSec;
    B.Life := B.Life - DeltaSec;

    if IsSolidTile(FTiles, FMapCols, FMapRows, B.Pos.X, B.Pos.Y) then
    begin
      SpawnExplosion(B.Pos.X, B.Pos.Y, TAlphaColors.Yellow);
      FBullets.Delete(I);
      Continue;
    end;

    if B.Life <= 0 then FBullets.Delete(I) else FBullets[I] := B;
  end;
end;

procedure TMegaCatlingGame.CheckBulletCollisions;
var
  I, J: Integer;
  B: TBullet;
  E: TEnemy;
  R1, R2: TRectF;
begin
  for I := FBullets.Count - 1 downto 0 do
  begin
    B := FBullets[I];
    R1 := TRectF.Create(B.Pos.X - 4, B.Pos.Y - 4, B.Pos.X + 4, B.Pos.Y + 4);

    // Enemy bullets hitting player
    if not B.IsPlayerBullet then
    begin
      if FInvincibilityTimer <= 0 then
      begin
        R2 := TRectF.Create(FPlayer.Pos.X, FPlayer.Pos.Y, FPlayer.Pos.X + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height);
        if R1.IntersectsWith(R2) then
        begin
          SpawnExplosion(B.Pos.X, B.Pos.Y, TAlphaColors.Red);
          FBullets.Delete(I);
          Dec(FPlayerHP);
          FInvincibilityTimer := 1.5;
          PlayEffect(afDie);

          if FPlayerHP <= 0 then
          begin
            FGameState := gsDead;
            FDeadTime := 1.5;
            FPlayer.Pos.X := -1000;
          end;
          Continue;
        end;
      end;
    end;

    // Player bullets hitting enemies
    if B.IsPlayerBullet then
    begin
      for J := FEnemies.Count - 1 downto 0 do
      begin
        E := FEnemies[J];
        R2 := TRectF.Create(E.Pos.X, E.Pos.Y, E.Pos.X + E.Width, E.Pos.Y + E.Height);
        if R1.IntersectsWith(R2) then
        begin
          E.Health := E.Health - B.Damage;
          E.HitFlash := 1.0;
          FEnemies[J] := E;

          SpawnExplosion(B.Pos.X, B.Pos.Y, TAlphaColors.Yellow);
          FBullets.Delete(I);

          if E.Health <= 0 then
          begin
            SpawnExplosion(E.Pos.X + E.Width/2, E.Pos.Y + E.Height/2, TAlphaColors.Orange);
            FEnemies.Delete(J);
            Inc(FScore, 100);
            PlayEffect(afExplosion);
          end;
          Break;
        end;
      end;
    end;
  end;
end;

procedure TMegaCatlingGame.UpdateParticles(DeltaTime: Single);
var
  I: Integer;
  P: TParticle;
  Center: TPointF;
  CullLeft, CullRight: Single;
begin
  Center := PointF(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y + FPlayer.Height);
  CullLeft := FCameraX - 200;
  CullRight := FCameraX + RENDER_WIDTH + 200;

  // Spawn running dust
  if (FPlayer.State = bsGround) and (Abs(FPlayer.Vel.X) > 0.5) then
  begin
    if Random(6) = 0 then
    begin
      P.Pos := Center + PointF(0, FPlayer.Height / 2 - 29);
      P.Vel := PointF(-FPlayer.Vel.X * 0.5, -5 - Random * 5);
      P.Life := 0.6;
      P.Color := TAlphaColors.White;
      P.Size := 3 + Random * 2;
      FParticles.Add(P);
    end;
  end;

  for I := FParticles.Count - 1 downto 0 do
  begin
    P := FParticles[I];
    P.Pos.X := P.Pos.X + P.Vel.X * DeltaTime;
    P.Pos.Y := P.Pos.Y + P.Vel.Y * DeltaTime;
    P.Life := P.Life - (0.8 * DeltaTime);

    if P.Life <= 0 then
      FParticles.Delete(I)
    else
      FParticles[I] := P;
  end;
end;

// Main physics and game logic loop
procedure TMegaCatlingGame.DoPhysicsUpdate(DeltaSec: Double);
var
  Left, Right, Jump, Shoot, Crouch: Boolean;
  AccelThisFrame, NextY, FloorLevel, NextX: Single;
  B: TBullet;
  TileUnder: TTileType;
  Plat: TMovingPlatform;
  R, R2: TRectF;
  I: Integer;
  P: TParticle;
  OnWall: Boolean;
  PlatformDX: Single;
begin
  if not FActive then Exit;

  if FGameState = gsLoading then
  begin
    FLoadingTimer := FLoadingTimer - DeltaSec;
    if FLoadingTimer <= 0 then
      FGameState := gsPlaying;
    Exit;
  end;

  if FGameState = gsTitle then
  begin
    if FTitleFadingOut then
    begin
      FTitleAlpha := Max(0.0, FTitleAlpha - DeltaSec * 1.5);
      if FTitleAlpha <= 0 then FGameState := gsPlaying;
    end;
    UpdateParticles(DeltaSec);
    Exit;
  end;

  if FMenuTargetActive then
    FMenuAlpha := Min(1.0, FMenuAlpha + DeltaSec * 5)
  else
    FMenuAlpha := Max(0.0, FMenuAlpha - DeltaSec * 5);

  if FMenuAlpha >= 0.5 then Exit;

  if FInvincibilityTimer > 0 then
    FInvincibilityTimer := FInvincibilityTimer - DeltaSec;

  if FGameState = gsWin then
  begin
    FWinTime := FWinTime - DeltaSec;
    FGate.Phase := FGate.Phase + DeltaSec * 20;
    if FWinTime <= 0 then
    begin
      Inc(FLevel);
      FPlayerHP := 3;
      GenerateProceduralMap;
      GenerateBackgroundElements;
      FGameState := gsLoading;
      FLoadingTimer := 1.0;
    end;
    Exit;
  end;

  if FGameState = gsDead then
  begin
    FDeadTime := FDeadTime - DeltaSec;
    UpdateParticles(DeltaSec);
    if FDeadTime <= 0 then
    begin
      FGameState := gsPlaying;
      FPlayer.Pos := FCheckpointPos;
      FPlayer.Vel.X := 0;
      FPlayer.Vel.Y := 0;
      FPlayer.JumpCount := 0;
      FPlayer.State := bsAir;
      FPlayerHP := 3;
      FInvincibilityTimer := 2.0;
    end;
    Exit;
  end;

  UpdatePlatforms(DeltaSec);

  if FPlayer.State = bsGround then
  begin
    FCheckpointTimer := FCheckpointTimer - DeltaSec;
    if FCheckpointTimer <= 0 then
    begin
      FCheckpointTimer := 2.0;
      FCheckpointPos := FPlayer.Pos;
    end;
  end;

  FloorLevel := FMapRows - 4;

  // Thread-safe input handling
  FLock.Acquire;
  try
    Left := Byte(vkLeft) in FKeys;
    Right := Byte(vkRight) in FKeys;
    Jump := FJumpPressed;
    Shoot := Byte(VK_SHOOT) in FKeys;
    Crouch := Byte(vkDown) in FKeys;
  finally
    FLock.Release;
  end;

  FCrouching := Crouch and (FPlayer.State = bsGround);

  if Left then FLookDir := -1
  else if Right then FLookDir := 1;

  FFireCooldown := FFireCooldown - DeltaSec;
  FDamageBoostTimer := FDamageBoostTimer - DeltaSec;
  FPlayer.Squash := FPlayer.Squash - DeltaSec * 5;
  if FPlayer.Squash < 0 then FPlayer.Squash := 0;
  FPlayer.JumpCooldown := FPlayer.JumpCooldown - DeltaSec;

  // Shooting logic
  if Shoot and (FFireCooldown <= 0) then
  begin
    if FCrouching then
      B.Pos := PointF(FPlayer.Pos.X + (FPlayer.Width / 2) - (8 * FLookDir), FPlayer.Pos.Y + FPlayer.Height - 14)
    else
      B.Pos := PointF(FPlayer.Pos.X + (FPlayer.Width / 2) - (8 * FLookDir), FPlayer.Pos.Y + (FPlayer.Height * 0.5));

    B.Vel := PointF(FLookDir * 600, 0);
    B.Life := 1.5;
    B.IsPlayerBullet := True;

    if FDamageBoostTimer > 0 then
    begin
      B.Damage := 2;
      B.Vel.X := B.Vel.X * 1.2;
    end
    else
      B.Damage := 1;

    FBullets.Add(B);
    FFireCooldown := 0.2;
    PlayEffect(afShoot);
  end;

  // Horizontal movement
  AccelThisFrame := ACCEL * DeltaSec;
  if FCrouching then
    AccelThisFrame := AccelThisFrame * 0.4;

  if Left then
    FPlayer.Vel.X := Max(FPlayer.Vel.X - AccelThisFrame, -MAX_SPEED)
  else if Right then
    FPlayer.Vel.X := Min(FPlayer.Vel.X + AccelThisFrame, MAX_SPEED)
  else
  begin
    FPlayer.Vel.X := FPlayer.Vel.X * 0.85;
    if Abs(FPlayer.Vel.X) < 0.1 then FPlayer.Vel.X := 0;
  end;

  FBraking := (Abs(FPlayer.Vel.X) > 0.5) and (((FPlayer.Vel.X > 0) and Left) or ((FPlayer.Vel.X < 0) and Right));

  // Conveyor belts
  if FPlayer.State = bsGround then
  begin
    TileUnder := GetTileType(FTiles, FMapCols, FMapRows, FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y + FPlayer.Height + 1);
    if TileUnder = ttConveyorLeft then FPlayer.Pos.X := FPlayer.Pos.X - 40 * DeltaSec;
    if TileUnder = ttConveyorRight then FPlayer.Pos.X := FPlayer.Pos.X + 40 * DeltaSec;
  end;

  // Jumping (Ground, Wall, Double Jump)
  if Jump and (FPlayer.JumpCooldown <= 0) then
  begin
    if FPlayer.State = bsGround then
    begin
      FPlayer.Vel.Y := JUMP_FORCE;
      FPlayer.State := bsAir;
      FPlayer.JumpCount := 1;
      FCrouching := False;
      FPlayer.Squash := 0.6;
      FPlayer.JumpCooldown := 0.2;
      FJumpPressed := False;
      PlayEffect(afJump);
    end
    else if FPlayer.State = bsWall then
    begin
      FPlayer.Vel.Y := JUMP_FORCE * 0.9;
      FPlayer.Vel.X := -FLookDir * MAX_SPEED * 1.5;
      FLookDir := -FLookDir;
      FPlayer.State := bsAir;
      FPlayer.JumpCount := 1;
      FPlayer.Squash := 0.6;
      FPlayer.JumpCooldown := 0.2;
      FJumpPressed := False;
      PlayEffect(afJump);
    end
    else if (FPlayer.State = bsAir) and (FPlayer.JumpCount < 2) then
    begin
      FPlayer.Vel.Y := JUMP_FORCE * 0.85;
      FPlayer.JumpCount := 2;
      FPlayer.Squash := 0.6;
      FPlayer.JumpCooldown := 0.2;
      FJumpPressed := False;

      for I := 0 to 5 do
      begin
        if FParticles.Count >= MAX_PARTICLES then Break;
        P.Pos := PointF(FPlayer.Pos.X + FPlayer.Width/2, FPlayer.Pos.Y + FPlayer.Height);
        P.Vel := PointF((Random - 0.5) * 100, 50);
        P.Life := 0.5;
        P.Color := TAlphaColors.Cyan;
        P.Size := 3;
        FParticles.Add(P);
      end;
      PlayEffect(afJump);
    end
    else
      FJumpPressed := False;
  end;

  // Gravity & Wall Sliding
  if FPlayer.State <> bsGround then
  begin
    OnWall := False;
    if FPlayer.State = bsAir then
    begin
      if IsSolidTile(FTiles, FMapCols, FMapRows, FPlayer.Pos.X + FPlayer.Width + 2, FPlayer.Pos.Y + FPlayer.Height / 2) then
      begin
        OnWall := True;
        FLookDir := 1;
      end
      else if IsSolidTile(FTiles, FMapCols, FMapRows, FPlayer.Pos.X - 2, FPlayer.Pos.Y + FPlayer.Height / 2) then
      begin
        OnWall := True;
        FLookDir := -1;
      end;

      if OnWall and (FPlayer.Vel.Y > 0) then
      begin
        FPlayer.State := bsWall;
        FPlayer.JumpCount := 1;
      end;
    end;

    if FPlayer.State = bsWall then
    begin
      // Reset squash/stretch immediately to prevent graphic glitching on the wall
      FPlayer.Squash := 0;

      FPlayer.Vel.Y := FPlayer.Vel.Y + (GRAVITY * 0.3) * DeltaSec;
      if FPlayer.Vel.Y > 5.0 then FPlayer.Vel.Y := 5.0;
    end
    else
    begin
      FPlayer.Vel.Y := FPlayer.Vel.Y + GRAVITY * DeltaSec;
    end;
  end;

  // Collision Detection: X Axis
  NextX := FPlayer.Pos.X + FPlayer.Vel.X * TILE_SIZE * DeltaSec;
  if NextX < 0 then NextX := 0;
  if NextX > FMapCols * TILE_SIZE - FPlayer.Width then
    NextX := FMapCols * TILE_SIZE - FPlayer.Width;

  if IsSolidTile(FTiles, FMapCols, FMapRows, NextX, FPlayer.Pos.Y + 5) or
     IsSolidTile(FTiles, FMapCols, FMapRows, NextX, FPlayer.Pos.Y + FPlayer.Height - 5) or
     IsSolidTile(FTiles, FMapCols, FMapRows, NextX + FPlayer.Width, FPlayer.Pos.Y + 5) or
     IsSolidTile(FTiles, FMapCols, FMapRows, NextX + FPlayer.Width, FPlayer.Pos.Y + FPlayer.Height - 5) then
  begin
    FPlayer.Vel.X := 0;
    if FPlayer.State = bsAir then FPlayer.State := bsWall;
  end
  else
  begin
    FPlayer.Pos.X := NextX;
    if FPlayer.State = bsWall then FPlayer.State := bsAir;
  end;

  // Moving Platform Collision
  if FPlayer.Vel.Y >= 0 then
  begin
    for I := 0 to FPlatforms.Count - 1 do
    begin
      Plat := FPlatforms[I];
      if (FPlayer.Pos.X + FPlayer.Width > Plat.Pos.X) and (FPlayer.Pos.X < Plat.Pos.X + Plat.Width) then
      begin
        if (FPlayer.Pos.Y + FPlayer.Height >= Plat.Pos.Y - 1) and (FPlayer.Pos.Y + FPlayer.Height <= Plat.Pos.Y + 15) then
        begin
          FPlayer.Pos.Y := Plat.Pos.Y - FPlayer.Height;
          FPlayer.Vel.Y := 0;
          FPlayer.State := bsGround;
          FPlayer.JumpCount := 0;

          PlatformDX := Plat.Speed * Plat.Direction * DeltaSec;
          FPlayer.Pos.X := FPlayer.Pos.X + PlatformDX;
          Break;
        end;
      end;
    end;
  end;

  // Collision Detection: Y Axis
  NextY := FPlayer.Pos.Y + FPlayer.Vel.Y * TILE_SIZE * DeltaSec;
  if IsSolidTile(FTiles, FMapCols, FMapRows, FPlayer.Pos.X + FPlayer.Width / 2, NextY + FPlayer.Height) then
  begin
    if (FPlayer.Vel.Y > 0) or (FPlayer.State = bsAir) then
    begin
      FPlayer.Squash := 0.4; // Landing squish
      FPlayer.JumpCooldown := 0.1;
    end;
    FPlayer.Pos.Y := Trunc((NextY + FPlayer.Height) / TILE_SIZE) * TILE_SIZE - FPlayer.Height;
    FPlayer.Vel.Y := 0;
    FPlayer.State := bsGround;
    FPlayer.JumpCount := 0;
  end
  else if IsSolidTile(FTiles, FMapCols, FMapRows, FPlayer.Pos.X + FPlayer.Width / 2, NextY) then
  begin
    FPlayer.Pos.Y := (Trunc(NextY / TILE_SIZE) + 1) * TILE_SIZE;
    FPlayer.Vel.Y := 0;
  end
  else
  begin
    FPlayer.Pos.Y := NextY;
    if FPlayer.State = bsGround then FPlayer.State := bsAir;
  end;

  if FPlayer.Pos.Y > (FMapRows * TILE_SIZE) then
  begin
    SpawnExplosion(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y, TAlphaColors.Red);
    FGameState := gsDead;
    FDeadTime := 1.5;
    FPlayer.Pos.X := -1000;
    FPlayer.Vel.X := 0;
    FPlayer.Vel.Y := 0;
    PlayEffect(afDie);
    Exit;
  end;

  CheckCrateCollisions;
  CheckEnemyCollisions;
  CheckGateCollision;
  UpdateEnemies(DeltaSec);
  UpdateBullets(DeltaSec);
  CheckBulletCollisions;
  UpdateParticles(DeltaSec);
  UpdateCamera;
end;

// ============================================================================
// RENDERING METHODS
// ============================================================================

procedure TMegaCatlingGame.DrawUI(const ACanvas: ISkCanvas);
var
  Font: ISkFont;
  Paint: ISkPaint;
  Txt: string;
  I: Integer;
  HeartRect: TRectF;
begin
  Txt := 'Score: ' + IntToStr(FScore) + ' | Level: ' + IntToStr(FLevel);
  if FDamageBoostTimer > 0 then
    Txt := Txt + ' [DMG: ' + IntToStr(Trunc(FDamageBoostTimer)) + 's]';

  Font := TSkFont.Create(nil, 18);
  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.AntiAlias := True;

  Paint.Color := TAlphaColors.Black;
  Paint.Alpha := 150;
  ACanvas.DrawSimpleText(Txt, 12, 32, Font, Paint);

  Paint.Color := TAlphaColors.Lime;
  Paint.Alpha := 255;
  ACanvas.DrawSimpleText(Txt, 10, 30, Font, Paint);

  for I := 0 to 2 do
  begin
    HeartRect := TRectF.Create(10 + (I * 26), 40, 30 + (I * 26), 60);
    if I < FPlayerHP then
      Paint.Color := TAlphaColors.Red
    else
      Paint.Color := $FF333333;

    ACanvas.DrawCircle(PointF(HeartRect.CenterPoint.X - 5, HeartRect.CenterPoint.Y - 3), 6, Paint);
    ACanvas.DrawCircle(PointF(HeartRect.CenterPoint.X + 5, HeartRect.CenterPoint.Y - 3), 6, Paint);
    ACanvas.DrawRect(TRectF.Create(HeartRect.CenterPoint.X - 10, HeartRect.CenterPoint.Y - 3, HeartRect.CenterPoint.X + 10, HeartRect.CenterPoint.Y + 10), Paint);

    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 1.5;
    Paint.Color := TAlphaColors.White;
    ACanvas.DrawCircle(PointF(HeartRect.CenterPoint.X - 5, HeartRect.CenterPoint.Y - 3), 6, Paint);
    ACanvas.DrawCircle(PointF(HeartRect.CenterPoint.X + 5, HeartRect.CenterPoint.Y - 3), 6, Paint);
    ACanvas.DrawRect(TRectF.Create(HeartRect.CenterPoint.X - 10, HeartRect.CenterPoint.Y - 3, HeartRect.CenterPoint.X + 10, HeartRect.CenterPoint.Y + 10), Paint);
    Paint.Style := TSkPaintStyle.Fill;
  end;
end;

procedure TMegaCatlingGame.DrawBackgrounds(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  Paint, BlurPaint: ISkPaint;
  Colors: TArray<TAlphaColor>;
  I: Integer;
  ParallaxX1, ParallaxX2, ParallaxX3: Single;
  PosX, PosY: Single;
begin
  Colors := [$FF05010F, $FF0A0420, $FF1A0B35];
  Paint := TSkPaint.Create;
  Paint.Shader := TSkShader.MakeGradientLinear(PointF(0, 0), PointF(0, ADest.Height), Colors, nil, TSkTileMode.Clamp);
  ACanvas.DrawPaint(Paint);
  Paint.Shader := nil;

  ParallaxX1 := -FCameraX * 0.05;
  ParallaxX2 := -FCameraX * 0.15;
  ParallaxX3 := -FCameraX * 0.4;

  Paint.AntiAlias := True;
  Paint.Style := TSkPaintStyle.Fill;
  BlurPaint := TSkPaint.Create(Paint);
  BlurPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal, 4.0);

  for I := 0 to High(FBgRings) do
  begin
    PosX := FBgRings[I].X + ParallaxX1;
    PosY := FBgRings[I].Y;
    if PosX < -300 then PosX := PosX + 2000;
    if PosX > ADest.Width + 300 then Continue;
    BlurPaint.Color := $55AA00FF;
    ACanvas.DrawOval(TRectF.Create(PosX - 100, PosY - 25, PosX + 100, PosY + 25), BlurPaint);
  end;

  for I := 0 to High(FBgPlanets) do
  begin
    PosX := FBgPlanets[I].X + ParallaxX1;
    PosY := FBgPlanets[I].Y;
    if PosX < -200 then PosX := PosX + 2000;
    if PosX > ADest.Width + 200 then Continue;
    BlurPaint.Color := $FF8A2BE2;
    ACanvas.DrawCircle(PointF(PosX, PosY), 60, BlurPaint);
    BlurPaint.Color := $FF4B0082;
    ACanvas.DrawCircle(PointF(PosX - 10, PosY - 10), 50, BlurPaint);
  end;

  Paint.Color := $FF0F0716;
  for I := 0 to 10 do
  begin
    PosX := (I * 150) + ParallaxX2;
    PosY := ADest.Height;
    var H := 120 + (I * 37 mod 80);
    ACanvas.DrawRect(RectF(PosX, PosY - H, PosX + 80, PosY), Paint);
    BlurPaint.Color := $FFFF00FF;
    ACanvas.DrawCircle(PointF(PosX + 40, PosY - H - 10), 4, BlurPaint);
  end;

  for I := 0 to High(FBgDrones) do
  begin
    PosX := FBgDrones[I].X + ParallaxX3;
    PosY := FBgDrones[I].Y + Sin(FAnimPhase * 2 + I) * 10;
    if PosX < -50 then PosX := PosX + (FMapCols * TILE_SIZE);
    if PosX > ADest.Width + 50 then Continue;
    Paint.Color := $FF00FFFF;
    ACanvas.DrawCircle(PointF(PosX, PosY), 4, Paint);
    BlurPaint.Color := $AA00FFFF;
    ACanvas.DrawCircle(PointF(PosX, PosY), 4, BlurPaint);
  end;
end;

procedure TMegaCatlingGame.DrawTileMap(const ACanvas: ISkCanvas);
var
  Paint, OutlinePaint, HighlightPaint: ISkPaint;
  TileRect: TRectF;
  C, R: Integer;
  VariantX: Single;
  T: TTileType;
  StartCol, EndCol, StartRow, EndRow: Integer;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  OutlinePaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  OutlinePaint.StrokeWidth := 1.5;
  OutlinePaint.AntiAlias := True;
  OutlinePaint.Color := $FF444466;

  HighlightPaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  HighlightPaint.StrokeWidth := 1.0;
  HighlightPaint.AntiAlias := True;
  HighlightPaint.Color := $66FFFFFF;

  // Expanded Culling bounds (-3 to +3) to prevent missing tiles on fast camera movement
  StartCol := Max(0, Trunc(FCameraX / TILE_SIZE) - 3);
  EndCol := Min(FMapCols - 1, Trunc((FCameraX + RENDER_WIDTH) / TILE_SIZE) + 3);
  StartRow := Max(0, Trunc(FCameraY / TILE_SIZE) - 3);
  EndRow := Min(FMapRows - 1, Trunc((FCameraY + RENDER_HEIGHT) / TILE_SIZE) + 3);

  for R := StartRow to EndRow do
    for C := StartCol to EndCol do
    begin
      if FTiles[R * FMapCols + C].Solid then
      begin
        T := FTiles[R * FMapCols + C].TileType;
        TileRect := TRectF.Create(C * TILE_SIZE, R * TILE_SIZE, (C + 1) * TILE_SIZE, (R + 1) * TILE_SIZE);

        if (T = ttConveyorLeft) or (T = ttConveyorRight) then
        begin
          Paint.Color := $FF222233;
          ACanvas.DrawRect(TileRect, Paint);
          Paint.Color := $FF00FFFF;
          if T = ttConveyorRight then
          begin
            ACanvas.DrawLine(PointF(TileRect.Left+5, TileRect.CenterPoint.Y), PointF(TileRect.Right-5, TileRect.CenterPoint.Y), Paint);
            ACanvas.DrawLine(PointF(TileRect.Right-5, TileRect.CenterPoint.Y), PointF(TileRect.Right-10, TileRect.CenterPoint.Y-4), Paint);
            ACanvas.DrawLine(PointF(TileRect.Right-5, TileRect.CenterPoint.Y), PointF(TileRect.Right-10, TileRect.CenterPoint.Y+4), Paint);
          end
          else
          begin
            ACanvas.DrawLine(PointF(TileRect.Left+5, TileRect.CenterPoint.Y), PointF(TileRect.Right-5, TileRect.CenterPoint.Y), Paint);
            ACanvas.DrawLine(PointF(TileRect.Left+5, TileRect.CenterPoint.Y), PointF(TileRect.Left+10, TileRect.CenterPoint.Y-4), Paint);
            ACanvas.DrawLine(PointF(TileRect.Left+5, TileRect.CenterPoint.Y), PointF(TileRect.Left+10, TileRect.CenterPoint.Y+4), Paint);
          end;
          ACanvas.DrawRect(TileRect, OutlinePaint);
        end
        else if Assigned(FGrassShader) then
        begin
          ACanvas.Save;
          try
            ACanvas.ClipRect(TileRect);
            VariantX := ((C * 13 + R * 7) mod 8) * 32;
            ACanvas.Translate(C * TILE_SIZE - VariantX, R * TILE_SIZE);
            Paint.Shader := FGrassShader;
            ACanvas.DrawRect(RectF(0, 0, 256, 32), Paint);
            Paint.Shader := nil;
          finally
            ACanvas.Restore;
          end;
          ACanvas.DrawRect(TileRect, OutlinePaint);
          if (R = 0) or (not FTiles[(R-1) * FMapCols + C].Solid) then
            ACanvas.DrawLine(TileRect.TopLeft, PointF(TileRect.Right, TileRect.Top), HighlightPaint);
        end;
      end;
    end;
end;

procedure TMegaCatlingGame.DrawDecorations(const ACanvas: ISkCanvas);
var
  Item: TDecorItem;
  Paint: ISkPaint;
  CrateRect: TRectF;
  CullLeft, CullRight: Single;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;

  CullLeft := FCameraX - 100;
  CullRight := FCameraX + RENDER_WIDTH + 100;

  for Item in FDecor do
  begin
    if (Item.Pos.X < CullLeft) or (Item.Pos.X > CullRight) then Continue;

    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 2;

    case Item.Kind of
      dtCrate: begin
          CrateRect := TRectF.Create(Item.Pos.X + 2, Item.Pos.Y + 2, Item.Pos.X + 30, Item.Pos.Y + 30);
          Paint.Style := TSkPaintStyle.Fill;
          Paint.Color := $FF2a2a3e;
          ACanvas.DrawRect(CrateRect, Paint);
          Paint.Style := TSkPaintStyle.Stroke;
          Paint.Color := $FF00ffff;
          ACanvas.DrawLine(CrateRect.TopLeft, CrateRect.BottomRight, Paint);
          ACanvas.DrawLine(PointF(CrateRect.Left, CrateRect.Bottom), PointF(CrateRect.Right, CrateRect.Top), Paint);
        end;
      dtUpgradeDmg: begin
          CrateRect := TRectF.Create(Item.Pos.X + 2, Item.Pos.Y + 2, Item.Pos.X + 30, Item.Pos.Y + 30);
          Paint.Style := TSkPaintStyle.Fill;
          Paint.Color := $FF1a1a2e;
          ACanvas.DrawRect(CrateRect, Paint);
          Paint.Style := TSkPaintStyle.Stroke;
          Paint.Color := TAlphaColors.Lime;
          Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 4.0);
          ACanvas.DrawRect(CrateRect, Paint);
          Paint.MaskFilter := nil;
          Paint.Style := TSkPaintStyle.Fill;
          Paint.Color := TAlphaColors.Lime;
          ACanvas.DrawSimpleText('D', Item.Pos.X + 10, Item.Pos.Y + 22, TSkFont.Create(nil, 16), Paint);
        end;
      dtUpgradeHP: begin
          CrateRect := TRectF.Create(Item.Pos.X + 2, Item.Pos.Y + 2, Item.Pos.X + 30, Item.Pos.Y + 30);
          Paint.Style := TSkPaintStyle.Fill;
          Paint.Color := $FF2e1a1a;
          ACanvas.DrawRect(CrateRect, Paint);
          Paint.Style := TSkPaintStyle.Stroke;
          Paint.Color := TAlphaColors.Red;
          Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 4.0);
          ACanvas.DrawRect(CrateRect, Paint);
          Paint.MaskFilter := nil;
          Paint.Style := TSkPaintStyle.Fill;
          Paint.Color := TAlphaColors.Red;
          ACanvas.DrawSimpleText('H', Item.Pos.X + 10, Item.Pos.Y + 22, TSkFont.Create(nil, 16), Paint);
        end;
    end;
    Paint.Style := TSkPaintStyle.Fill;
  end;
end;

procedure TMegaCatlingGame.DrawPlatforms(const ACanvas: ISkCanvas);
var
  Plat: TMovingPlatform;
  Paint, GlowPaint: ISkPaint;
  R: TRectF;
  CullLeft, CullRight: Single;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 8.0);
  GlowPaint.Color := $FF00FFFF;

  CullLeft := FCameraX - 100;
  CullRight := FCameraX + RENDER_WIDTH + 100;

  for Plat in FPlatforms do
  begin
    if (Plat.Pos.X < CullLeft) or (Plat.Pos.X > CullRight) then Continue;

    R := TRectF.Create(Plat.Pos.X, Plat.Pos.Y, Plat.Pos.X + Plat.Width, Plat.Pos.Y + Plat.Height);

    ACanvas.DrawRect(R, GlowPaint);

    Paint.MaskFilter := nil;
    Paint.Color := $FF0A0A1A;
    ACanvas.DrawRect(R, Paint);

    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 2;
    Paint.Color := $FF00FFFF;
    ACanvas.DrawRect(R, Paint);

    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := $AA00FFFF;
    ACanvas.DrawRect(TRectF.Create(Plat.Pos.X + 4, Plat.Pos.Y + 4, Plat.Pos.X + Plat.Width - 4, Plat.Pos.Y + 6), Paint);
  end;
end;

procedure TMegaCatlingGame.DrawGate(const ACanvas: ISkCanvas);
var
  Paint: ISkPaint;
  Center: TPointF;
  PhaseOffset: Single;
  PathBuilder: ISkPathBuilder;
  I: Integer;
  Angle, Radius: Single;
  CullLeft, CullRight: Single;
begin
  CullLeft := FCameraX - 200;
  CullRight := FCameraX + RENDER_WIDTH + 200;

  if (FGate.Pos.X < CullLeft) or (FGate.Pos.X > CullRight) then Exit;

  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Center := PointF(FGate.Pos.X + FGate.Width / 2, FGate.Pos.Y + FGate.Height / 2);

  ACanvas.Save;
  ACanvas.SaveLayer(TSkPaint.Create);
  try
    Paint.Style := TSkPaintStyle.Fill;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 25.0);
    if Sin(FGate.Phase * 2) > 0 then Paint.Color := $FF00FFFF else Paint.Color := $FFFF00FF;
    Paint.Alpha := 180;
    PhaseOffset := Sin(FGate.Phase) * 0.2;

    ACanvas.Save;
    ACanvas.Translate(Center.X, Center.Y);
    ACanvas.Scale(1.0 + PhaseOffset, 1.0 - PhaseOffset);
    ACanvas.DrawOval(TRectF.Create(-45, -70, 45, 70), Paint);
    ACanvas.Restore;

    Paint.Style := TSkPaintStyle.Fill;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal, 10.0);
    Paint.Color := $FF050510;
    ACanvas.DrawOval(TRectF.Create(Center.X - 25, Center.Y - 45, Center.X + 25, Center.Y + 45), Paint);

    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 2;
    Paint.Color := $FFFFFFFF;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 3.0);
    PathBuilder := TSkPathBuilder.Create;
    PathBuilder.MoveTo(Center.X, Center.Y);
    for I := 0 to 20 do
    begin
      Angle := FGate.Phase * 5 + (I * 0.5);
      Radius := I * 3.0;
      PathBuilder.LineTo(Center.X + Cos(Angle) * Radius, Center.Y + Sin(Angle) * Radius * 1.5);
    end;
    ACanvas.DrawPath(PathBuilder.Snapshot, Paint);
  finally
    ACanvas.Restore;
    ACanvas.Restore;
  end;
end;

procedure TMegaCatlingGame.DrawMenu(const ACanvas: ISkCanvas; const ADest: TRectF; const Alpha: Single);
var
  Paint: ISkPaint;
  Font: ISkFont;
  Rect: TRectF;
  CenterX, CenterY: Single;
begin
  if Alpha <= 0 then Exit;
  Paint := TSkPaint.Create;

  Paint.Color := $AA000000;
  Paint.Alpha := Round(Alpha * 170);
  ACanvas.DrawPaint(Paint);

  CenterX := ADest.Width / 2;
  CenterY := ADest.Height / 2;
  Rect := TRectF.Create(CenterX - 150, CenterY - 120, CenterX + 150, CenterY + 120);

  Paint.Color := $FF111122;
  Paint.Alpha := Round(Alpha * 255);
  ACanvas.DrawRoundRect(Rect, 20, 20, Paint);

  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3;
  Paint.Color := $FF00FFFF;
  Paint.Alpha := Round(Alpha * 255);
  ACanvas.DrawRoundRect(Rect, 20, 20, Paint);

  Font := TSkFont.Create(nil, 24);
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  Paint.Color := TAlphaColors.White;
  Paint.Alpha := Round(Alpha * 255);
  ACanvas.DrawSimpleText('PAUSED', CenterX - 50, CenterY - 70, Font, Paint);
  Paint.Color := TAlphaColors.Lime;
  ACanvas.DrawSimpleText('ESC - Resume', CenterX - 65, CenterY - 20, Font, Paint);
  ACanvas.DrawSimpleText('R - Reset Level', CenterX - 70, CenterY + 10, Font, Paint);
end;

procedure TMegaCatlingGame.DrawTitleScreen(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  Paint: ISkPaint;
  FontBig, FontSmall: ISkFont;
begin
  if FTitleAlpha <= 0 then Exit;
  Paint := TSkPaint.Create;
  Paint.Color := $FF000000;
  Paint.Alpha := Round(FTitleAlpha * 255);
  ACanvas.DrawRect(ADest, Paint);

  if FTitleAlpha > 0.1 then
  begin
    FontBig := TSkFont.Create(nil, 80);
    FontSmall := TSkFont.Create(nil, 24);

    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 6;
    Paint.StrokeJoin := TSkStrokeJoin.Round;
    Paint.Color := $FF00FFFF;
    Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 10.0);
    Paint.Alpha := Round(FTitleAlpha * 255);

    ACanvas.DrawSimpleText('MEGACATLING', ADest.CenterPoint.X - 260, ADest.CenterPoint.Y, FontBig, Paint);

    Paint.MaskFilter := nil;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := TAlphaColors.White;
    ACanvas.DrawSimpleText('MEGACATLING', ADest.CenterPoint.X - 260, ADest.CenterPoint.Y, FontBig, Paint);

    Paint.Color := TAlphaColors.Lime;
    ACanvas.DrawSimpleText('CLICK TO START', ADest.CenterPoint.X - 80, ADest.CenterPoint.Y + 50, FontSmall, Paint);
  end;
end;

procedure TMegaCatlingGame.DrawLoadingScreen(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  Paint: ISkPaint;
  FontBig, FontSmall: ISkFont;
begin
  Paint := TSkPaint.Create;
  Paint.Color := $FF000000;
  ACanvas.DrawRect(ADest, Paint);

  FontBig := TSkFont.Create(nil, 60);
  FontSmall := TSkFont.Create(nil, 24);

  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 4;
  Paint.StrokeJoin := TSkStrokeJoin.Round;
  Paint.Color := $FF00FFFF;
  Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 8.0);
  ACanvas.DrawSimpleText('LOADING...', ADest.CenterPoint.X - 180, ADest.CenterPoint.Y, FontBig, Paint);

  Paint.MaskFilter := nil;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := TAlphaColors.White;
  ACanvas.DrawSimpleText('LOADING...', ADest.CenterPoint.X - 180, ADest.CenterPoint.Y, FontBig, Paint);

  Paint.Color := TAlphaColors.Lime;
  if Trunc(FAnimPhase * 4) mod 2 = 0 then
    ACanvas.DrawSimpleText('PREPARING LEVEL ' + IntToStr(FLevel), ADest.CenterPoint.X - 100, ADest.CenterPoint.Y + 60, FontSmall, Paint);
end;

procedure TMegaCatlingGame.DrawEnemies(const ACanvas: ISkCanvas);
var
  E: TEnemy;
  Paint, GlowPaint, BgPaint: ISkPaint;
  Center: TPointF;
  Offset: Single;
  HPRect: TRectF;
  CullLeft, CullRight: Single;
begin
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 6.0);
  BgPaint := TSkPaint.Create(Paint);

  CullLeft := FCameraX - 100;
  CullRight := FCameraX + RENDER_WIDTH + 100;

  for E in FEnemies do
  begin
    if (E.Pos.X < CullLeft) or (E.Pos.X > CullRight) then Continue;

    Center := PointF(E.Pos.X + E.Width / 2, E.Pos.Y + E.Height / 2);

    if E.EnemyType = etWalker then
    begin
      Offset := Abs(Sin(E.Phase * 2)) * 2.0;

      if E.Health < E.MaxHealth then
      begin
        HPRect := TRectF.Create(E.Pos.X, E.Pos.Y - 12, E.Pos.X + E.Width, E.Pos.Y - 6);
        BgPaint.Color := $FF000000; ACanvas.DrawRect(HPRect, BgPaint);
        BgPaint.Color := $FFFF0000; ACanvas.DrawRect(TRectF.Create(HPRect.Left+1, HPRect.Top+1, HPRect.Right-1, HPRect.Bottom-1), BgPaint);
        BgPaint.Color := $FF00FF00; ACanvas.DrawRect(TRectF.Create(HPRect.Left+1, HPRect.Top+1, HPRect.Left + 1 + ((HPRect.Width-2) * (E.Health / E.MaxHealth)), HPRect.Bottom-1), BgPaint);
      end;

      GlowPaint.Color := $FFFF0000;
      if E.HitFlash > 0 then Paint.Color := TAlphaColors.White else Paint.Color := $FF880000;
      ACanvas.DrawRoundRect(TRectF.Create(E.Pos.X, E.Pos.Y + Offset, E.Pos.X + E.Width, E.Pos.Y + E.Height), 4, 4, GlowPaint);
      ACanvas.DrawRoundRect(TRectF.Create(E.Pos.X, E.Pos.Y + Offset, E.Pos.X + E.Width, E.Pos.Y + E.Height), 4, 4, Paint);

      Paint.Color := TAlphaColors.Yellow;
      ACanvas.DrawCircle(PointF(Center.X, Center.Y - 4 + Offset), 4, Paint);
      Paint.Color := TAlphaColors.Black;
      ACanvas.DrawCircle(PointF(Center.X, Center.Y - 4 + Offset), 2, Paint);
    end
    else if E.EnemyType = etFlyer then
    begin
      Offset := Sin(E.Phase) * 3.0;
      GlowPaint.Color := $FF00FFFF;
      if E.HitFlash > 0 then Paint.Color := TAlphaColors.White else Paint.Color := $FF005577;
      ACanvas.DrawOval(TRectF.Create(E.Pos.X, E.Pos.Y + Offset, E.Pos.X + E.Width, E.Pos.Y + E.Height), GlowPaint);
      ACanvas.DrawOval(TRectF.Create(E.Pos.X, E.Pos.Y + Offset, E.Pos.X + E.Width, E.Pos.Y + E.Height), Paint);

      Paint.Style := TSkPaintStyle.Stroke;
      Paint.StrokeWidth := 2;
      Paint.Color := $FFFFFFFF;
      ACanvas.DrawLine(PointF(E.Pos.X - 4, E.Pos.Y + 5 + Offset), PointF(E.Pos.X + E.Width + 4, E.Pos.Y + 5 + Offset), Paint);

      Paint.Style := TSkPaintStyle.Fill;
      Paint.Color := TAlphaColors.Red;
      ACanvas.DrawCircle(PointF(Center.X, Center.Y + Offset), 3, Paint);
    end
    else if E.EnemyType = etDog then
    begin
      if E.Health < E.MaxHealth then
      begin
        HPRect := TRectF.Create(E.Pos.X, E.Pos.Y - 10, E.Pos.X + E.Width, E.Pos.Y - 4);
        BgPaint.Color := $FF000000; ACanvas.DrawRect(HPRect, BgPaint);
        BgPaint.Color := $FFFF0000; ACanvas.DrawRect(TRectF.Create(HPRect.Left+1, HPRect.Top+1, HPRect.Right-1, HPRect.Bottom-1), BgPaint);
        BgPaint.Color := $FF00FF00; ACanvas.DrawRect(TRectF.Create(HPRect.Left+1, HPRect.Top+1, HPRect.Left + 1 + ((HPRect.Width-2) * (E.Health / E.MaxHealth)), HPRect.Bottom-1), BgPaint);
      end;

      GlowPaint.Color := $FFFF8800;
      if E.HitFlash > 0 then Paint.Color := TAlphaColors.White else Paint.Color := $FF884400;

      ACanvas.DrawRoundRect(TRectF.Create(E.Pos.X, E.Pos.Y, E.Pos.X + E.Width, E.Pos.Y + E.Height), 6, 6, GlowPaint);
      ACanvas.DrawRoundRect(TRectF.Create(E.Pos.X, E.Pos.Y, E.Pos.X + E.Width, E.Pos.Y + E.Height), 6, 6, Paint);

      Paint.Color := TAlphaColors.Red;
      ACanvas.DrawCircle(PointF(E.Pos.X + E.Width - 8, E.Pos.Y + 8), 3, Paint);
    end;
  end;
end;

procedure TMegaCatlingGame.DrawBullets(const ACanvas: ISkCanvas);
var
  B: TBullet;
  Paint, GlowPaint: ISkPaint;
begin
  if FBullets.Count = 0 then Exit;
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 8.0);

  for B in FBullets do
  begin
    if B.IsPlayerBullet then
    begin
      if B.Damage > 1 then
      begin
        GlowPaint.Color := TAlphaColors.Lime;
        Paint.Color := TAlphaColors.White;
        ACanvas.DrawCircle(B.Pos, 8, GlowPaint);
        ACanvas.DrawCircle(B.Pos, 4, Paint);
      end
      else
      begin
        GlowPaint.Color := TAlphaColors.Cyan;
        Paint.Color := TAlphaColors.White;
        ACanvas.DrawCircle(B.Pos, 6, GlowPaint);
        ACanvas.DrawCircle(B.Pos, 3, Paint);
      end;
    end
    else
    begin
      GlowPaint.Color := TAlphaColors.Red;
      Paint.Color := TAlphaColors.Yellow;
      ACanvas.DrawCircle(B.Pos, 5, GlowPaint);
      ACanvas.DrawCircle(B.Pos, 2, Paint);
    end;
  end;
end;

procedure TMegaCatlingGame.DrawParticles(const ACanvas: ISkCanvas);
var
  P: TParticle;
  Paint: ISkPaint;
  AlphaVal: Integer;
  CullLeft, CullRight: Single;
begin
  if FParticles.Count = 0 then Exit;
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  Paint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 3.0);

  CullLeft := FCameraX - 100;
  CullRight := FCameraX + RENDER_WIDTH + 100;

  for P in FParticles do
  begin
    if (P.Pos.X < CullLeft) or (P.Pos.X > CullRight) then Continue;

    Paint.Color := P.Color;
    AlphaVal := Round(P.Life * 180);
    if AlphaVal > 255 then AlphaVal := 255;
    if AlphaVal < 0 then AlphaVal := 0;
    Paint.Alpha := AlphaVal;
    ACanvas.DrawCircle(P.Pos, P.Size * P.Life, Paint);
  end;
end;

procedure TMegaCatlingGame.DrawCyberCatlingAvatar(const ACanvas: ISkCanvas; const Center: TPointF; const Scale: Single; const VelX: Single);
var
  Paint, GlowPaint: ISkPaint;
  BodyRect, HeadRect: TRectF;
  TailWag, RunPhase: Single;
  TailStart, TailMid, TailEnd: TPointF;
  PB: ISkPathBuilder;
  LegOffset, HeadXOffset, BodyDrop, HeadLift, EyeShift: Single;
begin
  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.AntiAlias := True;
  Paint.Color := $FF333333;
  GlowPaint := TSkPaint.Create(Paint);
  GlowPaint.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Solid, 6.0);
  GlowPaint.Color := $FF00FFFF;

  // HEAD SHAKE FIX:
  if not FBraking then
  begin
    if VelX < -0.5 then
      FLookDir := -1
    else if VelX > 0.5 then
      FLookDir := 1;
  end;
  if FLookDir = 0 then
    FLookDir := 1;

  BodyDrop := 16.0;
  HeadLift := -10.0;
  RunPhase := FAnimPhase * 10;

  if FCrouching then
  begin
    BodyRect := TRectF.Create(Center.X - 20, Center.Y + BodyDrop + 10, Center.X + 20, Center.Y + BodyDrop + 28);
  end
  else
  begin
    if Abs(VelX) > 0.5 then
      BodyRect := TRectF.Create(Center.X - 18, Center.Y + BodyDrop, Center.X + 18, Center.Y + BodyDrop + 18)
    else
      BodyRect := TRectF.Create(Center.X - 14, Center.Y + BodyDrop, Center.X + 14, Center.Y + BodyDrop + 20);
  end;

  ACanvas.DrawOval(BodyRect, GlowPaint);
  ACanvas.DrawOval(BodyRect, Paint);

  // Legs
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3.0;
  Paint.StrokeCap := TSkStrokeCap.Round;
  LegOffset := 0.0;
  if Abs(VelX) > 0.5 then
    LegOffset := Sin(RunPhase) * 5.0;

  if not FCrouching then
  begin
    ACanvas.DrawLine(PointF(BodyRect.Left + 4, BodyRect.Bottom), PointF(BodyRect.Left + 4 + LegOffset, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Left + 8, BodyRect.Bottom), PointF(BodyRect.Left + 8 - LegOffset, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 4, BodyRect.Bottom), PointF(BodyRect.Right - 4 + LegOffset, BodyRect.Bottom + 8), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 8, BodyRect.Bottom), PointF(BodyRect.Right - 8 - LegOffset, BodyRect.Bottom + 8), Paint);
  end
  else
  begin
    ACanvas.DrawLine(PointF(BodyRect.Left + 4, BodyRect.Bottom - 2), PointF(BodyRect.Left + 2, BodyRect.Bottom + 2), Paint);
    ACanvas.DrawLine(PointF(BodyRect.Right - 4, BodyRect.Bottom - 2), PointF(BodyRect.Right - 2, BodyRect.Bottom + 2), Paint);
  end;

  // Head
  Paint.Style := TSkPaintStyle.Fill;
  HeadXOffset := FLookDir * 10;
  if Abs(VelX) > 0.5 then
    HeadXOffset := FLookDir * 15;

  // Kopf-Position an das Ducken anpassen
  if FCrouching then
  begin
    // Wenn geduckt, sitzt der Kopf weiter unten und etwas weiter vorne
    HeadRect := TRectF.Create(Center.X - 10 + HeadXOffset + 5, BodyRect.Top - 5, Center.X + 10 + HeadXOffset + 5, BodyRect.Top + 15);
  end
  else
  begin
    HeadRect := TRectF.Create(Center.X - 10 + HeadXOffset, Center.Y + BodyDrop + HeadLift - 5, Center.X + 10 + HeadXOffset, Center.Y + BodyDrop + HeadLift + 15);
  end;

  ACanvas.DrawOval(HeadRect, GlowPaint);
  ACanvas.DrawOval(HeadRect, Paint);

  // Ears
  PB := TSkPathBuilder.Create;
  PB.MoveTo(HeadRect.Left + 2, HeadRect.Top + 5);
  PB.LineTo(HeadRect.Left + 6, HeadRect.Top - 8);
  PB.LineTo(HeadRect.Left + 10, HeadRect.Top + 5);
  PB.MoveTo(HeadRect.Right - 10, HeadRect.Top + 5);
  PB.LineTo(HeadRect.Right - 6, HeadRect.Top - 8);
  PB.LineTo(HeadRect.Right - 2, HeadRect.Top + 5);
  ACanvas.DrawPath(PB.Snapshot, Paint);

  // Tail
  TailWag := Sin(FAnimPhase * 6) * 5.0;
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3.0;
  Paint.Color := $FF333333;
  TailStart := PointF(BodyRect.CenterPoint.X - (FLookDir * 15), BodyRect.CenterPoint.Y);
  TailMid := PointF(TailStart.X - (FLookDir * 15), Center.Y + BodyDrop + TailWag);
  TailEnd := PointF(TailMid.X - (FLookDir * 5), Center.Y + BodyDrop - 15 + TailWag);
  PB := TSkPathBuilder.Create;
  PB.MoveTo(TailStart.X, TailStart.Y);
  PB.QuadTo(TailMid.X, TailMid.Y, TailEnd.X, TailEnd.Y);
  ACanvas.DrawPath(PB.Snapshot, Paint);

  // Eyes
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := TAlphaColors.Yellow;
  EyeShift := FLookDir * 2;
  ACanvas.DrawCircle(PointF(HeadRect.CenterPoint.X - 3 + EyeShift, HeadRect.CenterPoint.Y), 3, Paint);
  ACanvas.DrawCircle(PointF(HeadRect.CenterPoint.X + 3 + EyeShift, HeadRect.CenterPoint.Y), 3, Paint);
  Paint.Color := TAlphaColors.Black;
  ACanvas.DrawOval(TRectF.Create(HeadRect.CenterPoint.X - 4 + EyeShift, HeadRect.CenterPoint.Y - 1.5, HeadRect.CenterPoint.X - 2 + EyeShift, HeadRect.CenterPoint.Y + 1.5), Paint);
  ACanvas.DrawOval(TRectF.Create(HeadRect.CenterPoint.X + 2 + EyeShift, HeadRect.CenterPoint.Y - 1.5, HeadRect.CenterPoint.X + 4 + EyeShift, HeadRect.CenterPoint.Y + 1.5), Paint);
end;


// Main rendering entry point
procedure TMegaCatlingGame.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
var
  Scale: Single;
begin
  ACanvas.Clear(TAlphaColors.Black);

  if FGameState = gsLoading then
  begin
    Scale := Min(ADest.Width / RENDER_WIDTH, ADest.Height / RENDER_HEIGHT);
    ACanvas.Save;
    try
      ACanvas.Scale(Scale, Scale);
      var VisW := ADest.Width / Scale;
      var VisH := ADest.Height / Scale;
      DrawLoadingScreen(ACanvas, RectF(0, 0, VisW, VisH));
    finally
      ACanvas.Restore;
    end;
    Exit;
  end;

  Scale := Min(ADest.Width / RENDER_WIDTH, ADest.Height / RENDER_HEIGHT);
  ACanvas.Save;
  try
    ACanvas.Scale(Scale, Scale);

    var VisW := ADest.Width / Scale;
    var VisH := ADest.Height / Scale;

    DrawBackgrounds(ACanvas, RectF(0, 0, VisW, VisH));

    ACanvas.Save;
    ACanvas.Translate(-FCameraX, -FCameraY);
    FLock.Acquire;
    try
      DrawTileMap(ACanvas);
      DrawPlatforms(ACanvas);
      DrawDecorations(ACanvas);
      DrawGate(ACanvas);
      DrawEnemies(ACanvas);
      DrawBullets(ACanvas);
      DrawParticles(ACanvas);
      var PlayerCenter := PointF(FPlayer.Pos.X + FPlayer.Width / 2, FPlayer.Pos.Y + 10.0);
      if (FGameState = gsPlaying) and (FInvincibilityTimer <= 0) then
      begin
        FAnimPhase := FAnimPhase + 0.1;
        DrawCyberCatlingAvatar(ACanvas, PlayerCenter, 1.0, FPlayer.Vel.X);
      end
      else if (FGameState = gsPlaying) and (Trunc(FInvincibilityTimer * 10) mod 2 = 0) then
      begin
        FAnimPhase := FAnimPhase + 0.1;
        DrawCyberCatlingAvatar(ACanvas, PlayerCenter, 1.0, FPlayer.Vel.X);
      end;
    finally
      FLock.Release;
      ACanvas.Restore;
    end;

    DrawUI(ACanvas);

    if FMenuAlpha > 0 then
      DrawMenu(ACanvas, RectF(0, 0, VisW, VisH), FMenuAlpha);

    if FGameState = gsTitle then
      DrawTitleScreen(ACanvas, RectF(0, 0, VisW, VisH));

  finally
    ACanvas.Restore;
  end;
end;

// ============================================================================
// INPUT & THREADING
// ============================================================================

procedure TMegaCatlingGame.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if (FGameState = gsTitle) and not FTitleFadingOut then
    FTitleFadingOut := True;
  inherited;
end;

procedure TMegaCatlingGame.SafeInvalidate;
begin
  if csDestroying in ComponentState then Exit;
  TThread.Queue(nil,
    procedure
    begin
      if not (csDestroying in ComponentState) and Assigned(Self) then
      begin
        Redraw;
        Repaint;
      end;
    end);
end;

procedure TMegaCatlingGame.StartThread;
begin
  if Assigned(FThread) then Exit;
  FThread := TThread.CreateAnonymousThread(
    procedure
    var
      LastTime, NowTime, DeltaMS: Cardinal;
    begin
      LastTime := TThread.GetTickCount;
      while not TThread.CheckTerminated do
      begin
        NowTime := TThread.GetTickCount;
        DeltaMS := NowTime - LastTime;
        if DeltaMS = 0 then DeltaMS := 1;
        LastTime := NowTime;

        if FActive then
        begin
          DoPhysicsUpdate(DeltaMS / 1000);
          SafeInvalidate;
        end;
        Sleep(16); // Target ~60 FPS
      end;
    end);
  FThread.FreeOnTerminate := True;
  FThread.Start;
end;

procedure TMegaCatlingGame.StopThread;
begin
  FActive := False;
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    Sleep(50);
  end;
end;

// ============================================================================
// CONSTRUCTION & DESTRUCTION
// ============================================================================

constructor TMegaCatlingGame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FLock := TCriticalSection.Create;

  Align := TAlignLayout.Client;
  HitTest := True;
  CanFocus := True;
  TabStop := True;

  FActive := True;
  FLevel := 1;
  FGameState := gsTitle;
  FTitleAlpha := 1.0;
  FTitleFadingOut := False;
  FMenuAlpha := 0.0;
  FMenuTargetActive := False;
  FLoadingTimer := 0;

  FMapCols := 200;
  FMapRows := 20;
  FCameraX := 0;
  FCameraY := 0;

  FParticles := TList<TParticle>.Create;
  FDecor := TList<TDecorItem>.Create;
  FEnemies := TList<TEnemy>.Create;
  FBullets := TList<TBullet>.Create;
  FPlatforms := TList<TMovingPlatform>.Create;
  SetLength(FTiles, FMapCols * FMapRows);

  FPlayer.Width := 28;
  FPlayer.Height := 56;
  FLookDir := 1;
  FBraking := False;
  FCrouching := False;
  FFireCooldown := 0;
  FDamageBoostTimer := 0;
  FPlayerHP := 3;
  FInvincibilityTimer := 0;
  FCheckpointTimer := 0;
  FJumpPressed := False;

  InitProceduralTextures;

  GenerateBackgroundElements;
  GenerateProceduralMap;

  StartThread;
end;

destructor TMegaCatlingGame.Destroy;
begin
  StopThread;
  FreeAndNil(FLock);
  FreeAndNil(FParticles);
  FreeAndNil(FDecor);
  FreeAndNil(FEnemies);
  FreeAndNil(FBullets);
  FreeAndNil(FPlatforms);
  inherited;
end;

procedure TMegaCatlingGame.PlayEffect(Effect: TAudioEffect);
var
  FileName, BasePath: string;
  Flags: Cardinal;
begin
  if Effect = afNone then Exit;
  BasePath := ExtractFilePath(ParamStr(0));

  case Effect of
    afJump:      FileName := 'Game Design Sound Effects - Pavs Music\39 - Jump.wav';
    afExplosion: FileName := 'Game Design Sound Effects - Pavs Music\47 - Crunch.wav';
    afCrate:     FileName := 'Game Design Sound Effects - Pavs Music\05 - Equip.wav';
    afPortal:    FileName := 'Game Design Sound Effects - Pavs Music\12 - TingaLing.wav';
    afWin:       FileName := 'Game Design Sound Effects - Pavs Music\34 - Useful Sound 18.wav';
    afDie:       FileName := 'Game Design Sound Effects - Pavs Music\03 - Crush.wav';
    afShoot:     FileName := 'Game Design Sound Effects - Pavs Music\05 - Equip.wav';
    afUpgrade:   FileName := 'Game Design Sound Effects - Pavs Music\34 - Useful Sound 18.wav';
  else
    FileName := '';
  end;

  if FileName = '' then Exit;
  FileName := BasePath + FileName;
  if not FileExists(FileName) then Exit;

  Flags := SND_ASYNC or SND_FILENAME or SND_NODEFAULT;
  PlaySound(PChar(FileName), 0, Flags);
end;

procedure TMegaCatlingGame.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  GameKey: Byte;
begin
  if FGameState = gsTitle then
  begin
    if (Key = vkSpace) or (Key = vkReturn) then
      FTitleFadingOut := True;
    Exit;
  end;

  if (Key = vkEscape) then
  begin
    FMenuTargetActive := not FMenuTargetActive;
    Key := 0;
    KeyChar := #0;
    Redraw;
    Repaint;
    Exit;
  end;

  if FMenuTargetActive then
  begin
    if (KeyChar = 'R') or (KeyChar = 'r') then
    begin
      FLevel := 1;
      FPlayerHP := 3;
      GenerateProceduralMap;
      GenerateBackgroundElements;
      FMenuTargetActive := False;
      Redraw;
      Repaint;
    end;
    Exit;
  end;

  GameKey := 0;
  case Key of
    vkLeft: GameKey := vkLeft;
    vkRight: GameKey := vkRight;
    vkUp: GameKey := vkUp;
    vkDown: GameKey := vkDown;
    vkSpace: GameKey := vkUp;
  end;

  if GameKey = 0 then
  begin
    case KeyChar of
      'A', 'a': GameKey := vkLeft;
      'D', 'd': GameKey := vkRight;
      'W', 'w': GameKey := vkUp;
      'S', 's': GameKey := vkDown;
      ' ':      GameKey := vkUp;
      'E', 'e': GameKey := VK_SHOOT;
    end;
  end;

  if GameKey > 0 then
  begin
    FLock.Acquire;
    try
      if not (GameKey in FKeys) then
      begin
        Include(FKeys, GameKey);
        if GameKey = vkUp then
          FJumpPressed := True;
      end;
    finally
      FLock.Release;
    end;
    Key := 0;
    KeyChar := #0;
  end;
  inherited;
end;

procedure TMegaCatlingGame.KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  GameKey: Byte;
begin
  if FMenuTargetActive then Exit;

  GameKey := 0;
  case Key of
    vkLeft: GameKey := vkLeft;
    vkRight: GameKey := vkRight;
    vkUp: GameKey := vkUp;
    vkDown: GameKey := vkDown;
    vkSpace: GameKey := vkUp;
  end;

  if GameKey = 0 then
  begin
    case KeyChar of
      'A', 'a': GameKey := vkLeft;
      'D', 'd': GameKey := vkRight;
      'W', 'w': GameKey := vkUp;
      'S', 's': GameKey := vkDown;
      ' ':      GameKey := vkUp;
      'E', 'e': GameKey := VK_SHOOT;
    end;
  end;

  if GameKey > 0 then
  begin
    FLock.Acquire;
    try
      Exclude(FKeys, GameKey);
      if GameKey = vkUp then
        FJumpPressed := False;
    finally
      FLock.Release;
    end;
    Key := 0;
    KeyChar := #0;
  end;
  inherited;
end;

end.
