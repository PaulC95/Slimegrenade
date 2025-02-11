if SERVER then
   AddCSLuaFile("shared.lua")
end

ENT.Type = "anim"
ENT.Base = "ttt_basegrenade_proj"

//ENT.Model = Model("models/mld/duck.mdl")
ENT.Model = Model("models/mcmodelpack/mobs/slime.mdl")

--Change these values to modify damage proporties
ENT.ExplosionDamage = 0
ENT.ExplosionRadius = 0
ENT.TurtleCount 	= 1
deathind = 1

TurtleNPCClass 		= "npc_headcrab_fast"
TurtleInnocentDamage  = 10
TurtleTraitorDamage   = 5
thrower = null
AccessorFunc( ENT, "radius", "Radius", FORCE_NUMBER )
AccessorFunc( ENT, "dmg", "Dmg", FORCE_NUMBER )

local Quack = Sound("Quack.Single")

function ENT:Initialize()
   if not self:GetRadius() then self:SetRadius(256) end
   if not self:GetDmg() then self:SetDmg(0) end
   deathind = 1
   self.BaseClass.Initialize(self)
   
	local phys = self:GetPhysicsObject()
	thrower = self:GetThrower()
	self.Entity:SetModelScale( self.Entity:GetModelScale()*1,0)
	self.Entity:Activate()
	if phys:IsValid() then 
		
		phys:SetMass(350) 
	end
end

function ENT:Explode(tr)

   if SERVER then
      self.Entity:SetNoDraw(true)
      self.Entity:SetSolid(SOLID_NONE)

	  local pos = self.Entity:GetPos()
	  
      -- pull out of the surface
      if tr.Fraction != 1.0 then
         self.Entity:SetPos(tr.HitPos + tr.HitNormal * 0.6)
      end

      --[[if util.PointContents(pos) == CONTENTS_WATER then
         self:Remove()
         return
      end]]--

      local effect = EffectData()
      effect:SetStart(pos)
      effect:SetOrigin(pos)
      effect:SetScale(self.ExplosionRadius * 0.3)
      effect:SetRadius(self.ExplosionRadius)
      effect:SetMagnitude(self.ExplosionDamage)

      if tr.Fraction != 1.0 then
         effect:SetNormal(tr.HitNormal)
      end

      util.Effect("Explosion", effect, true, true)

      util.BlastDamage(self, self:GetThrower(), pos, self.ExplosionRadius,self.ExplosionDamage)--self.ExplosionRadius, self.ExplosionDamage)

      self:SetDetonateExact(0)	

	  Spawnin(self.TurtleCount,self.Entity,(1/(deathind*2)))
	  
      self:Remove()
   else
   
      local spos = self.Entity:GetPos()
      local trs = util.TraceLine({start=spos + Vector(0,0,64), endpos=spos + Vector(0,0,-128), filter=self})
      util.Decal("Scorch", trs.HitPos + trs.HitNormal, trs.HitPos - trs.HitNormal)      

      self:SetDetonateExact(0)
   end

end

function Spawnin(npccount,ent, scale)
	local pos = ent:GetPos()

	for i=1,npccount do

		local spos = pos+Vector(math.random(-75,75),math.random(-75,75),math.random(0,50))
		local contents = util.PointContents( spos )
		local _i = 0
		while i < 10 and (contents == CONTENTS_SOLID or contents == CONTENTS_PLAYERCLIP) do 
			_i = 1 + i
			spos = pos+Vector(math.random(-125,125),math.random(-125,125),math.random(-50,50)) 
			contents = util.PointContents( spos )
		end
		/*

		local slime = ents.Create( "ttt_slimeyboy" )                        
				slime:SetPos(spos)
				
                slime.Creator = thrower
                
                slime:Spawn()
				
		*/

		local headturtle = SpawnNPC(thrower,spos, TurtleNPCClass)
	
		headturtle:SetNPCState(2)
		headturtle:SetModelScale( headturtle:GetModelScale()*12*scale,0)
		//headturtle:SetModelScale( headturtle:GetModelScale()*3*scale,0)
		//print("scaleonspawncrab: " .. headturtle:GetModelScale())

		

		local turtle = ents.Create("prop_dynamic")
		//turtle:SetModel("models/mld/duck.mdl")
		turtle:SetModel("models/mcmodelpack/mobs/slime.mdl")
		turtle:SetPos(spos)
		turtle:SetAngles(Angle(0,-90,0))
		//turtle:SetAngles(Angle(0,0,0))
		turtle:SetParent(headturtle)
		turtle:SetModelScale( turtle:GetModelScale()*12*scale,0)
		//turtle:SetNoDraw(true)
		////print("scaleonspawnslime: " .. turtle:GetModelScale())
		
		--headturtle:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		
		headturtle:SetNWEntity("Thrower", thrower)
		--headturtle:SetName(self:GetThrower():GetName())
		headturtle:SetNoDraw(true)
		headturtle:SetHealth(1000)
		
	end
end

--From: gamemodes\sandbox\gamemode\commands.lua
--TODO: Adjust for TTT.

