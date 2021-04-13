--Serious RPG main script
--by NSKuber

--monster : CLeggedCharacterEntity
--damage : CReceiveDamageScriptEvent
--player : CPlayerPuppetEntity
--gameInfo : CGameInfo
--item : CGenericItemEntity
--Templates : CTemplatePropertiesHolder
--endChapter : CChapterInfoEntity
--weapon : CWeaponEntity
--RNG : CRandomNumberGenerator

--Preliminary setup

local worldInfo = worldGlobals.worldInfo
worldGlobals.WSMBanned = true
worldGlobals.FAWSUBanned = true
Wait(CustomEvent("OnStep"))
worldGlobals.RPGDoubleJumpEnabled = true
if (worldGlobals.DoubleJumpEnabled == false) then
  worldGlobals.RPGDoubleJumpEnabled = false
end
worldGlobals.DoubleJumpEnabled = false

dofile("Content/SeriousSamFusion/Scripts/SeriousRPG/RPGMenu.lua")
dofile("Content/SeriousSamFusion/Scripts/SeriousRPG/UniqueMonsters.lua")

local div = function(a,b)
  return (a-a%b)/b
end

local diffAmmoMult = 1
local diff = worldInfo:GetGameDifficulty()
local diffDamageMult = worldGlobals.RPGDifficultyDamageMultiplier[diff]
if (not worldGlobals.RPGisBFE and ((diff == "Tourist") or (diff == "Easy") or (diff == "Serious")))
     or (worldGlobals.RPGisBFE and (diff == "Tourist")) then
  diffAmmoMult = 2
elseif worldGlobals.RPGisBFE and (diff == "Easy") then
  diffAmmoMult = 1.5
end

local jumpSpeed = 11
if worldGlobals.RPGisBFE then
  jumpSpeed = 8.5
end

local playerMaxHealth = 100
if (diff == "Tourist") or (diff == "Easy") then
  playerMaxHealth = 200
end

local Weapons = worldGlobals.RPGWeapons

local WeaponParamsPaths = worldGlobals.RPGWeaponParamsPaths

local WeaponParams = {}
for weapon, path in pairs(WeaponParamsPaths) do
  WeaponParams[weapon] = LoadResource(path)
end

local WeaponAmmoPaths = worldGlobals.RPGWeaponAmmoPaths

local WeaponItemPaths = worldGlobals.RPGWeaponItemPaths

local WeaponNames = worldGlobals.RPGWeaponNames

local ReverseWeaponParams = {}
for name,path in pairs(WeaponParamsPaths) do
  ReverseWeaponParams[path] = name
end               
                          
netPrepareClassForScriptNetSync("CPlayerPuppetEntity")

RegisterNetworkDescriptor("NetDescriptor.MonsterSeriousRPG",
                          {{"server", "CString", "net_isElite"}})
                          
local RegularEnemyClasses = {
  ["CLeggedCharacterEntity"] = true,
  ["CSpiderPuppetEntity"] = true,
  ["CCaveDemonPuppetEntity"] = true,
  ["CPsykickPuppetEntity"] = true,
  ["CKhnumPuppetEntity"] = true,
  ["CAircraftCharacterEntity"] = true,
  ["CSS1LavaElementalPuppetEntity"] = true,     
  ["CSS1CannonRotatingEntity"] = true,   
  ["CSS1CannonStaticEntity"] = true,  
}  

local IsProjectileClass = {
  ["CGenericProjectileEntity"] = true,
  ["CAutoShotgunProjectileEntity"] = true,
}

local SniperResistantEnemies = {
  ["ReptiloidBig"] = 0.5,         
  ["ReptiloidHuge"] = 0.5,   
  ["WalkerRed"] = 0.5,   
  ["WalkerBlue"] = 0.5,   
  ["Demon"] = 0.5,   
  ["ExotechLarva"] = 0.66,   
  ["Khnum"] = 0.75,
}

for class,_ in pairs(RegularEnemyClasses) do
  netPrepareClassForScriptNetSync(class)
end

local time = GetDateTimeLocal()
local seed = 3600*tonumber(string.sub(time,-8,-7))+60*tonumber(string.sub(time,-5,-4))+tonumber(string.sub(time,-2,-1))
local RNG = CreateRandomNumberGenerator(seed + mthTruncF(mthRndF() * 1000))
worldGlobals.RPGRndL = function(a,b)
  return (mthFloorF(RNG:RndF()*(b-a+1))%(b-a+1)+a)
end

local gameInfo = worldInfo:GetGameInfo()
worldGlobals.RPGExpModifier = gameInfo:GetSessionValueFloat("RPGExpModifier")
worldGlobals.RPGEliteChance = gameInfo:GetSessionValueFloat("RPGEliteChance")
if (worldGlobals.RPGExpModifier == 0) then 
  if not worldGlobals.RPGisBFE then
    worldGlobals.RPGExpModifier = 1
  elseif scrFileExists("Content/SeriousSam3/Levels/02_DLC/01_Philae/01_Philae.wld") then
    worldGlobals.RPGExpModifier = 1.2
  else
    worldGlobals.RPGExpModifier = 1.6
  end
end
local baseEliteChance = 0.1
if (worldGlobals.RPGEliteChance == 0) then 
  worldGlobals.RPGEliteChance = baseEliteChance
end
if (worldGlobals.RPGEliteChance == -1) then 
  worldGlobals.RPGEliteChance = 0
end

RunAsync(function()
  if scrFileExists("Content/SeriousSam3/Levels/02_DLC/01_Philae/01_Philae.wld") then
    Wait(Delay(1))
    if (worldInfo:GetWorldFileName() == "Content/SeriousSam3/Levels/01_BFE/09_Luxor/09_Luxor.wld") then
      local endChapter = worldInfo:GetEntityByID("CChapterInfoEntity",14508)
      endChapter:SetNextLevel("Content/SeriousSam3/Levels/02_DLC/01_Philae/01_Philae.wld")
    elseif (worldInfo:GetWorldFileName() == "Content/SeriousSam3/Levels/02_DLC/03_TempleOfSethirkopshef/03_TempleOfSethirkopshef.wld") then
      local endChapter = worldInfo:GetEntityByID("CChapterInfoEntity",5889)
      endChapter:SetNextLevel("Content/SeriousSam3/Levels/01_BFE/10_LostNubianTemples/10_LostNubianTemples.wld")    
      local cutsceneChapter = worldInfo:GetEntityByID("CChapterInfoEntity",7185)
      Wait(Event(cutsceneChapter.Started))
      Wait(Delay(41))
      endChapter:Start()
    end
  end
end)

local levelJustStarted = true

local menuCommand = "plcmdRPGMenu"
if corIsAppEditor() then menuCommand = "plcmdVoiceComm" end

local Level = {}
local Experience = {}
local Attributes = {}
local Stats = {}
local Skills = {}
local Upgrades = {}
local Respecs = {}
local DamageRemainder = {}
local IsMonsterHandled = {}
local ReaperHealingRemainder = {}
local JustReceivedSelfDamage = {}

local ExpToNextLevel = {}
local ExpForLevel = {}
ExpForLevel[1] = 0
for i=1,200,1 do
  ExpToNextLevel[i] = mthFloorF((280 * i)*(1+(i+59)/40*baseEliteChance))
  ExpForLevel[i+1] = ExpForLevel[i] + ExpToNextLevel[i]
end

local expTextEffect = LoadResource(worldGlobals.expTextPath)
local deathTextEffect = LoadResource("Content/Shared/Databases/TextEffect/RPG/PleaseLoad.tfx")

worldGlobals.RPGTemplates = LoadResource("Content/SeriousSamFusion/Scripts/Templates/SeriousRPG/SeriousRPG.rsc")
local menuSwitch = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("MenuSwitch",worldInfo,worldInfo:GetPlacement())

