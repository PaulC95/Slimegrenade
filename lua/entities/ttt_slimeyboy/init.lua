AddCSLuaFile( "shared.lua" )

include( 'shared.lua' )


local Wet_Slap = Sound("wet.slap")

local Jump_sound = Sound("Small_Bill.Defeated")
local Hurt_sound = Sound("Bill.Damage")
local fly_sound = Sound("fly.big")
local fly_ramp = Sound("fly.ramp")

util.PrecacheModel("models/mcmodelpack/mobs/slime.mdl")
local HitMax = 10 //the amount of times we can collide with a player or prop before exploding
nexttargetcheck = CurTime() + 1



/*---------------------------------------------------------
   Initialize
---------------------------------------------------------*/
function ENT:Initialize()

        self.Avoidance = false            //do we want bill to avoid colliding with the world while he searches for targets
        self.Circle = false                     //do we want bill to go around in circles while looking for players?     
        self.HadTarget = true                  //if false bill will not do above until after it has aquired first target

        if !self.Scale then self.Scale = 2 end

        self.HitCount =0
        self.Canjump = true

        self.Entity:SetModel("models/mcmodelpack/mobs/slime.mdl")

        self.Entity:SetModelScale( self.Entity:GetModelScale()*1,0)

        //self.Entity:Activate()

        self.Entity:PhysicsInit( SOLID_VPHYSICS )
        self.Entity:SetMoveType(  MOVETYPE_VPHYSICS )   
        self.Entity:SetSolid( SOLID_VPHYSICS )

        self.Entity:SetLagCompensated(true)
        self.Entity:SetHealth(200)
        
       
        self.Target = nil 
        
        // Wake the physics object up. Its time to have fun!
        local phys = self.Entity:GetPhysicsObject()
        if phys:IsValid() then 
                //phys:Wake()
                phys:SetMass(10)
                //phys:SetDamping( 0.01,0.01)
                phys:EnableGravity( true )
                //phys:Sleep()
        end

        print("Canmove? -- ") print(phys:IsMotionEnabled())

        self.Exploded = true
end

/*---------------------------------------------------------
   Initialize II
---------------------------------------------------------*/
function ENT:OnRemove()

        if ( self.Sound ) then
                self.Sound:Stop()
        end

end

function ENT:Think()

        //print("my health is:" .. self:Health() .. "\n" )
        if self.Dead then self.Entity:Remove() return end
       
        //if self.Exploded then return end

        self:Track()
        //print(self:GetGravity())
        if self.Canjump then

                local tr = util.TraceLine( {
                        start = self.Entity:GetPos(),
                        endpos = self.Entity:GetPos() + Vector(0,0,-1),
                        filter = function( ent ) if ( ent:GetClass() == "prop_physics" ) then return true end end
                } )

                print(tr.Entity)
                print(self.Canjump) 
                if !(tr.Entity:IsWorld()) then 
                        self.Canjump = false
                        timer.Simple(math.random(3,6),function() self.Canjump = true end) 
                return end

                //self.Jump()
                //self.Entity:SetGroundEntity(nil)
                //self.Entity:SetPos(self.Entity:GetPos()+ Vector(0,0,5))
                self.Entity:SetVelocity(self.Entity:GetForward()*1000 +Vector(0,0,1000))
                self.Canjump = false
                local nextjump = math.random(3,6)
                timer.Simple(nextjump,function() self.Canjump = true end)
        end

        
        

        self:NextThink(CurTime())

return true end

/*---------------------------------------------------------
   Explode
---------------------------------------------------------*/
function ENT:Explode()

        if ( self.Exploded ) then return end

        self.Exploded = true

        local explosion = ents.Create( "env_explosion" )
		explosion:SetKeyValue( "spawnflags", 144 )
		explosion:SetKeyValue( "iMagnitude", 0 )
		explosion:SetKeyValue( "iRadiusOverride", 200 )
		explosion:SetPos(self:GetPos()) // Placing the explosion where we are
		explosion:Spawn( ) // Spawning it
		explosion:Fire("explode","",0)

                util.BlastDamage(self.Entity, self.Creator, self:GetPos(), 200, 60 )
        self.Entity:Remove()

end

/*---------------------------------------------------------
   PhysicsCollide
---------------------------------------------------------*/
function ENT:PhysicsSimulate( phys, deltatime )

        if self.Dead then return SIM_NOTHING end

        if self.Exploded then return SIM_NOTHING end

        local fSin = math.sin( CurTime() * 20 ) * 1.1
        local fCos = math.cos( CurTime() * 20 ) * 1.1

        local vAngular = Vector(0,0,0)
        local vLinear = (self.Entity:GetForward():Angle():Right() * fSin) + (self.Entity:GetForward():Angle():Up() * fCos)
        vLinear = vLinear * deltatime * 1.001


        return vAngular, vLinear, SIM_GLOBAL_FORCE

