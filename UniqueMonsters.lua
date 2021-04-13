--Script handling elite monsters' special effects for the Serious RPG mod
--by NSKuber

--monster : CLeggedCharacterEntity
--weapon : CWeaponEntity
--player : CPlayerPuppetEntity
--gameInfo : CGameInfo

--Preliminary setup

local worldInfo = worldGlobals.worldInfo
local Pi = 3.14159265359
local QV = function(x,y,z,h,p,b)
  return mthQuatVect(mthHPBToQuaternion(h,p,b),mthVector3f(x,y,z))
end

worldGlobals.RPGUniqueAffixes = {
  "Cold Enchanted","Fire Enchanted","Lightning Enchanted","Cursed",
  "Extra Fast","Stone Skin","Extra Strong","Corpse Explosion",
  "Life Regen","Iron Maiden","Ammo Steal","Knockback","Vortex",
  "Teleporting",
}
local gameInfo = worldInfo:GetGameInfo()
worldGlobals.RPGBannedAffixes = {}
local AffixToNumber = {}
for i,name in pairs(worldGlobals.RPGUniqueAffixes) do
  AffixToNumber[name] = i
  worldGlobals.RPGBannedAffixes[name] = false
  if (gameInfo:GetSessionValueInt("RPGBan"..name) > 0) then
    worldGlobals.RPGBannedAffixes[name] = true
  end
end
worldGlobals.MonsterUniqueAffixes = {}

local localPlayer

local GetLocalViewer = function()
  local tempPlayer
  local spectator = false
  if IsDeleted(localPlayer) then
    local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
    for i=1,#Players,1 do
      if Players[i]:IsLocalViewer() then
        tempPlayer = localPlayer
        localPlayer = Players[i]
        spectator = true
        break
      end
    end
  elseif not localPlayer:IsAlive() then
    local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
    for i=1,#Players,1 do
      if Players[i]:IsLocalViewer() and not (Players[i] == localPlayer) then
        tempPlayer = localPlayer
        localPlayer = Players[i]
        spectator = true
        break
      end
    end        
  end
  if spectator then
    return tempPlayer
  else
    return false
  end
end

local time = GetDateTimeLocal()
local seed = 3600*tonumber(string.sub(time,-8,-7))+60*tonumber(string.sub(time,-5,-4))+tonumber(string.sub(time,-2,-1))
local RNG = CreateRandomNumberGenerator(seed + mthTruncF(mthRndF() * 1000))

--COLD ENCHANTED
local FreezingSounds = {}
for i=1,4,1 do
  FreezingSounds[i] = LoadResource("Content/SeriousSamFusion/Scripts/Templates/SeriousRPG/Sounds/Freeze0"..i..".wav")