--Function which resets abilities and skills for a player who wishes to 'respec'
local ResetAbilitiesAndSkills = function(player)
  for i=1,#worldGlobals.StatUpgrades,1 do
    Stats[player][i] = 0
  end
  for i,weapon in pairs(Weapons) do
    Upgrades[player][weapon] = {}
    for j=1,4,1 do
      Upgrades[player][weapon][j] = 0
    end
  end  
  player.net_attr = Attributes[player]
  player.net_skill = Skills[player]  
  local temp = ""
  for i=1,#worldGlobals.StatUpgrades,1 do
    temp = temp..Stats[player][i].."|"
  end
  player.net_abilities = temp
  
  player.net_ss = 0
  player.net_ds = 0
  player.net_min = 0
  player.net_rl = 0
  player.net_laser = 0
  player.net_sniper = 0
  player.net_cannon = 0
  if not worldGlobals.RPGisBFE then
    player.net_knife = 0
    player.net_saw = 0
    player.net_colt = 0
    player.net_tom = 0
    player.net_gl = 0
    player.net_flamer = 0
  else
    player.net_hammer = 0
    player.net_pistol = 0
    player.net_ar = 0
    player.net_as = 0
    player.net_sticky = 0        
  end
  
  for i,weapon in pairs(Weapons) do
    for j=1,4,1 do
      gameInfo:SetSessionValueFloat(player:GetPlayerId().."_"..weapon..j,Upgrades[player][weapon][j])
    end 
  end     
  gameInfo:SetSessionValueFloat(player:GetPlayerId().."_attr",Attributes[player]) 
  gameInfo:SetSessionValueFloat(player:GetPlayerId().."_skill",Skills[player])  
  for i=1,#worldGlobals.StatUpgrades,1 do
    gameInfo:SetSessionValueFloat(player:GetPlayerId().."_"..worldGlobals.StatUpgrades[i][4],Stats[player][i])
  end  
end

--Function which sets the XP for the player to
--a certain number, possible leading to lvlups or respecs
worldGlobals.SetExpForPlayer = function(player,XP)
  local downgrade = (XP < Experience[player])
  
  if not downgrade then
    Experience[player] = XP
    while (Experience[player] >= ExpForLevel[Level[player]+1]) do
      Level[player] = Level[player] + 1
      Attributes[player] = Attributes[player] + 1
      Skills[player] = Skills[player] + 1
      if player:IsAlive() and (player:GetHealth() < playerMaxHealth) then
        player:SetHealth(playerMaxHealth)
      end
    end    
  
  else
  
    ResetAbilitiesAndSkills(player)
    Experience[player] = XP      
    Level[player] = 1
    while (Experience[player] >= ExpForLevel[Level[player]+1]) do
      Level[player] = Level[player] + 1
      if player:IsAlive() and (player:GetHealth() < playerMaxHealth) then
        player:SetHealth(playerMaxHealth)
      end
    end
    Respecs[player] = 0
    Attributes[player] = Level[player] - Respecs[player] - 1
    Skills[player] = Level[player] - Respecs[player] - 1       
    
  end
  
  player.net_exp = Experience[player]
  player.net_lvl = Level[player]   
  player.net_attr = Attributes[player]
  player.net_skill = Skills[player]        
  gameInfo:SetSessionValueFloat(player:GetPlayerId().."_resp",Respecs[player])
  gameInfo:SetSessionValueFloat(player:GetPlayerId().."_exp",Experience[player]) 
  gameInfo:SetSessionValueFloat(player:GetPlayerId().."_lvl",Level[player])  
  gameInfo:SetSessionValueFloat(player:GetPlayerId().."_attr",Attributes[player]) 
  gameInfo:SetSessionValueFloat(player:GetPlayerId().."_skill",Skills[player])         
  
end

local AddExperience = function(XP,killer)
  local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
  for i=1,#Players,1 do
    local player = Players[i]
    if (player == killer) then
      worldGlobals.SetExpForPlayer(player,Experience[player]+XP)
    else
      worldGlobals.SetExpForPlayer(player,Experience[player]+XP*0.9)
    end
  end
end


--Handling a monster.
--Each has the damage dealt to it 'filtered'
--to account for all the RPG mod damage multipliers and resistances.
worldGlobals.RPGMonsterLastDamagedTimer = {}

local HandleMonster = function(monster)
  RunAsync(function()
    worldGlobals.RPGMonsterLastDamagedTimer[monster] = 0
    Wait(CustomEvent("OnStep"))
    while levelJustStarted do
      Wait(CustomEvent("OnStep"))
    end
    if IsDeleted(monster) then return end
    if not (monster == monster:GetEffectiveEntity()) then return end
    worldGlobals.MonsterUniqueAffixes[monster] = {}
    local class = monster:GetClassName()
    local characterClass = monster:GetCharacterClass()
    local baseXP = monster:GetHealth()
    if RegularEnemyClasses[class] then
      local gameLvl = 0
      local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
      for i=1,#Players,1 do
        gameLvl = mthMaxF(gameLvl,Level[Players[i]])
      end
      monster:AssignScriptNetworkDescriptor("NetDescriptor.MonsterSeriousRPG")
      if (monster:GetHealth() < 1600) and (RNG:RndF() < worldGlobals.RPGEliteChance) then
        baseXP = worldGlobals.HandleEliteMonster(monster,gameLvl)
      else
        monster.net_isElite = ""
      end
    end
    local LECooldown = 0
    local killer
    if not (monster:GetClassName() == "CSpaceshipPuppetEntity") then
      monster:EnableReceiveDamageScriptEvent(1)
    end
    DamageRemainder[monster] = 0
    
    RunHandled(function()
      Wait(Event(monster.Died))
    end,
    
    OnEvery(CustomEvent("OnStep")),
    function(step)
      LECooldown = mthMaxF(0,LECooldown-step:GetTimeStep())
      worldGlobals.RPGMonsterLastDamagedTimer[monster] = worldGlobals.RPGMonsterLastDamagedTimer[monster] + step:GetTimeStep() 
    end,
    
    OnEvery(Event(monster.ReceiveDamage)),
    function(damage)
      
      if worldGlobals.MonsterUniqueAffixes[monster]["Lightning Enchanted"] and (LECooldown == 0) then
        LECooldown = 1
        worldGlobals.RPGLightningEnchantedHit(monster)
      end
      worldGlobals.RPGMonsterLastDamagedTimer[monster] = 0
    
      killer = damage:GetInflictor()
      local type = damage:GetDamageType()
      local newDamage = damage:GetDamageAmount()
      
      if (killer ~= nil) then
        if (killer:GetClassName() == "CPlayerPuppetEntity") then
          if (damage:GetInflictorWeapon() >= 0) then
            local weapon = ReverseWeaponParams[worldInfo:GetWeaponParamsForIndex(damage:GetInflictorWeapon()):GetFileName()]
            if (weapon ~= nil) then
              weapon = string.gsub(weapon,"Up","")
              weapon = string.gsub(weapon,"+","")
            end
            if not worldGlobals.RPGisBFE then
              --HD PART
              if (weapon == "DoubleColt") then weapon = "Colt" end
              if (weapon == "Knife") or (weapon == "Colt") or (weapon == "SingleShotgun") or (weapon == "DoubleShotgun") or (weapon == "TommyGun") then
                if (Upgrades[killer][weapon][2] > 0) then
                  newDamage = newDamage*(1+worldGlobals.WeaponUpgrades[weapon][2][Upgrades[killer][weapon][2]][4])
                end
              elseif (weapon == "Chainsaw") or (weapon == "MiniGun") then
                if (Upgrades[killer][weapon][1] > 0) then
                  newDamage = newDamage*(1+worldGlobals.WeaponUpgrades[weapon][1][Upgrades[killer][weapon][1]][4])
                end
              elseif (weapon == "Flamer") and (newDamage < 10) then
                if (Upgrades[killer][weapon][2] > 0) then
                  newDamage = newDamage*(1+worldGlobals.WeaponUpgrades[weapon][2][Upgrades[killer][weapon][2]][4])
                end              
              elseif (weapon == "Sniper") and (Upgrades[killer][weapon][3] > 0) and SniperResistantEnemies[characterClass] then
                newDamage = newDamage / SniperResistantEnemies[characterClass]
              end
            else
              --BFE PART
              if (weapon == "Pistol") or (weapon == "bSingleShotgun") or (weapon == "bDoubleShotgun") or (weapon == "AssaultRifle") then
                if (Upgrades[killer][weapon][2] > 0) then
                  newDamage = newDamage*(1+worldGlobals.WeaponUpgrades[weapon][2][Upgrades[killer][weapon][2]][4])
                end
              elseif (weapon == "SledgeHammer") or (weapon == "Axe") or (weapon == "SledgeHammer_M") then
                if (Upgrades[killer][weapon][1] > 0) then
                  newDamage = newDamage*(1+worldGlobals.WeaponUpgrades[weapon][1][Upgrades[killer][weapon][1]][4])
                end       
              elseif (weapon == "bSniper") and (Upgrades[killer][weapon][3] > 0) and SniperResistantEnemies[characterClass] then
                newDamage = newDamage / SniperResistantEnemies[characterClass]
              end              
            end
          end
          
          if killer:IsAlive() and (Stats[killer][14] > 0) then
            ReaperHealingRemainder[killer] = ReaperHealingRemainder[killer]+worldGlobals.StatUpgrades[14][5]*mthMinF(mthFloorF(newDamage),monster:GetHealth())
            if (ReaperHealingRemainder[killer] >= 1) and (killer:GetHealth() < playerMaxHealth) then
              killer:SetHealth(mthMinF(killer:GetHealth()+mthFloorF(ReaperHealingRemainder[killer]),playerMaxHealth))
              ReaperHealingRemainder[killer] = ReaperHealingRemainder[killer] - mthFloorF(ReaperHealingRemainder[killer])    
            end 
          end          
          
        end
      end
      
      if worldGlobals.MonsterUniqueAffixes[monster]["Stone Skin"] then
        newDamage = newDamage/2
      end
      
      if worldGlobals.RPGIronMaiden[monster] then
        if (killer ~= nil) then
          if (killer:GetClassName() == "CPlayerPuppetEntity") then
            killer:InflictDamageOfType(mthMaxF(newDamage/10*diffDamageMult,1),"Punch")
          end
        end
      end      
      
      newDamage = newDamage + DamageRemainder[monster]
      damage:SetDamageAmount(mthFloorF(newDamage))
      DamageRemainder[monster] = newDamage - mthFloorF(newDamage)
      damage:HandleDamage()      
    end)
    
    AddExperience(baseXP*worldGlobals.RPGExpModifier,killer)
  end)