function SpawnNPC( Player, Position, Class )

	local NPCList = list.Get( "NPC" )
	local NPCData = NPCList[ Class ]
	
	-- Don't let them spawn this entity if it isn't in our NPC Spawn list.
	-- We don't want them spawning any entity they like!
	if ( !NPCData ) then 
		if ( IsValid( Player ) ) then
			Player:SendLua( "Derma_Message( \"Sorry! You can't spawn that NPC!\" )" );
		end
	return end
	
	local bDropToFloor = false
		
	--
	-- This NPC has to be spawned on a ceiling ( Barnacle )
	--
	if ( NPCData.OnCeiling && Vector( 0, 0, -1 ):Dot( Normal ) < 0.95 ) then
		return nil
	end
	
	if ( NPCData.NoDrop ) then bDropToFloor = false end
	
	--
	-- Offset the position
	--
	
	
	-- Create NPC
	local NPC = ents.Create( NPCData.Class )
	if ( !IsValid( NPC ) ) then return end

	NPC:SetPos( Position )
	--
	-- This NPC has a special model we want to define
	--
	if ( NPCData.Model ) then
		NPC:SetModel( NPCData.Model )
	end
	
	--
	-- Spawn Flags
	--
	local SpawnFlags = bit.bor( SF_NPC_FADE_CORPSE, SF_NPC_ALWAYSTHINK)
	if ( NPCData.SpawnFlags ) then SpawnFlags = bit.bor( SpawnFlags, NPCData.SpawnFlags ) end
	if ( NPCData.TotalSpawnFlags ) then SpawnFlags = NPCData.TotalSpawnFlags end
	NPC:SetKeyValue( "spawnflags", SpawnFlags )
	NPC:SetKeyValue("damagefilter", "16384" )
	
	--
	-- Optional Key Values
	--
	if ( NPCData.KeyValues ) then
		for k, v in pairs( NPCData.KeyValues ) do
			NPC:SetKeyValue( k, v )
		end		
	end


	
	--
	-- This NPC has a special skin we want to define
	--
	if ( NPCData.Skin ) then
		NPC:SetSkin( NPCData.Skin )
	end
	
	--
	-- What weapon should this mother be carrying
	--
	
	NPC:Spawn()
	NPC:Activate()
	
	if ( bDropToFloor && !NPCData.OnCeiling ) then
		NPC:DropToFloor()	
	end
	
	return NPC
end



if SERVER and GetConVarString("gamemode") == "terrortown" then

function TurtleNadeDamage(victim, dmg)

	local attacker = dmg:GetAttacker()
	////print("ow")
	////print(dmg:GetDamageType())
	if dmg:IsDamageType(16384) then  return true end
	
	if attacker:IsValid() and attacker:IsNPC() and attacker:GetClass() == TurtleNPCClass then
		if victim:IsTraitor() == false  then
			dmg:SetAttacker(attacker:GetNWEntity("Thrower"))
			dmg:SetDamage(TurtleInnocentDamage)
		else
			dmg:SetDamage(TurtleTraitorDamage)
		end
	end

	
	--Annoyingly complex check to make the headcrab ragdolls invisible
	if victim:GetClass() == TurtleNPCClass then
		dmg:SetDamageType(DMG_REMOVENORAGDOLL)
		--Odd behaviour occured when killing turtles with the 'crowbar'
		--Extra steps had to be taken to reliably hide the ragdoll.
		if dmg:GetInflictor():GetClass() == "weapon_zm_improvised" then
			local turtle = ents.Create("prop_physics")
			//turtle:SetModel("models/mld/duck.mdl")
			turtle:SetModel("models/mcmodelpack/mobs/slime.mdl")
			turtle:SetPos(victim:GetPos())
			turtle:SetAngles(victim:GetAngles() + Angle(0,-90,0))
			turtle:SetColor(Color(160,160,160,255))
			turtle:PhysicsInit( SOLID_VPHYSICS )
			turtle:SetMoveType(  MOVETYPE_VPHYSICS )   
			turtle:SetSolid( SOLID_VPHYSICS )
			turtle:SetModelScale( turtle:GetModelScale()*0.6,0)
			//turtle:SetCollisionGroup(COLLISION_GROUP_NONE)
			turtle:Spawn()
			turtle:Activate()
			
			local phys = turtle:GetPhysicsObject()
			if !(phys && IsValid(phys)) then turtle:Remove() end
		
			victim:SetNoDraw(false)
			victim:SetColor(Color(255,2555,255,1))
			--victim:SetRenderMode(RENDER_TRANSALPHA)
			phys:SetMass(20)
			phys:Sleep()

			victim:Remove()
		end
		if dmg:GetDamageType() == DMG_DROWN then
			dmg:SetDamage(0)
		end

		if (victim:Health() - dmg:GetDamage()) < 980 then
			////print(victim:GetChildren()[1])
			////print(victim:GetChildren()[1]:GetModelRenderBounds())
			//print("victims model scale:")
			//print(victim:GetModelScale())
			////print("deathind: " .. deathind)
			deathind = deathind+1
			if victim:GetModelScale() > 1.6 then
				//print(victim:GetModelRadius())			
				Spawnin(2,victim,(1/(deathind*2)))
			
				victim:Remove()
			return end

			local turtle = ents.Create("prop_physics")
			//turtle:SetModel("models/mld/duck.mdl")
			turtle:SetModel("models/mcmodelpack/mobs/slime.mdl")
			turtle:SetPos(victim:GetPos())
			turtle:SetAngles(victim:GetAngles() + Angle(0,-90,0))
			turtle:SetColor(Color(160,160,160,255))
			turtle:PhysicsInit( SOLID_VPHYSICS )
			turtle:SetMoveType(  MOVETYPE_VPHYSICS )   
			turtle:SetSolid( SOLID_VPHYSICS )
			turtle:SetModelScale( turtle:GetModelScale()*0.6,0)
			//print(turtle:GetModelRadius())
			//turtle:SetCollisionGroup(COLLISION_GROUP_NONE)
			
			turtle:Spawn()
			turtle:Activate()
			
			local phys = turtle:GetPhysicsObject()
			if !(phys && IsValid(phys)) then turtle:Remove() end
			
			
			phys:SetMass(20)
			phys:Sleep()
			
			victim:Remove()
		end
	end
end

hook.Add("EntityTakeDamage","TurtlenadeDmgHandle",TurtleNadeDamage) 
end