end
local zeroBias = mthVector3f(0,0,0)
local frozenBias = mthVector3f(0,0,5)
--freezingSond : CStaticSoundEntity
local RPGFreezingHit = function(player)
  player:SetAmbientBias(frozenBias)
  local freezingSound = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("FreezeSound",worldInfo,player:GetPlacement())
  freezingSound:SetSound(FreezingSounds[worldGlobals.RPGRndL(1,#FreezingSounds)])
  freezingSound:PlayOnce()
  Wait(Delay(2))
  if not IsDeleted(freezingSound) then
    freezingSound:Delete()
  end   
end
worldGlobals.CreateRPC("server","reliable","RPGFreezingHit",function(player)
  RPGFreezingHit(player)
end)
worldGlobals.CreateRPC("server","reliable","RPGUnfreeze",function(player)
  RunAsync(function()
    player:SetAmbientBias(zeroBias)
  end)
end)
worldGlobals.BaseRPGFreezingHit = function(player)
  RunAsync(function()
    if worldInfo:IsSinglePlayer() then
      RPGFreezingHit(player)  
    else
      worldGlobals.RPGFreezingHit(player)
    end
  end)
end

--FIRE ENCHANTED
local FireSounds = {}
for i=1,2,1 do
  FireSounds[i] = LoadResource("Content/SeriousSamFusion/Scripts/Templates/SeriousRPG/Sounds/Fire0"..i..".wav")
end
local RPGFireHit = function(player)
  local playerID = player:GetPlayerId()
  SignalEvent("RPGStopBurningSound"..playerID)
  local fireSound = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("FireSound",worldInfo,player:GetPlacement())
  fireSound:SetParent(player,"")
  for i=1,6,1 do
    if IsDeleted(fireSound) then
      fireSound = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("FireSound",worldInfo,player:GetPlacement())
      fireSound:SetParent(player,"")
    end
    fireSound:SetSound(FireSounds[worldGlobals.RPGRndL(1,#FireSounds)])
    fireSound:PlayOnce()
    local payload = Wait(Any(CustomEvent("RPGStopBurningSound"..playerID),Delay(0.4)))
    if payload.any[1] then
      break
    end
  end
  Wait(Delay(0.5))
  if not IsDeleted(fireSound) then
    fireSound:Delete()
  end   
end
worldGlobals.CreateRPC("server","reliable","RPGFireHit",function(player)
  RPGFireHit(player)
end)
worldGlobals.BaseRPGFireHit = function(player)
  RunAsync(function()
    if worldInfo:IsSinglePlayer() then
      RPGFireHit(player)
    else
      worldGlobals.RPGFireHit(player)
    end
  end)
end

--LIGHTNING ENCHANTED
local lightningBolt = LoadResource("Content/SeriousSam3/Databases/Projectiles/RPG/LightningBolt.ep")
worldGlobals.RPGLightningEnchantedHit = function(monster)
  local qvProjSpawn = monster:GetPlacement()
  local box = monster:GetBoundingBoxSize()
  qvProjSpawn.vy = qvProjSpawn.vy + mthMinF(box.y*0.75,1.3)
  qvProjSpawn.qp = 0
  qvProjSpawn.qb = 0
  local vProjSpawn = qvProjSpawn:GetVect()
  local spawnRadius = mthLenV3f(mthVector3f(box.x,0,box.z))*0.25
  for i=1,6,1 do
    qvProjSpawn.qh = RNG:RndF()*Pi/4 + Pi*(i-1)/3 - Pi/8
    qvProjSpawn:SetVect(vProjSpawn+mthQuaternionToDirection(qvProjSpawn:GetQuat())*spawnRadius)
    worldInfo:SpawnProjectile(monster,lightningBolt,qvProjSpawn,6,nil)
  end
end
local LightningSounds = {}
for i=1,4,1 do
  LightningSounds[i] = LoadResource("Content/SeriousSam3/Models/Projectiles/RPG/Sounds/LightningHit0"..i..".wav")
end
local RPGLightningHit = function(player)
  local lightningSound = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("FreezeSound",worldInfo,player:GetPlacement())
  lightningSound:SetSound(LightningSounds[worldGlobals.RPGRndL(1,#LightningSounds)])
  lightningSound:PlayOnce()
  Wait(Delay(2))
  if not IsDeleted(lightningSound) then
    lightningSound:Delete()
  end
end
worldGlobals.CreateRPC("server","reliable","RPGLightningHit",function(player)
  RPGLightningHit(player)
end)
worldGlobals.BaseRPGLightningHit = function(player)
  RunAsync(function()
    if worldInfo:IsSinglePlayer() then
      RPGLightningHit(player)
    else
      worldGlobals.RPGLightningHit(player)
    end
  end)
end

--CURSED
local RPGCursedHit = function(player)
  local playerID = player:GetPlayerId()
  SignalEvent("RPGStopCursedEffect"..playerID)
  local qvPlayer = player:GetPlacement()
  qvPlayer.vy = qvPlayer.vy + player:GetBoundingBoxSize().y*1.05
  local cursedEffect = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("ADCurseEffect",worldInfo,qvPlayer)
  cursedEffect:SetParent(player,"")
  Wait(Any(CustomEvent("RPGStopCursedEffect"..playerID),Delay(4)))
  if not IsDeleted(cursedEffect) then
    cursedEffect:Delete()
  end     
end
worldGlobals.CreateRPC("server","reliable","RPGCursedHit",function(player)
  RPGCursedHit(player)
end)
worldGlobals.BaseRPGCursedHit = function(player)
  RunAsync(function()
    if worldInfo:IsSinglePlayer() then
      RPGCursedHit(player)
    else
      worldGlobals.RPGCursedHit(player)
    end
  end)
end

--CORPSE EXPLOSION
local corpseExplosion = LoadResource("Content/SeriousSam3/Databases/Projectiles/RPG/CorpseExplosion.ep")
local HandleCorpseExplosion = function(monster)
  RunAsync(function()
    local verticalShift = monster:GetBoundingBoxSize().y/2
    Wait(Event(monster.Died))
    if not IsDeleted(monster) then
      local qvExplosion = monster:GetPlacement()
      qvExplosion.vy = qvExplosion.vy + verticalShift
      worldInfo:SpawnProjectile(monster,corpseExplosion,qvExplosion,0,nil)
    end
  end)
end

--IRON MAIDEN
local function CanPlayerSeeEnemy(enPlayer,enEnemy)

  local vEnemyPos = enEnemy:GetPlacement():GetVect()  
  
  local qvOrigin = enPlayer:GetLookOrigin()
  local vOrigin = qvOrigin:GetVect()
  local vLookDir = enPlayer:GetLookDir(false)
  
  local enHit,vHit,vNorm = CastRay(worldInfo,enPlayer,vOrigin,mthQuaternionToDirection(qvOrigin:GetQuat()),1000,0,"camera_aim_ray")
  if (enHit == nil) then
    vHit = qvOrigin:GetVect() + mthQuaternionToDirection(qvOrigin:GetQuat()) * 1000
  end  
  vOrigin = vHit - vLookDir*mthDotV3f(vLookDir,vHit - vOrigin)
  
  local enHit,vHit,vNorm = CastRay(worldInfo,enPlayer,vOrigin,(-1)*vLookDir,8,0.01,"camera_aim_ray")
  if (enHit == nil) then
    vHit = vOrigin - vLookDir * 8
  end
  local fDist = mthLenV3f(vHit - vOrigin)

  local bCanSee = false
  local enEmptyModel = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("LookTarget",worldInfo,qvOrigin)
  for i=0,8,1 do
    local vCameraPos = vOrigin - vLookDir*(fDist*i/8)
    enEmptyModel:SetPlacement(mthQuatVect(qvOrigin:GetQuat(),vCameraPos))
    if enEnemy:CanSeeEntity(enEmptyModel) then 
      bCanSee = true
      break
    end
  end
  enEmptyModel:Delete()

  return bCanSee
  
end

--effect : CParticleEffectEntity
worldGlobals.RPGIronMaiden = {}
worldGlobals.RPGIronMaidenEffects = {}
local RPGIMEffectSwitch = function(monster,bSwitch)
  RunAsync(function()
    if not bSwitch then
      if not IsDeleted(worldGlobals.RPGIronMaidenEffects[monster]) then
        worldGlobals.RPGIronMaidenEffects[monster]:Delete()
      end
    else
      local qvEffect = monster:GetPlacement()
      local box = monster:GetBoundingBoxSize()
      local effectEnabled = true
      qvEffect.vy = qvEffect.vy + box.y*0.5
      local size = (mthLenV3f(mthVector3f(box.x,0,box.z))+2)/2
      worldGlobals.RPGIronMaidenEffects[monster] = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("IronMaidenSpikes",worldInfo,qvEffect)
      worldGlobals.RPGIronMaidenEffects[monster]:SetParent(monster,"")
      worldGlobals.RPGIronMaidenEffects[monster]:SetShaderArgValCOLOR("Color",180,255,240,100)
      RunHandled(function()
        local fLifeTime = 0
        while not IsDeleted(worldGlobals.RPGIronMaidenEffects[monster]) do
          local tempPlayer = GetLocalViewer()
          if not IsDeleted(localPlayer) then
            local dist = mthLenV3f(qvEffect:GetVect()-localPlayer:GetPlacement():GetVect())
            worldGlobals.RPGIronMaidenEffects[monster]:SetStretch(mthMinF(dist/30+1,7)*size*fLifeTime)
          end
          if IsDeleted(monster) then
            worldGlobals.RPGIronMaidenEffects[monster]:Delete()
            break
          end
          if not (tempPlayer == false) then localPlayer = tempPlayer end
          fLifeTime = mthMinF(fLifeTime + Wait(CustomEvent("OnStep")):GetTimeStep(),1)
        end
      end,
        
      On(Delay(1)), function()
        if IsDeleted(worldGlobals.RPGIronMaidenEffects[monster]) then return end
        worldGlobals.RPGIronMaidenEffects[monster]:SetShaderArgValCOLOR("Color",255,255,255,100)
      end,
      
      OnEvery(Delay(0.1)), function()
        if IsDeleted(worldGlobals.RPGIronMaidenEffects[monster]) then return end
        if IsDeleted(localPlayer) and not effectEnabled then
          worldGlobals.RPGIronMaidenEffects[monster]:Appear()
          effectEnabled = true
        else
          if not CanPlayerSeeEnemy(localPlayer,monster) and effectEnabled then
            worldGlobals.RPGIronMaidenEffects[monster]:Disappear()
            effectEnabled = false
          end
          if CanPlayerSeeEnemy(localPlayer,monster) and not effectEnabled then
            worldGlobals.RPGIronMaidenEffects[monster]:Appear()
            effectEnabled = true
          end
        end      
      end)
    end
  end)
end
worldGlobals.CreateRPC("server","reliable","RPGIMEffectSwitch",function(monster,bSwitch)
  RPGIMEffectSwitch(monster,bSwitch)
end)
local HandleIronMaiden = function(monster)
  RunAsync(function()
    Wait(Delay(3+RNG:RndF()*3))
    while not IsDeleted(monster) do
      if not monster:IsAlive() then break end
      if worldInfo:IsSinglePlayer() then
        RPGIMEffectSwitch(monster,true)
      else
        worldGlobals.RPGIMEffectSwitch(monster,true)
      end
      Wait(Delay(1))      
      if IsDeleted(monster) then break end
      worldGlobals.RPGIronMaiden[monster] = true  
      Wait(Delay(4))
      if IsDeleted(monster) then break end
      worldGlobals.RPGIronMaiden[monster] = false
      if worldInfo:IsSinglePlayer() then
        RPGIMEffectSwitch(monster,false)
      else
        worldGlobals.RPGIMEffectSwitch(monster,false)
      end 
      Wait(Delay(4+RNG:RndF()*4))         
    end
  end)
end

--LIFE REGEN
local HandleLifeRegen = function(monster)
  RunAsync(function()
    while not IsDeleted(monster) do
      if not monster:IsAlive() then break end
      monster:SetCurrentHealth(mthMinF(monster:GetMaxHealth(),monster:GetHealth()+5))
      Wait(Delay(0.25))  
    end    
  end)
end

--AMMO STEAL
worldGlobals.RPGStolenAmmo = {}
worldGlobals.RPGHandleAmmoSteal = function(monster,player,damage)
  RunAsync(function()
    local weapon = player:GetRightHandWeapon()
    if weapon then
      local weaponParams = weapon:GetParams()
      if (player:GetMaxAmmoForWeapon(weaponParams) > 0) then
        local stolenShare = damage/200
        local stolenAmmo = mthFloorF(mthMinF(player:GetMaxAmmoForWeapon(weaponParams)*stolenShare,player:GetAmmoForWeapon(weaponParams)))
        player:SetAmmoForWeapon(weaponParams,player:GetAmmoForWeapon(weaponParams)-stolenAmmo)
        Wait(Event(monster.Died))
        if (stolenShare >= 0.1) then
          player:AwardAmmoForWeapon(weaponParams,mthCeilF(stolenAmmo*0.75))
        elseif (RNG:RndF() < 0.75) then
          player:AwardAmmoForWeapon(weaponParams,stolenAmmo)
        end
      end
    end
  end)
end

--KNOCKBACK
local KnockbackSounds = {}
for i=1,2,1 do
  KnockbackSounds[i] = LoadResource("Content/SeriousSamFusion/Scripts/Templates/SeriousRPG/Sounds/Knockback0"..i..".wav")
end
local PlayerWeaponsDisabled = {}
local KnockPlayerBack = function(player,vDir)
  RunAsync(function()
    local knockbackSound = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("FreezeSound",worldInfo,player:GetPlacement())
    knockbackSound:SetSound(KnockbackSounds[worldGlobals.RPGRndL(1,#KnockbackSounds)])
    knockbackSound:PlayOnce()
    Wait(Delay(2))
    if not IsDeleted(knockbackSound) then
      knockbackSound:Delete()
    end      
  end)    
  RunAsync(function()
    if player:IsLocalOperator() then
      local lookDir = player:GetLookDirEul()
      local qvLookTarget = player:GetLookOrigin()
      qvLookTarget:SetVect(qvLookTarget:GetVect()+100*mthEulerToDirectionVector(lookDir))
      local lookTarget = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("LookTarget",worldInfo,qvLookTarget)      
      lookTarget:SetParent(player,"")
      player:SetLookTarget(lookTarget) 
      Wait(CustomEvent("OnStep"))
      local qvPlayer = player:GetPlacement()
      qvPlayer.vy = qvPlayer.vy + 1
      local vel = vDir*25
      vel.y = 10
      player:SetPlacement(qvPlayer)
      player:SetLinearVelocity(vel)     
      Wait(CustomEvent("OnStep"))
      lookTarget:Delete()  
    else
      local vel = vDir*25
      vel.y = 10
      player:SetLinearVelocity(vel)        
    end
  end)
end
worldGlobals.CreateRPC("server","reliable","RPGKnockPlayerBack",function(player,vDir)
  KnockPlayerBack(player,vDir)
end)
local PlayerRecentlyKnockedBack = {}
local PlayerHeldWeapon = {}
worldGlobals.RPGHandleKnockback = function(monster,player,vPoint)
  if PlayerRecentlyKnockedBack[player] then return end
  RunAsync(function()
    local diff = player:GetPlacement():GetVect() - vPoint
    diff.y = 0
    if (mthLenV3f(diff) > 0.01) then
      PlayerRecentlyKnockedBack[player] = true
      if worldInfo:IsSinglePlayer() then
        KnockPlayerBack(player,mthNormalize(diff))
      else
        worldGlobals.RPGKnockPlayerBack(player,mthNormalize(diff))
      end
      Wait(CustomEvent("OnStep"))
      if player:GetRightHandWeapon() then
        PlayerHeldWeapon[player] = player:GetRightHandWeapon():GetParams()
      end
      player:DisableWeapons()
      Wait(Delay(0.6))
      player:EnableWeapons()
      if PlayerHeldWeapon[player] then
        player:SelectWeapon(PlayerHeldWeapon[player])
      end
      PlayerHeldWeapon[player] = nil      
      PlayerRecentlyKnockedBack[player] = false
    end
  end)
end

--VORTEX
local vortexTime = 0.7
local vortexRadius = 40
local WhooshSounds = {}
for i=1,2,1 do
  WhooshSounds[i] = LoadResource("Content/SeriousSamFusion/Scripts/Templates/SeriousRPG/Sounds/Whoosh0"..i..".wav")
end
local VortexPlayers = function(monster, Players)
  for i=1,#Players,1 do
    local player = Players[i]
    local vel = (monster:GetPlacement():GetVect()-player:GetPlacement():GetVect())/vortexTime
    vel.y = mthMinF(vel.y,4/vortexTime) - 1/vortexTime + 15*vortexTime
    if player:IsLocalOperator() then
      RunAsync(function()
        local whooshSound = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("WhooshSound",worldInfo,player:GetPlacement())
        whooshSound:SetSound(WhooshSounds[worldGlobals.RPGRndL(1,#WhooshSounds)])
        whooshSound:PlayOnce()
        Wait(Delay(2))
        if not IsDeleted(whooshSound) then
          whooshSound:Delete()
        end        
      end)          
      local lookDir = player:GetLookDirEul()
      local qvLookTarget = player:GetLookOrigin()
      qvLookTarget:SetVect(qvLookTarget:GetVect()+100*mthEulerToDirectionVector(lookDir))
      local lookTarget = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("LookTarget",worldInfo,qvLookTarget)      
      lookTarget:SetParent(player,"")
      player:SetLookTarget(lookTarget) 
      Wait(CustomEvent("OnStep"))
      local qvPlayer = player:GetPlacement()
      qvPlayer.vy = qvPlayer.vy + 1
      player:SetPlacement(qvPlayer)
      player:SetLinearVelocity(vel)     
      Wait(CustomEvent("OnStep"))
      lookTarget:Delete()  
    else
      player:SetLinearVelocity(vel)        
    end    
  end
end
worldGlobals.CreateRPC("server","reliable","RPGVortexPlayers",function(monster,IDString)
  local PlayerIDs = {}
  while not (IDString == "") do
    local index = string.find(IDString,"|")
    PlayerIDs[string.sub(IDString,1,index-1)] = true
    IDString = string.sub(IDString,index+1,-1)     
  end  
  local AllPlayers = worldInfo:GetAllPlayersInRange(monster,vortexRadius*1.5)
  local VortexedPlayers = {}
  for i=1,#AllPlayers,1 do
    if PlayerIDs[AllPlayers[i]:GetPlayerId()] then
      VortexedPlayers[#VortexedPlayers+1] = AllPlayers[i]
    end
  end
  VortexPlayers(monster,VortexedPlayers)
end)
local HandleVortexElite = function(monster)
  RunAsync(function()
    while not IsDeleted(monster) do
      if not monster:IsAlive() then break end  
      if (monster:GetFoe() ~= nil) then
        local Players = worldInfo:GetAllPlayersInRange(monster,vortexRadius)
        local IDString = ""
        for i=1,#Players,1 do
          IDString = IDString..Players[i]:GetPlayerId().."|"
        end
        if worldInfo:IsSinglePlayer() then
          VortexPlayers(monster,Players)
        else
          worldGlobals.RPGVortexPlayers(monster,IDString)
        end        
      end
      Wait(Delay(6*(1+0.5*RNG:RndF())))
      while (worldGlobals.RPGMonsterLastDamagedTimer[monster] < 3) do
        Wait(CustomEvent("OnStep"))
      end
    end    
  end)  
end

--TELEPORTING
local MonsterTeleportEffects = function(monster)
  RunAsync(function()
    local qvEffect = monster:GetPlacement()
    local box = monster:GetBoundingBoxSize()
    qvEffect.vy = qvEffect.vy + box.y/2
    local monsterRadius = mthLenV3f(mthVector3f(box.x,0,box.z))
    local teleportEffect
    if (monsterRadius < 2) then
      teleportEffect = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("TeleportingEffectSmall",worldInfo,qvEffect)
    elseif (monsterRadius < 4) then
      teleportEffect = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("TeleportingEffectMed",worldInfo,qvEffect)
    else
      teleportEffect = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("TeleportingEffectBig",worldInfo,qvEffect)
    end
    local teleportSound = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("TeleportingSound",worldInfo,qvEffect) 
    teleportSound:SetParent(monster,"")
    teleportEffect:Start()
    teleportSound:PlayOnce()
    Wait(Delay(2))
    if not IsDeleted(teleportEffect) then
      teleportEffect:Delete()
    end 
    if not IsDeleted(teleportSound) then
      teleportSound:Delete()
    end               
  end)
end
worldGlobals.CreateRPC("server","reliable","RPGMonsterTeleportEffects",function(monster)
  MonsterTeleportEffects(monster)
end)

local HandleTeleportingElite = function(monster)
  RunAsync(function()
    while not IsDeleted(monster) do
      if not monster:IsAlive() then break end
      local foe = monster:GetFoe()
      if (foe ~= nil) then
        if (worldInfo:GetDistance(foe,monster) < 100) then
          if worldInfo:IsSinglePlayer() then
            MonsterTeleportEffects(monster)
          else
            worldGlobals.RPGMonsterTeleportEffects(monster)
          end
          monster:DisablePlayerFoes(true)
          monster:LoseFoe()
          monster:StopMoving()     
          Wait(Delay(0.25))
          if not IsDeleted(foe) then
            local qvTeleport = foe:GetPlacement()
            qvTeleport:SetQuat(mthEulerToQuaternion(foe:GetLookDirEul()))
            qvTeleport.qh = qvTeleport.qh+Pi
            qvTeleport.qp = 0
            qvTeleport.qb = 0
            qvTeleport:SetVect(qvTeleport:GetVect()-mthQuaternionToDirection(qvTeleport:GetQuat())*0.4)
            monster:SetPlacement(qvTeleport)
          end
          Wait(Delay(1))
          if not IsDeleted(monster) then
            monster:DisablePlayerFoes(false)   
            if not IsDeleted(foe) then
              monster:ForceFoe(foe)
            end
          end
        end
      end
      Wait(Delay(4*(1+0.5*RNG:RndF())))
      while (worldGlobals.RPGMonsterLastDamagedTimer[monster] < 2) do
        Wait(CustomEvent("OnStep"))
      end      
    end    
  end)  
end

--END OF AFFIXES HANDLING

local maxAffixNum = 14
local globalAffixCount = 0

--General function which rolls the affixes for an elite monster
--and runs corresponding functions
worldGlobals.HandleEliteMonster = function(monster,gameLvl)
  local AllowedAffixes = {}
  local health = monster:GetHealth()
  local box = monster:GetBoundingBoxSize()
  local monsterRadius = mthLenV3f(mthVector3f(box.x,0,box.z))
  for i=1,#worldGlobals.RPGUniqueAffixes,1 do
    if ((i ~= 14) or ((health < 500) and (monsterRadius < 3) and (monster:GetCharacterClass() ~= "Gizmo"))) and not worldGlobals.RPGBannedAffixes[worldGlobals.RPGUniqueAffixes[i]] then
      AllowedAffixes[#AllowedAffixes+1] = worldGlobals.RPGUniqueAffixes[i]
    end
  end
  local totalAffixesChance
  if (gameLvl < 11) then
    totalAffixesChance = 1
  elseif (gameLvl < 21) then
    totalAffixesChance = 1+(gameLvl-10)*(gameLvl-10)/200
  elseif (gameLvl < 31) then
    totalAffixesChance = 2
  elseif (gameLvl < 41) then
    totalAffixesChance = 2+(gameLvl-30)*(gameLvl-30)/200    
  elseif (gameLvl < 51) then
    totalAffixesChance = 3
  elseif (gameLvl < 61) then
    totalAffixesChance = 3+(gameLvl-50)*(gameLvl-50)/200   
  else
    totalAffixesChance = 4
  end
  local numberOfAffixes = mthFloorF(totalAffixesChance)
  if (RNG:RndF() < totalAffixesChance-mthFloorF(totalAffixesChance)) then
    numberOfAffixes = numberOfAffixes + 1
  end
  numberOfAffixes = mthMinF(numberOfAffixes,#AllowedAffixes)
  local eliteString = ""
  local affixNum = worldGlobals.RPGRndL(1,#AllowedAffixes)
  for i=1,numberOfAffixes,1 do
    while worldGlobals.MonsterUniqueAffixes[monster][AllowedAffixes[affixNum]] do
      affixNum = worldGlobals.RPGRndL(1,#AllowedAffixes)
    end  
    worldGlobals.MonsterUniqueAffixes[monster][AllowedAffixes[affixNum]] = true
    eliteString = eliteString..AllowedAffixes[affixNum].."|"    
  end
  
  if worldGlobals.MonsterUniqueAffixes[monster]["Extra Fast"] then
    monster:SetCustomSpeedMultiplier(1.5)
  else
    monster:SetCustomSpeedMultiplier(1.1)
  end
  if worldGlobals.MonsterUniqueAffixes[monster]["Corpse Explosion"] then
    HandleCorpseExplosion(monster)
  end
  if worldGlobals.MonsterUniqueAffixes[monster]["Iron Maiden"] then
    HandleIronMaiden(monster)
  end  
  if worldGlobals.MonsterUniqueAffixes[monster]["Life Regen"] then
    HandleLifeRegen(monster)
  end  
  if worldGlobals.MonsterUniqueAffixes[monster]["Vortex"] then
    HandleVortexElite(monster)
  end
  if worldGlobals.MonsterUniqueAffixes[monster]["Teleporting"] then
    HandleTeleportingElite(monster)
  end  
  monster.net_isElite = eliteString
  monster:SetHealth(mthCeilF(health*4000/(health+1000)))
  return (health*(2+numberOfAffixes/2))
end

--Functions which handle elite monsters visuals (affix panel model)
local eliteBias = mthVector3f(7.5,1,0)
local RecreateAffixPanel = function(MonsterAffixes)
  local panel = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("AffixesPanel",worldInfo,worldInfo:GetPlacement())
  for i=1,4,1 do
    panel:SetShaderArgValFloat("0"..i.."U",0)
    panel:SetShaderArgValFloat("0"..i.."V",0)
    panel:SetShaderArgValFloat("1"..i.."U",0)
    panel:SetShaderArgValFloat("1"..i.."V",0)
  end
  for i=1,#MonsterAffixes,1 do
    local num = AffixToNumber[MonsterAffixes[i]]
    panel:SetShaderArgValFloat((#MonsterAffixes%2)..i.."U",(num%8)*0.125)
    panel:SetShaderArgValFloat((#MonsterAffixes%2)..i.."V",(num-num%8)/8*0.25)
  end  
  return panel
end

worldGlobals.HandleEliteVisuals = function(monster)
  local box = monster:GetBoundingBoxSize()
  local size = (mthLenV3f(mthVector3f(box.x,0,box.z))+2)/15
  if (size > 10000) then
    return
  end  
  local temp = monster.net_isElite
  local MonsterAffixes = {}
  while not (temp == "") do
    local index = string.find(temp,"|")
    MonsterAffixes[#MonsterAffixes+1] = string.sub(temp,1,index-1)
    temp = string.sub(temp,index+1,-1)     
  end
  --affixPanel : CStaticModelEntity
  local affixPanel = RecreateAffixPanel(MonsterAffixes)
  local panelEnabled = true

  RunHandled(function()
    while not IsDeleted(monster) do
     
      monster:SetAmbientBias(eliteBias)
      local tempPlayer = GetLocalViewer()
    
      if not IsDeleted(localPlayer) then
        if IsDeleted(affixPanel) then
          affixPanel = RecreateAffixPanel(MonsterAffixes)
          if not panelEnabled then
            affixPanel:Disappear()
          end
        end    
        local qvMonster = monster:GetPlacement()
        local dist = mthLenV3f(qvMonster:GetVect()-localPlayer:GetPlacement():GetVect())
        qvMonster.vy = qvMonster.vy + monster:GetBoundingBoxSize().y*(1-0.01-(mthMinF(dist/30+1,7)*0.02))
        local dir = mthEulerToQuaternion(localPlayer:GetLookDirEul())    
        qvMonster:SetQuat(dir)
        qvMonster = mthMulQV(qvMonster,QV(0,0,0,Pi,0,0))
        qvMonster:SetVect(qvMonster:GetVect()+monster:GetLinearVelocity()*worldInfo:SimGetStep())    
        affixPanel:SetPlacement(qvMonster)
        affixPanel:SetStretch(mthMinF(dist/30+1,7)*size)
      else
        if not IsDeleted(affixPanel) then
          affixPanel:Delete()
        end        
      end    
      if not (tempPlayer == false) then localPlayer = tempPlayer end
      if not monster:IsAlive() then break end    
      
      Wait(CustomEvent("OnStep"))
    end
  end,
  
  OnEvery(Delay(0.1)), function()
    if IsDeleted(monster) or IsDeleted(localPlayer) or IsDeleted(affixPanel) then return end
    if CanPlayerSeeEnemy(localPlayer,monster) and not panelEnabled then
      panelEnabled = true
      affixPanel:Appear()
    end
    if not CanPlayerSeeEnemy(localPlayer,monster) and panelEnabled then
      panelEnabled = false
      affixPanel:Disappear()
    end      
  end)
  
  if not IsDeleted(affixPanel) then
    affixPanel:Delete()
  end  
end

local searching = false
local FindPlayer = function()
  while IsDeleted(localPlayer) do
    local Players = worldInfo:GetAllPlayersInRange(worldInfo, 10000)
    for i=1,#Players,1 do
      if Players[i]:IsLocalOperator() then
        localPlayer = Players[i]
        searching = false
        break
      end
    end
    Wait(CustomEvent("OnStep"))
  end
end

RunHandled(WaitForever,

OnEvery(CustomEvent("OnStep")),
function()
  if IsDeleted(localPlayer) then
    if not searching then
      searching = true
      RunAsync(FindPlayer)
    end
  end  
end)