end

--Some weapons have "upgraded" variants.
--This function switches them in the player inventory if needed.
local SwitchWeapons = function(player,name,upgrade01,upgrade02,weapon)
  local removedWeapon = false
  local removedSelectedWeapon = false
  
  if not (upgrade02 < 0) then
    if player:HasWeaponInInventory(WeaponParamsPaths[name.."Up+"]) and (upgrade01+2*upgrade02 ~= 2) then
      player:RemoveWeapon(WeaponParams[name.."Up+"])
      removedWeapon = true
      if (weapon == name.."Up+") then removedSelectedWeapon = true end
    end
    if player:HasWeaponInInventory(WeaponParamsPaths[name.."UpUp+"]) and (upgrade01+2*upgrade02 ~= 3) then
      player:RemoveWeapon(WeaponParams[name.."UpUp+"])
      removedWeapon = true
      if (weapon == name.."UpUp+") then removedSelectedWeapon = true end
    end  
  end
  upgrade02 = mthMaxF(upgrade02,0)
  if player:HasWeaponInInventory(WeaponParamsPaths[name]) and (upgrade01+2*upgrade02 ~= 0) then
    player:RemoveWeapon(WeaponParams[name])
    removedWeapon = true
    if (weapon == name) then removedSelectedWeapon = true end
  end
  if player:HasWeaponInInventory(WeaponParamsPaths[name.."Up"]) and (upgrade01+2*upgrade02 ~= 1) then
    player:RemoveWeapon(WeaponParams[name.."Up"])
    removedWeapon = true
    if (weapon == name.."Up") then removedSelectedWeapon = true end
  end   
  
  if removedWeapon then
    if (upgrade01+2*upgrade02 == 0) then
      player:AwardWeapon(WeaponParams[name])
      if removedSelectedWeapon then player:SelectWeapon(WeaponParams[name]) end
    elseif (upgrade01+2*upgrade02 == 1) then
      player:AwardWeapon(WeaponParams[name.."Up"])
      if removedSelectedWeapon then player:SelectWeapon(WeaponParams[name.."Up"]) end
    elseif (upgrade01+2*upgrade02 == 2) then
      player:AwardWeapon(WeaponParams[name.."Up+"])
      if removedSelectedWeapon then player:SelectWeapon(WeaponParams[name.."Up+"]) end
    elseif (upgrade01+2*upgrade02 == 3) then
      player:AwardWeapon(WeaponParams[name.."UpUp+"])
      if removedSelectedWeapon then player:SelectWeapon(WeaponParams[name.."UpUp+"]) end
    end                  
  end

end

local FixPlayer = function(player)
  local weapon = player:GetRightHandWeapon()
  if weapon then
    weapon = ReverseWeaponParams[weapon:GetParams():GetFileName()]
  end
  if not worldGlobals.RPGisBFE then
    --HD PART
    SwitchWeapons(player,"Knife",Upgrades[player]["Knife"][3],-1,weapon)
    SwitchWeapons(player,"Chainsaw",Upgrades[player]["Chainsaw"][2],Upgrades[player]["Chainsaw"][3],weapon)
    SwitchWeapons(player,"Colt",Upgrades[player]["Colt"][3],-1,weapon)
    SwitchWeapons(player,"DoubleColt",Upgrades[player]["Colt"][3],-1,weapon)
    SwitchWeapons(player,"SingleShotgun",Upgrades[player]["SingleShotgun"][3],-1,weapon)
    SwitchWeapons(player,"DoubleShotgun",Upgrades[player]["DoubleShotgun"][3],-1,weapon)
    SwitchWeapons(player,"TommyGun",Upgrades[player]["TommyGun"][3],-1,weapon)
    SwitchWeapons(player,"MiniGun",Upgrades[player]["MiniGun"][2],-1,weapon)
    SwitchWeapons(player,"GrenadeLauncher",Upgrades[player]["GrenadeLauncher"][2],Upgrades[player]["GrenadeLauncher"][3],weapon)
    SwitchWeapons(player,"RocketLauncher",Upgrades[player]["RocketLauncher"][2],Upgrades[player]["RocketLauncher"][3],weapon) 
    SwitchWeapons(player,"Flamer",Upgrades[player]["Flamer"][3],-1,weapon) 
    SwitchWeapons(player,"Laser",Upgrades[player]["Laser"][2],Upgrades[player]["Laser"][3],weapon)
    SwitchWeapons(player,"Sniper",Upgrades[player]["Sniper"][2],-1,weapon)  
    SwitchWeapons(player,"Cannon",Upgrades[player]["Cannon"][2],-1,weapon)  
  else
    --BFE PART
    SwitchWeapons(player,"SledgeHammer",Upgrades[player]["SledgeHammer"][2],Upgrades[player]["SledgeHammer"][3],weapon)
    SwitchWeapons(player,"SledgeHammer_M",Upgrades[player]["SledgeHammer_M"][2],Upgrades[player]["SledgeHammer_M"][3],weapon)
    SwitchWeapons(player,"Axe",Upgrades[player]["Axe"][2],Upgrades[player]["Axe"][3],weapon)
    SwitchWeapons(player,"Pistol",Upgrades[player]["Pistol"][3],Upgrades[player]["Pistol"][4],weapon)
    SwitchWeapons(player,"bSingleShotgun",Upgrades[player]["bSingleShotgun"][3],-1,weapon)
    SwitchWeapons(player,"bDoubleShotgun",Upgrades[player]["bDoubleShotgun"][3],-1,weapon)
    SwitchWeapons(player,"AssaultRifle",Upgrades[player]["AssaultRifle"][3],-1,weapon)
    SwitchWeapons(player,"bMiniGun",Upgrades[player]["bMiniGun"][2],-1,weapon)
    SwitchWeapons(player,"bRocketLauncher",Upgrades[player]["bRocketLauncher"][2],Upgrades[player]["bRocketLauncher"][3],weapon)     
    SwitchWeapons(player,"AutoShotgun",Upgrades[player]["AutoShotgun"][2],Upgrades[player]["AutoShotgun"][3],weapon)  
    SwitchWeapons(player,"bLaser",Upgrades[player]["bLaser"][2],Upgrades[player]["bLaser"][3],weapon)
    SwitchWeapons(player,"StickyBomb",Upgrades[player]["StickyBomb"][2],Upgrades[player]["StickyBomb"][3],weapon)
    SwitchWeapons(player,"bSniper",Upgrades[player]["bSniper"][2],-1,weapon) 
    SwitchWeapons(player,"bCannon",Upgrades[player]["bCannon"][2],-1,weapon)  
  end