end
/*---------------------------------------------------------
   PhysicsCollide
---------------------------------------------------------*/
function ENT:PhysicsCollide( data, physobj )

        if self.Exploded then return end

        if data.HitEntity:IsWorld() then return end
        //print(data.Speed)
        //print(data.OurOldVelocity:Length())
        
       
        
        if( data.HitEntity && data.HitEntity:IsPlayer() ) then
            local ply = data.HitEntity
            print("I collided with a player named: " .. ply:Nick() .. "!\n")
            local ColVector =  data.HitPos - physobj:GetPos()
            //print("The collision vector is: " .. ColVector.x .. "," .. ColVector.y .. "," .. ColVector.z .. "\n")
            //print("They player is moving : " .. ply:GetVelocity().z .. " in the z direction!\n")
        
                //print("I pushed back a player named: " .. ply:Nick() .. "!\n")
                local hitang = ColVector:GetNormalized()
                pushvel = hitang * 350
                pushvel.z = math.max(pushvel.z, 100)
                ply:TakeDamage(20,self.Creator, self.Entity)
                if(self.Entity:IsOnFire()) then ply:Ignite(5) end


            ply:SetGroundEntity(nil)
            ply:SetVelocity(ply:GetVelocity() + pushvel)
            ply.was_pushed = {att=owner, t=CurTime(), wep=self:GetClass()}
        end

        self.HitCount = self.HitCount + 1
        self.Entity:NextThink(CurTime())
end

//tracking code

//first we need to find out which player is closest && in front of us

// Gets the nearest player relative to pos and within 90 degrees of fwd vector

function ENT:GetNearestPlayerInfront(pos,fwd) 

        local dist = 300000
        local ply = NULL
        local targetvect = NULL

        for _, v in pairs( player.GetAll() ) do

                //find distance to a player
                local newdist = pos:DistToSqr( v:GetPos() )

                //find angle to between where we are pointing and that player
                targetvect = v:GetPos()-pos
                ntarget = targetvect:GetNormalized()
                nfwd = fwd:GetNormalized()
                local dot = nfwd:Dot(ntarget)
                tarangle = math.deg(math.acos(dot))

                ////print("mypos: " .. pos.x .. "," .. pos.y  .. "," .. pos.z .. "\ntarget player: " .. v:Nick() .. "\ntarget pos: " .. v:GetPos().x .. "," .. v:GetPos().y  .. "\ntarget vector:" .. targetvect.x .. "," .. targetvect.y .. "," .. targetvect.z .. "\nangle between is ".. tarangle .. "\n")
                
                //check if that player is closer than the last one we check and also not behind us and also not behind a wall and is alive!
                
                local tr = util.TraceLine( {
                        start = pos + nfwd*30,   //have to start the trace outside our body otherwise hitent is just us, could also filter out us but this is easier
                        endpos = v:GetPos()
                })
                
                //print(tr.Entity:IsWorld())

                if (newdist < dist && v:Alive() && !v:IsSpec() && !tr.Entity:IsWorld()) then
                        ply = v
                        dist = newdist
                end
        end

        if(ply.IsPlayer()) then self.HadTarget = true //print("\nplayer found: " .. ply:Nick() .. " at a distance of: " .. math.sqrt(dist) .. " and an angle of: " .. tarangle .. "\n")
        else //print ("no players found")
        end 

        return ply
end