end

local hasServerResponse = false
worldGlobals.CreateRPC("server","reliable","RPGPlayerReady",function(player)
  if player:IsLocalOperator() then
    hasServerResponse = true
  end
end)

--Handling the player's RPG stats, modifiers and resistances.
local HandlePlayer = function(player)
  RunAsync(function()
    
    --Preliminary setup
    
    local temp
    local deathPenaltyApplied = false
    DamageRemainder[player] = 0
    ReaperHealingRemainder[player] = 0.0001
    Respecs[player] = gameInfo:GetSessionValueFloat(player:GetPlayerId().."_resp")
    Experience[player] = gameInfo:GetSessionValueFloat(player:GetPlayerId().."_exp")
    Level[player] = gameInfo:GetSessionValueFloat(player:GetPlayerId().."_lvl")  
    Attributes[player] = gameInfo:GetSessionValueFloat(player:GetPlayerId().."_attr")
    Skills[player] = gameInfo:GetSessionValueFloat(player:GetPlayerId().."_skill")       
    Upgrades[player] = {}
    Stats[player] = {}
    local playerFrozen = 0
    local playerBurning = 0
    local playerCursed = 0
    if (Level[player] == 0) then 
      local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
      if (#Players == 1) then 
        Level[player] = 1
        Experience[player] = ExpForLevel[Level[player]]
        Attributes[player] = Level[player]-1
        Skills[player] = Level[player]-1      
      else
        while levelJustStarted do
          Wait(CustomEvent("OnStep"))
        end
        local newLvl = 0
        local donePlayers = 0
        for i=1,#Players,1 do
          while (Level[Players[i]] == nil) do
            Wait(CustomEvent("OnStep"))
          end
          if (Level[Players[i]] > 0) then 
            newLvl=newLvl+Level[Players[i]]
            donePlayers = donePlayers + 1
          end
        end
        if (donePlayers == 0) then
          donePlayers = 1
          newLvl = 1
        end
        newLvl = mthFloorF(newLvl/donePlayers)
        Experience[player] = ExpForLevel[newLvl]
        Level[player] = newLvl
        Attributes[player] = (newLvl-1)
        Skills[player] = (newLvl-1)
      end
    end
    for i=1,#worldGlobals.StatUpgrades,1 do
      Stats[player][i] = gameInfo:GetSessionValueFloat(player:GetPlayerId().."_"..worldGlobals.StatUpgrades[i][4])
    end
    if (Stats[player][13] == 1) and not worldGlobals.RPGDoubleJumpEnabled then
      Stats[player][13] = 0
      Attributes[player] = Attributes[player] + 5
    end
    for i,weapon in pairs(Weapons) do
      Upgrades[player][weapon] = {}
      for j=1,4,1 do
        Upgrades[player][weapon][j] = gameInfo:GetSessionValueFloat(player:GetPlayerId().."_"..weapon..j)
      end
    end
      
    player:AssignScriptNetworkDescriptor("NetDescriptor.PlayerSeriousRPG")
    player.net_exp = Experience[player]
    player.net_lvl = Level[player]    
    player.net_attr = Attributes[player]
    player.net_skill = Skills[player]  
    temp = ""
    for i=1,#worldGlobals.StatUpgrades,1 do
      temp = temp..Stats[player][i].."|"
    end
    player.net_abilities = temp
    if not worldGlobals.RPGisBFE then
      --HD PART
      temp = Upgrades[player]["Knife"]
      player.net_knife = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["Chainsaw"]
      player.net_saw = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["Colt"]
      player.net_colt = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["SingleShotgun"]
      player.net_ss = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["DoubleShotgun"]
      player.net_ds = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["TommyGun"]
      player.net_tom = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["MiniGun"]
      player.net_min = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["GrenadeLauncher"]
      player.net_gl = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["RocketLauncher"]
      player.net_rl = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["Laser"]
      player.net_laser = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["Flamer"]
      player.net_flamer = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["Sniper"]
      player.net_sniper = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["Cannon"]
      player.net_cannon = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
    else
      --BFE PART
      temp = Upgrades[player]["SledgeHammer"]
      player.net_hammer = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["Pistol"]
      player.net_pistol = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["bSingleShotgun"]
      player.net_ss = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["bDoubleShotgun"]
      player.net_ds = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["AssaultRifle"]
      player.net_ar = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["bMiniGun"]
      player.net_min = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["AutoShotgun"]
      player.net_as = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["bRocketLauncher"]
      player.net_rl = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["bLaser"]
      player.net_laser = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["StickyBomb"]
      player.net_sticky = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["bSniper"]
      player.net_sniper = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
      temp = Upgrades[player]["bCannon"]
      player.net_cannon = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]      
    end
    
    RunAsync(function()
      Wait(Delay(0.1))
      if worldInfo:IsSinglePlayer() then
        hasServerResponse = true
      else
        worldGlobals.RPGPlayerReady(player)
      end
    end)
    
    player:EnableReceiveDamageScriptEvent(1)
    
    local Ammo = {}
    for i, weapon in pairs(Weapons) do
      Ammo[weapon] = player:GetAmmoForWeapon(WeaponParams[weapon])
    end

    RunHandled(function()
      if (worldInfo:GetWorldFileName() == "Content/SeriousSam3/Levels/02_DLC/01_Philae/01_Philae.wld") then
        if player:HasWeaponInInventory(WeaponParamsPaths["bCannon"]) or player:HasWeaponInInventory(WeaponParamsPaths["bCannonUp"]) then
          player:RemoveAllWeapons()
          player:AwardWeapon(WeaponParams["Hands"])
        end 
      end
      while not IsDeleted(player) do 
        Wait(CustomEvent("OnStep")) 
      end
    end,
    
    --Checking differents stats/statuses of the player each frame
    OnEvery(CustomEvent("OnStep")),
    function(step)
      if not IsDeleted(player) then
        local timeStep = step:GetTimeStep()
        playerFrozen = mthMaxF(0,playerFrozen-timeStep)
        playerCursed = mthMaxF(0,playerCursed-timeStep)
        if mthCeilF(playerBurning-timeStep*2.5) < mthCeilF(playerBurning) then
          player:InflictDamageOfType(2*diffDamageMult,"Explosion")
        end
        playerBurning = mthMaxF(0,playerBurning-timeStep*2.5)
        local tempo = player:GetDesiredTempoAbs()
        tempo = mthLenV3f(mthVector3f(tempo.x,0,tempo.z))
        local speedMultiplier = mthVector3f(1,1,1)
        if not (player:GetRightHandWeapon() == nil) then
          local weapon = ReverseWeaponParams[player:GetRightHandWeapon():GetParams():GetFileName()]
          if (weapon ~= nil) then
            weapon = string.gsub(weapon,"Up","")
            weapon = string.gsub(weapon,"+","")
          end
          if ((weapon == "Knife") or (weapon == "Chainsaw") or (weapon == "Hands") or (weapon == "SledgeHammer") or (weapon == "SledgeHammer_M") or (weapon == "Axe")) and (Stats[player][12] > 0) then
            speedMultiplier = speedMultiplier+mthVector3f(worldGlobals.StatUpgrades[12][5],0,worldGlobals.StatUpgrades[12][5])
          end
          if (weapon == "DoubleColt") then weapon = "Colt" end
          if not ((weapon == nil) or (weapon == "Chainsaw") or (weapon == "MiniGun") or (weapon == "SledgeHammer")) then
            if (Upgrades[player][weapon][1] > 0) then
              player:GetRightHandWeapon():SetRateOfFireMultiplier(1+worldGlobals.WeaponUpgrades[weapon][1][Upgrades[player][weapon][1]][4])
            else
              player:GetRightHandWeapon():SetRateOfFireMultiplier(1)
            end
          end
        end
        if not worldGlobals.RPGisBFE or (tempo > 1.4) then
          speedMultiplier = speedMultiplier+mthVector3f(Stats[player][3]*worldGlobals.StatUpgrades[3][5],0,Stats[player][3]*worldGlobals.StatUpgrades[3][5])
        end     
        if (playerFrozen > 0) then
          speedMultiplier.x = speedMultiplier.x/2
          speedMultiplier.z = speedMultiplier.z/2
        elseif (mthLenV3f(player:GetAmbientBias()) > 0) then
          if worldInfo:IsSinglePlayer() then
            player:SetAmbientBias(mthVector3f(0,0,0))
          else
            worldGlobals.RPGUnfreeze(player)
          end
        end
        player:SetSpeedMultiplier(speedMultiplier)
        if not player:IsAlive() then DamageRemainder[player] = 0 end
        local NewAmmo = {}
        for i, weapon in pairs(Weapons) do
          NewAmmo[weapon] = player:GetAmmoForWeapon(WeaponParams[weapon])
        end        
        Wait(CustomEvent("OnStep"))
        Ammo = NewAmmo  
      end
    end,
    
    --Filtering and increasing/reducing damage applied to the player 
    --based on the damage inflictor and player's resistances
    OnEvery(Event(player.ReceiveDamage)),
    function(damage)
      local type = damage:GetDamageType()
      local newDamage = damage:GetDamageAmount()
      
      --Increasing damage from elites
      if (damage:GetInflictor() ~= nil) then
        local inflictor = damage:GetInflictor()
        if RegularEnemyClasses[inflictor:GetClassName()] then
          if (inflictor.net_isElite ~= "") then
            
            local addedDamage = 0
            if worldGlobals.MonsterUniqueAffixes[inflictor]["Cold Enchanted"] then
              addedDamage = addedDamage + newDamage*0.4
              playerFrozen = 4
              worldGlobals.BaseRPGFreezingHit(player)   
            end
            if worldGlobals.MonsterUniqueAffixes[inflictor]["Fire Enchanted"] then
              addedDamage = addedDamage + newDamage*0.4
              playerBurning = 5
              worldGlobals.BaseRPGFireHit(player)
            end      
            if worldGlobals.MonsterUniqueAffixes[inflictor]["Lightning Enchanted"] then
              addedDamage = addedDamage + newDamage*0.4
              worldGlobals.BaseRPGLightningHit(player)
            end     
            if worldGlobals.MonsterUniqueAffixes[inflictor]["Extra Strong"] then
              addedDamage = addedDamage + newDamage
            end            
            if worldGlobals.MonsterUniqueAffixes[inflictor]["Cursed"] then
              playerCursed = 4
              worldGlobals.BaseRPGCursedHit(player)   
            end         
            
            newDamage = newDamage + addedDamage
            
            if worldGlobals.MonsterUniqueAffixes[inflictor]["Ammo Steal"] then
              worldGlobals.RPGHandleAmmoSteal(inflictor,player,newDamage*diffDamageMult)      
            end  
            if worldGlobals.MonsterUniqueAffixes[inflictor]["Knockback"] then
              worldGlobals.RPGHandleKnockback(inflictor,player,damage:GetDamagePoint())      
            end                
          end
        end
        
        if (inflictor == player) then
          JustReceivedSelfDamage[player] = {newDamage,damage:GetDamagePoint()}
          RunAsync(function()
            Wait(Times(2,CustomEvent("OnStep")))
            JustReceivedSelfDamage[player] = false
          end)
        end       
      end      
   
      if (playerCursed > 0) then
        newDamage = newDamage*1.5
      end      
      
      --Resistances
      if (type == "Punch") or (type == "Kicking") or (type == "Sawing") then
        newDamage = newDamage * (1-Stats[player][1]*worldGlobals.StatUpgrades[1][5])
      else
        newDamage = newDamage * (1-Stats[player][2]*worldGlobals.StatUpgrades[2][5])
      end
      
      if (Stats[player][12] > 0) then
        if not (player:GetRightHandWeapon() == nil) then
          local weapon = ReverseWeaponParams[player:GetRightHandWeapon():GetParams():GetFileName()]
          if (weapon ~= nil) then
            weapon = string.gsub(weapon,"Up","")
            weapon = string.gsub(weapon,"+","")
          end
          if (weapon == "Knife") or (weapon == "Chainsaw") or (weapon == "Hands") or (weapon == "SledgeHammer") or (weapon == "SledgeHammer_M") or (weapon == "Axe") then
            newDamage = newDamage * (1-worldGlobals.StatUpgrades[12][5])
          end
        end
      end
      
      newDamage = newDamage + DamageRemainder[player]
      damage:SetDamageAmount(mthFloorF(newDamage))
      DamageRemainder[player] = newDamage - mthFloorF(newDamage)
      damage:HandleDamage()
      if not player:IsAlive() and not deathPenaltyApplied then
        deathPenaltyApplied = true
        Experience[player] = mthMaxF(Experience[player]-ExpToNextLevel[Level[player]]*0.05,ExpForLevel[Level[player]])
        player.net_exp = Experience[player]
        Wait(CustomEvent("OnStep"))
        deathPenaltyApplied = false
      end
    end,
    
    --Handling increased ammo gain (from RPG stat upgrades)
    --when picking up an ammo pack
    OnEvery(CustomEvent(player, "AmmoPackPicked")),
    function()
      local Diff = {}
      for i, weapon in pairs(Weapons) do
        Diff[weapon] = player:GetAmmoForWeapon(WeaponParams[weapon]) - Ammo[weapon]
        if (weapon == "DoubleShotgun") or (weapon == "MiniGun") or (weapon == "bDoubleShotgun") then 
          Diff[weapon] = 0
        end        
        if (Diff[weapon] > 0) then
          if not worldGlobals.RPGisBFE then
            --HD PART
            if (weapon == "SingleShotgun") and (Stats[player][4] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][4]*Diff[weapon]))
            elseif ((weapon == "TommyGun") or (weapon == "MiniGun")) and (Stats[player][5] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][5]*Diff[weapon]))
            elseif (weapon == "Laser") and (Stats[player][8] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][8]*Diff[weapon])) 
            elseif (weapon == "Flamer") and (Stats[player][9] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][9]*Diff[weapon]))                                
            elseif (weapon == "GrenadeLauncher") and (Stats[player][6] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][6]*Diff[weapon]))          
            elseif (weapon == "RocketLauncher") and (Stats[player][7] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][7]*Diff[weapon]))          
            elseif (weapon == "Sniper") and (Stats[player][10] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][10]*Diff[weapon]))          
            elseif (weapon == "Cannon") and (Stats[player][11] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.25*Stats[player][11]*Diff[weapon]))
            end   
          else
            --BFE PART
            if (weapon == "bSingleShotgun") and (Stats[player][4] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][4]*Diff[weapon]))
            elseif (weapon == "AssaultRifle") and (Stats[player][5] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][5]*Diff[weapon]))
            elseif (weapon == "bMiniGun") and (Stats[player][6] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][6]*Diff[weapon]))                                            
            elseif (weapon == "bLaser") and (Stats[player][8] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][8]*Diff[weapon])) 
            elseif (weapon == "AutoShotgun") and (Stats[player][9] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][9]*Diff[weapon]))          
            elseif (weapon == "bRocketLauncher") and (Stats[player][7] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][7]*Diff[weapon]))          
            elseif (weapon == "bSniper") and (Stats[player][10] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.34*Stats[player][10]*Diff[weapon]))          
            elseif (weapon == "bCannon") and (Stats[player][11] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.25*Stats[player][11]*Diff[weapon]))
            end
          end       
        end
      end
    end,
    
    OnEvery(Delay(0.2)),
    function()
      if not IsDeleted(player) then
        FixPlayer(player)
      end
    end,
    
    --Forcing the game load upon player's death in single player
    --because custom single player gamemodes work weirdly
    OnEvery(Event(player.Died)),
    function()
      if worldInfo:IsSinglePlayer() then
        Wait(Delay(0.9))
        SetGlobalData(70209283)
      end
    end)
  end)
end

--Synced function to spend an 'attribute' (player stats upgrade)
worldGlobals.CreateRPC("client","reliable","SpendAttribute", function(player,num)
  if worldGlobals.netIsHost then 
    if (Attributes[player] >= worldGlobals.StatUpgrades[num][1]) then
      local hasSpent = false
      if (Stats[player][num] < worldGlobals.StatUpgrades[num][3]) and (Level[player] >= worldGlobals.StatUpgrades[num][2]) then
        hasSpent = true
        Stats[player][num] = Stats[player][num] + 1
        Attributes[player] = Attributes[player] - worldGlobals.StatUpgrades[num][1]
        gameInfo:SetSessionValueFloat(player:GetPlayerId().."_"..worldGlobals.StatUpgrades[num][4],Stats[player][num]) 
        gameInfo:SetSessionValueFloat(player:GetPlayerId().."_attr",Attributes[player]) 
        player.net_attr = Attributes[player] 
      end
      if hasSpent then
        local temp = ""
        for i=1,#worldGlobals.StatUpgrades,1 do
          temp = temp..Stats[player][i].."|"
        end
        player.net_abilities = temp        
      end
    end
  end
end)

--Synced function to spend a 'skill' (weapon upgrade)
worldGlobals.CreateRPC("client","reliable","SpendSkill", function(player,weapon,upnum)
  if worldGlobals.netIsHost then 
    local grade = upnum%10
    local type = div(upnum,10)    
    if (Skills[player] >= worldGlobals.WeaponUpgrades[weapon][type][grade][1]) then
      local hasSpent = false
      if (Upgrades[player][weapon][type] == grade-1) and (Level[player] >= worldGlobals.WeaponUpgrades[weapon][type][grade][2]) then
        hasSpent = true
        Upgrades[player][weapon][type] = Upgrades[player][weapon][type] + 1
        gameInfo:SetSessionValueFloat(player:GetPlayerId().."_"..weapon..type,Upgrades[player][weapon][type])        
        Skills[player] = Skills[player] - worldGlobals.WeaponUpgrades[weapon][type][grade][1]
        gameInfo:SetSessionValueFloat(player:GetPlayerId().."_skill",Skills[player])  
        if (weapon == "SledgeHammer") then
          Upgrades[player]["SledgeHammer_M"][type] = Upgrades[player]["SledgeHammer_M"][type] + 1
          gameInfo:SetSessionValueFloat(player:GetPlayerId().."_".."SledgeHammer_M"..type,Upgrades[player]["SledgeHammer_M"][type])        
          Upgrades[player]["Axe"][type] = Upgrades[player]["Axe"][type] + 1
          gameInfo:SetSessionValueFloat(player:GetPlayerId().."_".."Axe"..type,Upgrades[player]["Axe"][type])        
        end    
      end
      if hasSpent then
        local temp = Upgrades[player][weapon]
        if not worldGlobals.RPGisBFE then
          --HD PART
          if (weapon == "Knife") then player.net_knife = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "Chainsaw") then player.net_saw = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "Colt") then player.net_colt = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4] 
          elseif (weapon == "SingleShotgun") then player.net_ss = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "DoubleShotgun") then player.net_ds = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]                 
          elseif (weapon == "TommyGun") then player.net_tom = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "MiniGun") then player.net_min = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]     
          elseif (weapon == "GrenadeLauncher") then player.net_gl = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "RocketLauncher") then player.net_rl = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "Laser") then player.net_laser = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "Flamer") then player.net_flamer = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4] 
          elseif (weapon == "Sniper") then player.net_sniper = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "Cannon") then player.net_cannon = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          end
        else
          --BFE PART
          if (weapon == "SledgeHammer") then player.net_hammer = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "Pistol") then player.net_pistol = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4] 
          elseif (weapon == "bSingleShotgun") then player.net_ss = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "bDoubleShotgun") then player.net_ds = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]                 
          elseif (weapon == "AssaultRifle") then player.net_ar = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "bMiniGun") then player.net_min = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]     
          elseif (weapon == "AutoShotgun") then player.net_as = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "bRocketLauncher") then player.net_rl = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "bLaser") then player.net_laser = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "StickyBomb") then player.net_sticky = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4] 
          elseif (weapon == "bSniper") then player.net_sniper = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          elseif (weapon == "bCannon") then player.net_cannon = temp[1]+10*temp[2]+100*temp[3]+1000*temp[4]
          end          
        end  
        player.net_skill = Skills[player]                                                                                            
      end
      FixPlayer(player)
    end
  end