function ENT:Track()

        local fwd = self.Entity:GetForward()

        ////print("my forward vector is: " .. fwd.x .. "," .. fwd.y .. "," .. fwd.z .. "\n")

        target = self:GetNearestPlayerInfront(self:GetPos(),fwd)
        

        local tr = util.TraceLine( {
                start = self.Entity:GetPos() + Vector(0,1,0)*30,
                endpos = self.Entity:GetPos() + Vector(0,0,-1)*10000
        })
        
        local height = self:GetPos().z - tr.HitPos.z
        

        if (target:IsPlayer() && (!self:OnTarget(target))) then
                ////print("My target is " .. target:GetName() .. "\nTracking target!\n" )

                //remember our speed and velocity

                self.Target = target

                local currentvelocity = self.Entity:GetVelocity()
                local speed = currentvelocity:Length()

                ////print("My speed is " .. speed .. "\n" )

                //we want to aim at the eyes of our victim
                
                local aimpoint = target:EyePos() - Vector(0,0,25)
                local targetvect = aimpoint - self.Entity:GetPos()
                local targetang = targetvect:Angle()
                local ntarget = targetvect:GetNormalized()
                local dot = fwd:Dot(ntarget)
                local ang = math.deg(math.acos(dot))

                //difference between our velocity and the target vector gives us a velocity change vector
                local vchange = targetvect - fwd

                ////print("target vector:" .. targetvect.x .. "," .. targetvect.y .. "," .. targetvect.z .. "\n")

                ////print("my change vector is: " .. vchange.x .. "," .. vchange.y .. "," .. vchange.z .. "\n")

                //we want to find the rotation (normal) vector between our forward vecor and target vector
                local normal = (fwd:Cross(targetvect)):GetNormalized()

                
                ////print("angle between me and my target is: " .. tarangle .. "\n correcting... \n")

                local currentang = fwd:Angle()
                ////print("the angle im pointing is: "  .. currentang.x .. "," .. currentang.y .. "," .. currentang.z .. "\n")

                ////print("my rotation axis is: "  .. normal.x .. "," .. normal.y .. "," .. normal.z .. "\n")
                ////print("my velocity angle is ".. currentang.x .. "," .. currentang.y .. "," .. currentang.z .. "\n")
                local dang = currentang - targetang
                
                dx = math.AngleDifference( targetang.y, currentang.y)
                dy = math.AngleDifference( targetang.x, currentang.x)

                ////print("I'm facing " .. dx .. " degrees away from my target in my xy (left/right) plane.\n")
                ////print("I'm facing " .. dy .. " degrees away from my target in my xz (up/down) plane.\n")
                
                //rotate left or right
                if math.abs(dx) < 5 then   
                elseif normal.z > 0 then currentang:RotateAroundAxis(currentang:Up(),1.2)
                elseif normal.z <0 then currentang:RotateAroundAxis(currentang:Up(),-1.2) end
                
                
                ////print("my new velocity angle is ".. currentang.x .. "," .. currentang.y .. "," .. currentang.z .. "\n")
                
                
                self.Entity:SetAngles(Angle(0, currentang.y , 0))
                
                //self.Entity:GetPhysicsObject():RotateAroundAxis(normal,math.max(tarangle/10,1))
                
                local newfwd = currentang:Forward()

                //local newvelocity = (newfwd * 10)
                ////print("my new velocity angle is ".. newvelocity.x .. "," .. newvelocity.y .. "," .. newvelocity.z .. "\n")

                //self.Entity:GetPhysicsObject():SetVelocityInstantaneous(newfwd*speed)


         
        elseif (self:OnTarget(target)) 
                then
                        self.Target = target
                //print( "I'm on target!\n" )

        else //this is where we want to do our flying around without actively tracking players
                //print("No target found!") 

                local currentang = fwd:Angle()
                //print(self.HadTarget)
                self.Target = nil
                if(self.Avoidance) then

                        if(height && self.HadTarget) then
                                //currentang:RotateAroundAxis(currentang:Up(),2)
                        
                               
                                local dy = math.abs(math.AngleDifference(Angle(0,0,0).x, currentang.x))
                                //print(currentang)
                                //print(dy)
                                //print(height)
                                //print(levelout)
                                //if (math.abs(height-50) < 5) then levelout = true end

                                if ((height - 50 < 5) && dy <2) then levelout = true

                                elseif (height < 100) and (currentang.x > 20) then 
                                        //print("pullup")
                                        currentang:RotateAroundAxis(currentang:Right(),2) levelout = false
                                elseif height < 50 then 
                                        //print("pullup")
                                        currentang:RotateAroundAxis(currentang:Right(),1.5) levelout = false
                                elseif (currentang.x > 90) then 
                                        //print("sharp")
                                        currentang:RotateAroundAxis(currentang:Right(),-1) levelout = false
                                elseif (currentang.x < 60 and dy < 20 )  then
                                        //print"smooth" 
                                        currentang:RotateAroundAxis(currentang:Right(),-0.5) levelout = false
                                
                                end

                                if (dy > 80) then currentang.x = 280 end

                                if (levelout) then currentang = Angle(0,currentang.y,currentang.z) end

                                self.Entity:SetAngles(currentang)
                                
                                //self.Entity:GetPhysicsObject():RotateAroundAxis(normal,math.max(tarangle/10,1))
                                
                                
                                        
                                local newfwd = currentang:Forward()

                                //local newvelocity = (newfwd * 10)
                                ////print("my new velocity angle is ".. newvelocity.x .. "," .. newvelocity.y .. "," .. newvelocity.z .. "\n")
                                
                                //self.Entity:GetPhysicsObject():SetVelocityInstantaneous(newfwd*self.Speed)
                        end
                end 
        end        

        self.Entity:NextThink(CurTime())

end

function ENT:OnTarget(target)

        local fwd = self.Entity:GetForward()

        local tr = util.TraceLine( {
                start = self.Entity:GetPos() + fwd*20 ,
                endpos = self.Entity:GetPos() + fwd*10000
        })
        ////print(tr.Entity)

        if ((self.target) && (tr.Entity == target)) then return true
                else return false end
end

function ENT:OnTakeDamage(dmginfo)
     
        self:SetHealth(self:Health() - dmginfo:GetDamage())
  
        if (self:Health() < 0) then
           self.Dead = true
        end
end

function ENT:Jump(fwd)
        
       // jumpvec = fwd*3 + Vector(0,0,5)
        //self.Entity:GetPhysicsObject():SetVelocityInstantaneous(jumpvec)
end