end)

--Ask for a respec
worldGlobals.CreateRPC("client","reliable","Respec", function(player)
  if worldGlobals.netIsHost and (Level[player] > Respecs[player] + 1) then
    
    Respecs[player] = Respecs[player] + 1
    Attributes[player] = Level[player] - Respecs[player] - 1
    Skills[player] = Level[player] - Respecs[player] - 1  
    gameInfo:SetSessionValueFloat(player:GetPlayerId().."_resp",Respecs[player])
      
    ResetAbilitiesAndSkills(player)
  end
end)

--Handle item's  extra ammo gain
local HandleItem = function(item)
  RunAsync(function()
    for name,Paths in pairs(WeaponAmmoPaths) do
      for _,path in pairs(Paths) do
        if (item:GetItemParams():GetFileName() == path[1]) then
          local weapon = name
          while not IsDeleted(item) do
            local pay = Wait(Event(item.Picked))
            local player = pay:GetPicker()     
            if not worldGlobals.RPGisBFE then 
              --HD PART
              if (weapon == "SingleShotgun") and (Stats[player][4] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][4]*path[2]*diffAmmoMult))
              elseif (weapon == "TommyGun") and (Stats[player][5] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][5]*path[2]*diffAmmoMult))
              elseif (weapon == "Flamer") and (Stats[player][9] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][9]*path[2]*diffAmmoMult))                    
              elseif (weapon == "Laser") and (Stats[player][8] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][8]*path[2]*diffAmmoMult))                    
              elseif (weapon == "GrenadeLauncher") and (Stats[player][6] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][6]*path[2]*diffAmmoMult))          
              elseif (weapon == "RocketLauncher") and (Stats[player][7] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][7]*path[2]*diffAmmoMult))          
              elseif (weapon == "Sniper") and (Stats[player][10] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][10]*path[2]*diffAmmoMult))          
              elseif (weapon == "Cannon") and (Stats[player][11] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.25*Stats[player][11]*path[2]*diffAmmoMult))
              end      
            else
              --BFE PART
              if (weapon == "bSingleShotgun") and (Stats[player][4] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][4]*path[2]*diffAmmoMult))
              elseif (weapon == "AssaultRifle") and (Stats[player][5] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][5]*path[2]*diffAmmoMult))
              elseif (weapon == "bMiniGun") and (Stats[player][6] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][6]*path[2]*diffAmmoMult))                    
              elseif (weapon == "bLaser") and (Stats[player][8] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][8]*path[2]*diffAmmoMult))                    
              elseif (weapon == "AutoShotgun") and (Stats[player][9] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][9]*path[2]*diffAmmoMult))          
              elseif (weapon == "bRocketLauncher") and (Stats[player][7] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][7]*path[2]*diffAmmoMult))          
              elseif (weapon == "bSniper") and (Stats[player][10] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.34*Stats[player][10]*path[2]*diffAmmoMult))          
              elseif (weapon == "bCannon") and (Stats[player][11] > 0) then
                player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.25*Stats[player][11]*path[2]*diffAmmoMult))
              end      
            end    
          end
          break
        end
      end
    end
    for name,path in pairs(WeaponItemPaths) do
      if (item:GetItemParams():GetFileName() == path) then
        local weapon = name
        while not IsDeleted(item) do
          local pay = Wait(Event(item.Picked))
          local player = pay:GetPicker()     
          if not worldGlobals.RPGisBFE then 
            --HD PART           
            if ((weapon == "SingleShotgun") or (weapon == "DoubleShotgun")) and (Stats[player][4] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][4]*10))
            elseif (weapon == "TommyGun") and (Stats[player][5] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][5]*100))
            elseif (weapon == "MiniGun") and (Stats[player][5] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][5]*200))
            elseif (weapon == "Flamer") and (Stats[player][9] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][9]*50))                    
            elseif (weapon == "Laser") and (Stats[player][8] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][8]*50))                    
            elseif (weapon == "GrenadeLauncher") and (Stats[player][6] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][6]*10))          
            elseif (weapon == "RocketLauncher") and (Stats[player][7] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][7]*8))          
            elseif (weapon == "Sniper") and (Stats[player][10] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][10]*15))          
            elseif (weapon == "Cannon") and (Stats[player][11] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.25*Stats[player][11]*4))
            end       
          else
            --BFE PART
            if ((weapon == "bSingleShotgun") or (weapon == "bDoubleShotgun")) and (Stats[player][4] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][4]*10))
            elseif (weapon == "AssaultRifle") and (Stats[player][5] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][5]*20))
            elseif (weapon == "bMiniGun") and (Stats[player][6] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][6]*50))
            elseif (weapon == "bLaser") and (Stats[player][8] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][8]*20))                    
            elseif (weapon == "AutoShotgun") and (Stats[player][9] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.1*Stats[player][9]*10))          
            elseif (weapon == "bRocketLauncher") and (Stats[player][7] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.2*Stats[player][7]*5))          
            elseif (weapon == "bSniper") and (Stats[player][10] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.34*Stats[player][10]*5))          
            elseif (weapon == "bCannon") and (Stats[player][11] > 0) then
              player:AwardAmmoForWeapon(WeaponParams[weapon],mthFloorF(0.25*Stats[player][11]*1))
            end             
          end   
        end
        break
      end
    end    
  end)
end

local HandleAmmoPack = function(ammoPack)
  RunAsync(function()
    while not IsDeleted(ammoPack) do
      local pay = Wait(Event(ammoPack.Picked))
      local picker = pay:GetPicker()
      SignalEvent(picker, "AmmoPackPicked")
    end
  end)
end

--Handling elite monsters' visuals
local MonsterGlowHandled = {}
local HandleEliteVisuals = function(monster)
  RunAsync(function()
    if not RegularEnemyClasses[monster:GetClassName()] then return end
    if not (monster == monster:GetEffectiveEntity()) then return end
    if not worldGlobals.netIsHost then
      while not hasServerResponse do
        Wait(CustomEvent("OnStep"))
      end
      Wait(Delay(0.5))
    else
      Wait(Times(2,CustomEvent("OnStep")))
      while levelJustStarted do
        Wait(CustomEvent("OnStep"))
      end
      Wait(CustomEvent("OnStep"))
    end
    if not IsDeleted(monster) then
      if (monster.net_isElite ~= "") then
        worldGlobals.HandleEliteVisuals(monster)
      end
    end
  end)
end


--General handling of the local player (lvlup effects, menu opening, text effects with info displaying) 

local player
local searching = false
local prevVel = mthVector3f(0,0,0)
local justJumped = false
local doubleJumped = false
local justDoubleJumped = false

worldGlobals.RPGMenuOn = false
local menuText = ""
local timer = 0
local prevLvl
local FindPlayer = function()
  while IsDeleted(player) do
    local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
    for i=1,#Players,1 do
      if Players[i]:IsLocalOperator() then
        player = Players[i]
        if not worldGlobals.netIsHost then 
          Stats[player] = {} 
          Upgrades[player] = {}
          for i,weapon in pairs(Weapons) do
            Upgrades[player][weapon] = {}  
          end        
        end
        searching = false
        break
      end
    end
    Wait(CustomEvent("OnStep"))
  end
end

--lvlUp : CParticleEffectEntity
local lvlUpPP = LoadResource(worldGlobals.lvlUpPP)
local lvlUpSound = LoadResource("Content/SeriousSamHD/Sounds/Misc/SeriousRPG/LvlUpPauseLouder.wav")
worldGlobals.lvlUpEffects = function(player)
  RunAsync(function()
    local lvlUp = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("LvlUpEffect",worldInfo,player:GetPlacement())
    lvlUp:SetParent(player)    
    lvlUp:Start()
    worldInfo:Announce(lvlUpSound)
    local timer = 0.6
    while (timer > 0) do
      player:AddPostprocessingLayer(5,lvlUpPP,timer/3,1)
      timer = timer - Wait(CustomEvent("OnStep")):GetTimeStep()
      player:RemovePostprocessingLayer(5)
    end
    Wait(Delay(1.4))
    if not IsDeleted(lvlUp) then
      lvlUp:Delete()
    end
  end)
end

local isPlayerChatting = false
local prevLookDir = mthVector3f(0,0,0)

local damageToEnergy = 300
local energyToUp = 0.5
local puppetEnergyCoefficient = 0.78
local puppetHullHeight = 2.218912
local SquareSum = function(u,v)
  if (u*v > 0) then
    return mthSqrtF(u*u+v*v)*mthSgnF(u)
  elseif (u*v < 0) then
    return mthSqrtF(mthAbsF(u*u-v*v))*mthSgnF(u+v)
  else
    if (u == 0) then return v else return u end
  end  
end
worldGlobals.CreateRPC("server","reliable","SendAppliedForce",function(player,vel)
  player:SetLinearVelocity(vel)
end)

--Handling projectiles to enable rocket jumping
--because handling damage from scripts disables rocket jumping
local HandleProjectile = function(proj)
  RunAsync(function()
    if worldGlobals.RPGisBFE then return end
    local owner
    local Players = worldInfo:GetAllPlayersInRange(proj,20)
    for i=1,#Players,1 do
      local dist = 0
      local weapon = Players[i]:GetRightHandWeapon()
      if (weapon ~= nil) then
        local playerLook = Players[i]:GetPlacement()
        playerLook.vy = playerLook.vy + worldGlobals.CWMViewHeight
        playerLook:SetQuat(mthEulerToQuaternion(Players[i]:GetLookDirEul()))
        local qvBarrel = mthMulQV(playerLook,weapon:GetAttachmentAbsolutePlacement("Barrel01"))
        dist = mthLenV3f(qvBarrel:GetVect()-proj:GetPlacement():GetVect())
      end
      local lookDiff = mthLenV3f(mthEulerToDirectionVector(Players[i]:GetLookDirEul())-mthNormalize(proj:GetLinearVelocity()))       
      if (lookDiff*lookDiff+dist*dist < 1) then
        owner = Players[i]
      end
    end
    if not owner then return end
    local qvProj = proj:GetPlacement()
    local ownerVel = owner:GetLinearVelocity()
    while not IsDeleted(owner) and not IsDeleted(proj) do
      if proj:IsDestroyed() then break end
      ownerVel = owner:GetLinearVelocity()
      qvProj = proj:GetPlacement()
      Wait(CustomEvent("OnStep"))  
    end
    if not IsDeleted(proj) then
      qvProj = proj:GetPlacement()
    end
    if JustReceivedSelfDamage[owner] then
      local qvPlayer = owner:GetPlacement()
      local actionPoint = JustReceivedSelfDamage[owner][2]
      local realDir = actionPoint - qvProj:GetVect()
      realDir.y = realDir.y+mthLenV3f(realDir)*energyToUp
      realDir = mthNormalize(realDir)*mthSqrtF(2*2.25*damageToEnergy*JustReceivedSelfDamage[owner][1]*puppetEnergyCoefficient/owner:GetMass())
      realDir = mthVector3f(SquareSum(realDir.x,ownerVel.x),SquareSum(realDir.y,ownerVel.y),SquareSum(realDir.z,ownerVel.z))
      if worldInfo:IsSinglePlayer() then
        owner:SetLinearVelocity(realDir)      
      else
        worldGlobals.SendAppliedForce(owner,realDir)
      end
    end
  end)
end

if not worldGlobals.SortingEntitySpawnedScriptRunning then
  dofile("Content/Shared/Scripts/SortingEntitySpawnedScript.lua")
end

--Main function which checks different entities and handles those it needs to
RunHandled(function()
  if worldGlobals.netIsHost then
    Wait(CustomEvent("OnStep"))
    local Items = worldInfo:GetAllEntitiesOfClass("CGenericItemEntity")
    for i=1,#Items,1 do 
      HandleItem(Items[i])
    end    
    local AmmoPacks = worldInfo:GetAllEntitiesOfClass("CGenericAmmoPackItemEntity")
    for i=1,#AmmoPacks,1 do
      HandleAmmoPack(AmmoPacks[i])
    end
  end
  WaitForever()
end, 

On(Delay(0.5)),
function()
  levelJustStarted = false
end,

OnEvery(CustomEvent("EntitySpawned_CPlayerPuppetEntity")),
function(spawnedEvent)  
  HandlePlayer(spawnedEvent.spawnee)
end,

OnEvery(CustomEvent("EntitySpawned_CGenericItemEntity")),
function(spawnedEvent)  
  HandleItem(spawnedEvent.spawnee)
end,

OnEvery(CustomEvent("EntitySpawned_CGenericAmmoPackItemEntity")),
function(spawnedEvent)  
  HandleAmmoPack(spawnedEvent.spawnee)
end,

OnEvery(CustomEvent("EntitySpawned_CGenericProjectileEntity")),
function(spawnedEvent)  
  HandleProjectile(spawnedEvent.spawnee)
end,

OnEvery(CustomEvent("EntitySpawned_AutoShotgunProjectileEntity")),
function(spawnedEvent)  
  HandleProjectile(spawnedEvent.spawnee)
end,

OnEvery(Event(worldInfo.PlayerBorn)),
function(born)
  if worldGlobals.netIsHost and not levelJustStarted and (Levels ~= nil) then
    if (Levels[born:GetBornPlayer()] ~= nil) then
      FixPlayer(born:GetBornPlayer())
    end
  end
end,

OnEvery(CustomEvent("OnStep")),
function(step)

  --Handle player text effects information (exp, level, etc) and some individual perks
  timer = timer + step:GetTimeStep()
  
  local Monsters = worldInfo:GetCharacters("","Evil",worldInfo,10000)       
  for i=1,#Monsters,1 do
    if not MonsterGlowHandled[Monsters[i]] then 
      MonsterGlowHandled[Monsters[i]] = true
      HandleEliteVisuals(Monsters[i]) 
    end
    if worldGlobals.netIsHost then
      if not IsMonsterHandled[Monsters[i]] then 
        IsMonsterHandled[Monsters[i]] = true
        HandleMonster(Monsters[i]) 
      end      
    end
  end  

  if not IsDeleted(player) then
    if not worldGlobals.netIsHost then
      if (timer > 1) and hasServerResponse then
        if (prevLvl == nil) then prevLvl = player.net_lvl end
        local expText = ""
        if (player.net_skill > 0) then expText=expText.."Weapon points: "..player.net_skill.."\n" end
        if (player.net_attr > 0) then expText=expText.."Ability points: "..player.net_attr.."\n" end        
        worldInfo:AddLocalTextEffect(expTextEffect, expText.."LVL: "..player.net_lvl.."\nEXP: "..mthFloorF(player.net_exp-ExpForLevel[player.net_lvl]).."/"..ExpToNextLevel[player.net_lvl]) 
        if (player.net_lvl ~= prevLvl) then 
          worldGlobals.lvlUpEffects(player)
          prevLvl = player.net_lvl
        end
        
        Stats[player] = {}
        local temp = player.net_abilities
        for i=1,#worldGlobals.StatUpgrades,1 do
          local index = string.find(temp,"|")
          Stats[player][i] = tonumber(string.sub(temp,1,index-1))
          temp = string.sub(temp,index+1,-1)     
        end        
        
        if not (player:GetRightHandWeapon() == nil) then
          local weapon = ReverseWeaponParams[player:GetRightHandWeapon():GetParams():GetFileName()]
          if (weapon ~= nil) then
            weapon = string.gsub(weapon,"Up","")
            weapon = string.gsub(weapon,"+","")
          end
          local grade
          if not worldGlobals.RPGisBFE then
            if (weapon == "Knife") then grade = mthRoundF(player.net_knife)%10
            elseif (weapon == "Colt") then grade = mthRoundF(player.net_colt)%10
            elseif (weapon == "DoubleColt") then grade = mthRoundF(player.net_colt)%10
            elseif (weapon == "SingleShotgun") then grade = mthRoundF(player.net_ss)%10
            elseif (weapon == "DoubleShotgun") then grade = mthRoundF(player.net_ds)%10
            elseif (weapon == "TommyGun") then grade = mthRoundF(player.net_tom)%10
            elseif (weapon == "GrenadeLauncher") then grade = mthRoundF(player.net_gl)%10
            elseif (weapon == "RocketLauncher") then grade = mthRoundF(player.net_rl)%10
            elseif (weapon == "Laser") then grade = mthRoundF(player.net_laser)%10
            elseif (weapon == "Flamer") then grade = mthRoundF(player.net_flamer)%10
            elseif (weapon == "Sniper") then grade = mthRoundF(player.net_sniper)%10
            elseif (weapon == "Cannon") then grade = mthRoundF(player.net_cannon)%10
            end
          else
            if (weapon == "Pistol") then grade = mthRoundF(player.net_pistol)%10
            elseif (weapon == "bSingleShotgun") then grade = mthRoundF(player.net_ss)%10
            elseif (weapon == "bDoubleShotgun") then grade = mthRoundF(player.net_ds)%10
            elseif (weapon == "AssaultRifle") then grade = mthRoundF(player.net_ar)%10
            elseif (weapon == "MiniGun") then grade = mthRoundF(player.net_min)%10
            elseif (weapon == "AutoShotgun") then grade = mthRoundF(player.net_as)%10
            elseif (weapon == "bRocketLauncher") then grade = mthRoundF(player.net_rl)%10
            elseif (weapon == "bLaser") then grade = mthRoundF(player.net_laser)%10
            elseif (weapon == "StickyBomb") then grade = mthRoundF(player.net_sticky)%10
            elseif (weapon == "bSniper") then grade = mthRoundF(player.net_sniper)%10
            elseif (weapon == "bCannon") then grade = mthRoundF(player.net_cannon)%10
            end
          end          
          if (grade ~= nil) then
            local mult
            if (grade > 0) then
              mult = 1+worldGlobals.WeaponUpgrades[weapon][1][grade][4]
            else
              mult = 1
            end
            player:GetRightHandWeapon():SetRateOfFireMultiplier(mult)
          end
        end    
      else
        Stats[player] = {}
        Stats[player][13] = 0
      end
    elseif (timer > 0.6) and hasServerResponse then
      if (prevLvl == nil) then prevLvl = Level[player] end
      local expText = ""
      if (Skills[player] > 0) then expText=expText.."Weapon points: "..Skills[player].."\n" end
      if (Attributes[player] > 0) then expText=expText.."Ability points: "..Attributes[player].."\n" end
      worldInfo:AddLocalTextEffect(expTextEffect,expText.."LVL: "..Level[player].."\nEXP: "..mthFloorF(Experience[player]-ExpForLevel[Level[player]]).."/"..ExpToNextLevel[Level[player]]) 
      if (Level[player] ~= prevLvl) then 
        worldGlobals.lvlUpEffects(player)
        prevLvl = Level[player]
      end    
    end
    
    --DOUBLE JUMPING
    if (timer > 0.6) and hasServerResponse then
      if (Stats[player][13] > 0) then
        local tempo = player:GetDesiredTempoAbs()
        local vel = player:GetLinearVelocity()
        local speed = player:GetSpeedMultiplier()
        if ((vel.y - prevVel.y) >= 0) and not justDoubleJumped then
          doubleJumped = false
        end
        if (tempo.y >= 1) then
          if ((vel.y - prevVel.y) > 2) then
            justJumped = true
          elseif not justJumped and not doubleJumped then
            tempo.x = tempo.x * jumpSpeed * speed.x
            tempo.y = tempo.y * jumpSpeed * speed.y
            tempo.z = tempo.z * jumpSpeed * speed.z
            player:SetLinearVelocity(tempo)
            player:PlaySchemeSound("Jump")
            doubleJumped = true
            justDoubleJumped = true
            RunAsync(function()
              Wait(Delay(0.2))
              justDoubleJumped = false
            end)
          end
        else
          justJumped = false
        end
        prevVel = vel        
      end      
    end
    local newLookDir = player:GetLookDirEul()
    if ((mthLenV3f(player:GetDesiredTempoAbs()) > 0) or (mthLenV3f(prevLookDir-newLookDir) > 0)) then
      isPlayerChatting = false
    end    
    if player:IsCommandPressed("plcmdTalk") then
      isPlayerChatting = true
    end
    prevLookDir = newLookDir        
    
    if not player:IsAlive() then
      isPlayerChatting = false
    elseif player:IsCommandPressed(menuCommand) and not isPlayerChatting then
      if not worldGlobals.RPGMenuOn then worldGlobals.RPGOpenMenu(player)
      else worldGlobals.RPGMenuOn = false end
      if IsDeleted(menuSwitch) then
        menuSwitch = worldGlobals.RPGTemplates:SpawnEntityFromTemplateByName("MenuSwitch",worldInfo,worldInfo:GetPlacement())
      end 
      menuSwitch:Start()
    end
    
  elseif not searching then
    searching = true
    FindPlayer()
  end
end,

OnEvery(CustomEvent("XML_Log")),
function(LogEvent)
  local line = LogEvent:GetLine()
  if not IsDeleted(player) then
    if (string.find(line, "<chat player=\""..player:GetPlayerName().."\" playerid=\""..player:GetPlayerId()) ~= nil) then
      isPlayerChatting = false
    end
  end
end
)