#****************************************************************************
#**
#**  File     :  /lua/AI/sorianutilities.lua
#**  Author(s): Michael Robbins aka Sorian
#**
#**  Summary  : Utility functions for the Sorian AIs
#**
#****************************************************************************

local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local Utils = import('/lua/utilities.lua')
local Mods = import('/lua/mods.lua')

local AIChatText = import('/lua/AI/sorianlang.lua').AIChatText

#Table of AI taunts orginized by faction
local AITaunts = {
	{3,4,5,6,7,8,9,10,11,12,14,15,16}, #Aeon
	{19,21,23,24,26,27,28,29,30,31,32}, #UEF
	{33,34,35,36,37,38,39,40,41,43,46,47,48}, #Cybran
	{49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64}, #Seraphim
}

#Unused - Deprecated
function T4Timeout(aiBrain)
	WaitSeconds(30)
	aiBrain.T4Building = false
end

#-----------------------------------------------------
#   Function: XZDistanceTwoVectorsSq
#   Args:
#       v1 			- Position 1
#       v2     		- Position 2
#   Description:
#       Gets the distance squared between 2 points.
#   Returns:  
#       Distance
#-----------------------------------------------------
function XZDistanceTwoVectorsSq( v1, v2 )
	if not v1 or not v2 then return false end
    return VDist2Sq( v1[1], v1[3], v2[1], v2[3] )
end

#Small function the draw intel points on the map for debugging
function DrawIntel(aiBrain)
	threatColor = {
		#ThreatType = { ARGB value }
		StructuresNotMex = 'ff00ff00', #Green
		Commander = 'ff00ffff', #Cyan
		Experimental = 'ffff0000', #Red
		Artillery = 'ffffff00', #Yellow
		Land = 'ffff9600', #Orange
	}
	while true do
		if aiBrain:GetArmyIndex() == GetFocusArmy() then
			for k, v in aiBrain.InterestList.HighPriority do
				if threatColor[v.Type] then
					DrawCircle( v.Position, 1, threatColor[v.Type] )
					DrawCircle( v.Position, 3, threatColor[v.Type] )
					DrawCircle( v.Position, 5, threatColor[v.Type] )
				end
		    end
		end
		WaitSeconds(2)
	end
end

#-----------------------------------------------------
#   Function: AIHandleIntelData
#   Args:
#       aiBrain			- AI Brain
#   Description:
#       Lets the AI handle intel data.
#   Returns:  
#       nil
#-----------------------------------------------------
function AIHandleIntelData(aiBrain)
	local numchecks = 0
	local checkspertick = 5
	for _, intel in aiBrain.InterestList.HighPriority do
		numchecks = numchecks + 1
		if intel.Type == 'StructuresNotMex' then
			AIHandleStructureIntel(aiBrain, intel)
		elseif intel.Type == 'Commander' then
			AIHandleACUIntel(aiBrain, intel)
		#elseif intel.Type == 'Experimental' then
		#	AIHandleT4Intel(aiBrain, intel)
		elseif intel.Type == 'Artillery' then
			AIHandleArtilleryIntel(aiBrain, intel)
		elseif intel.Type == 'Land' then
			AIHandleLandIntel(aiBrain, intel)
		end
		#Reduce load on game
		if numchecks > checkspertick then
			WaitTicks(1)
			numchecks = 0
		end
	end
end

#-----------------------------------------------------
#   Function: AIHandleStructureIntel
#   Args:
#       aiBrain			- AI Brain
#		intel			- Table of intel data
#   Description:
#       Handles structure intel.
#   Returns:  
#       nil
#-----------------------------------------------------
function AIHandleStructureIntel(aiBrain, intel)
	for subk, subv in aiBrain.BaseMonitor.AlertsTable do
		if intel.Position[1] == subv.Position[1] and intel.Position[3] == subv.Position[3] then
			return
		end
	end
	for subk, subv in aiBrain.AttackPoints do
		if intel.Position[1] == subv.Position[1] and intel.Position[3] == subv.Position[3] then
			return
		end
	end
	for k,v in aiBrain.BuilderManagers do
		local basePos = v.EngineerManager:GetLocationCoords()
		#If intel is within 300 units of a base
		if VDist2Sq(intel.Position[1], intel.Position[3], basePos[1], basePos[3]) < 90000 then
			#Bombard the location
			table.insert(aiBrain.AttackPoints,
				{
				Position = intel.Position,
				}
			)
			aiBrain:ForkThread(aiBrain.AttackPointsTimeout, intel.Position)
			#Set an alert for the location
			table.insert(aiBrain.BaseMonitor.AlertsTable,
				{
				Position = intel.Position,
				Threat = 350,
				}
			)
			aiBrain.BaseMonitor.AlertSounded = true
			aiBrain:ForkThread(aiBrain.BaseMonitorAlertTimeout, intel.Position)
			aiBrain.BaseMonitor.ActiveAlerts = aiBrain.BaseMonitor.ActiveAlerts + 1
		end
	end
end

#-----------------------------------------------------
#   Function: AIHandleACUIntel
#   Args:
#       aiBrain			- AI Brain
#		intel			- Table of intel data
#   Description:
#       Handles ACU intel.
#   Returns:  
#       nil
#-----------------------------------------------------
function AIHandleACUIntel(aiBrain, intel)
	for subk, subv in aiBrain.BaseMonitor.AlertsTable do
		if intel.Position[1] == subv.Position[1] and intel.Position[3] == subv.Position[3] then
			return
		end
	end
	for subk, subv in aiBrain.AttackPoints do
		if intel.Position[1] == subv.Position[1] and intel.Position[3] == subv.Position[3] then
			return
		end
	end
	#If AntiAir threat level is less than 10 around the ACU
	if aiBrain:GetThreatAtPosition( intel.Position, 1, true, 'AntiAir' ) < 10 then
		#Bombard the location
		table.insert(aiBrain.AttackPoints,
			{
			Position = intel.Position,
			}
		)
		aiBrain:ForkThread(aiBrain.AttackPointsTimeout, intel.Position)
		#Set an alert for the location
		table.insert(aiBrain.BaseMonitor.AlertsTable,
			{
			Position = intel.Position,
			Threat = 350,
			}
		)
		aiBrain.BaseMonitor.AlertSounded = true
		aiBrain:ForkThread(aiBrain.BaseMonitorAlertTimeout, intel.Position)
		aiBrain.BaseMonitor.ActiveAlerts = aiBrain.BaseMonitor.ActiveAlerts + 1
	end
end

#-----------------------------------------------------
#   Function: AIHandleArtilleryIntel
#   Args:
#       aiBrain			- AI Brain
#		intel			- Table of intel data
#   Description:
#       Handles Artillery intel.
#   Returns:  
#       nil
#-----------------------------------------------------
function AIHandleArtilleryIntel(aiBrain, intel)
	for subk, subv in aiBrain.BaseMonitor.AlertsTable do
		if intel.Position[1] == subv.Position[1] and intel.Position[3] == subv.Position[3] then
			return
		end
	end
	for subk, subv in aiBrain.AttackPoints do
		if intel.Position[1] == subv.Position[1] and intel.Position[3] == subv.Position[3] then
			return
		end
	end
	for k,v in aiBrain.BuilderManagers do
		local basePos = v.EngineerManager:GetLocationCoords()
		#If intel is within 950 units of a base
		if VDist2Sq(intel.Position[1], intel.Position[3], basePos[1], basePos[3]) < 902500 then
			#Bombard the location
			table.insert(aiBrain.AttackPoints,
				{
				Position = intel.Position,
				}
			)
			aiBrain:ForkThread(aiBrain.AttackPointsTimeout, intel.Position)
			#Set an alert for the location
			table.insert(aiBrain.BaseMonitor.AlertsTable,
				{
				Position = intel.Position,
				Threat = intel.Threat,
				}
			)
			aiBrain.BaseMonitor.AlertSounded = true
			aiBrain:ForkThread(aiBrain.BaseMonitorAlertTimeout, intel.Position)
			aiBrain.BaseMonitor.ActiveAlerts = aiBrain.BaseMonitor.ActiveAlerts + 1
		end
	end
end

#-----------------------------------------------------
#   Function: AIHandleLandIntel
#   Args:
#       aiBrain			- AI Brain
#		intel			- Table of intel data
#   Description:
#       Handles land unit intel.
#   Returns:  
#       nil
#-----------------------------------------------------
function AIHandleLandIntel(aiBrain, intel)
	for subk, subv in aiBrain.BaseMonitor.AlertsTable do
		if intel.Position[1] == subv.Position[1] and intel.Position[3] == subv.Position[3] then
			return
		end
	end
	for subk, subv in aiBrain.TacticalBases do
		if intel.Position[1] == subv.Position[1] and intel.Position[3] == subv.Position[3] then
			return
		end
	end
	for k,v in aiBrain.BuilderManagers do
		local basePos = v.EngineerManager:GetLocationCoords()
		#If intel is within 100 units of a base we don't want this spot
		if VDist2Sq(intel.Position[1], intel.Position[3], basePos[1], basePos[3]) < 10000 then
			return
		end
	end
	#Mark location for a defensive point
	nextBase = (table.getn(aiBrain.TacticalBases) + 1)
	table.insert(aiBrain.TacticalBases,
		{
		Position = intel.Position,
		Name = 'IntelBase'..nextBase,
		}
	)
	#Set an alert for the location
	table.insert(aiBrain.BaseMonitor.AlertsTable,
		{
		Position = intel.Position,
		Threat = intel.Threat,
		}
	)
	aiBrain.BaseMonitor.AlertSounded = true
	aiBrain:ForkThread(aiBrain.BaseMonitorAlertTimeout, intel.Position)
	aiBrain.BaseMonitor.ActiveAlerts = aiBrain.BaseMonitor.ActiveAlerts + 1
end

#Unused
function AIMicro(aiBrain, platoon, target, threatatLocation, mySurfaceThreat)
	local friendlyThreat = aiBrain:GetThreatAtPosition( platoon:GetPlatoonPosition(), 1, true, 'AntiSurface', aiBrain:GetArmyIndex()) - mySurfaceThreat
	if mySurfaceThreat + friendlyThreat > threatatLocation * 3 or table.getn(platoon:GetPlatoonUnits()) > 14 then
		platoon:AggressiveMoveToLocation(target:GetPosition())
	#elseif threatatLocation * 2 > mySurfaceThreat + friendlyThreat then
	#	OrderedRetreat(aiBrain, platoon)
	else
		CircleAround(aiBrain, platoon, target)
	end
end

#Unused
function CircleAround(aiBrain, platoon, target)
	platPos = platoon:GetPlatoonPosition()
	ePos = target:GetPosition()
	if not platPos or not ePos then
		return false
	elseif VDist2Sq(platPos[1], platPos[3], ePos[1], ePos[3]) > 2500 then
		IssueMove(platoon, ePos)
		return
	end
	local platterheight = GetTerrainHeight(platPos[1], platPos[3])
	if platterheight < GetSurfaceHeight(platPos[1], platPos[3]) then
		platterheight = GetSurfaceHeight(platPos[1], platPos[3])
	end
	vert = math.abs(platPos[1] - ePos[1])
	horz = math.abs(platPos[3] - ePos[3])
	local leftright
	local updown
	local movePos = {}
	if vert > horz then
		if ePos[3] > platPos[3] then
			leftright = -1
		else
			leftright = 1
		end
		if ePos[1] > platPos[1] then
			updown = 1
		else
			updown = -1
		end
		movePos[1] = { platPos[1], ePos[2], ePos[3] + (16 * leftright) }
		movePos[2] = { ePos[1] + (16 * updown), ePos[2], ePos[3] + (16 * leftright) }
		movePos[3] = { ePos[1] + (16 * updown), ePos[2], ePos[3] - (16 * leftright) }
		for k,v in movePos do
			local terheight = GetTerrainHeight(v[1], v[3])
			local _, slope = GetSlopeAngle(platPos, v, platterheight, terheight)
			# If its in water
			if terheight < GetSurfaceHeight(v[1], v[3]) then
				platoon:AggressiveMoveToLocation(target:GetPosition())
				return
			# If the slope is too high
			elseif slope > .75 then
				platoon:AggressiveMoveToLocation(target:GetPosition())
				return
			end
		end
		
		platoon:MoveToLocation( movePos[1], false)
		platoon:MoveToLocation( movePos[2], false)
		platoon:MoveToLocation( movePos[3], false)
	else
		if ePos[3] > platPos[3] then
			leftright = 1
		else
			leftright = -1
		end
		if ePos[1] > platPos[1] then
			updown = -1
		else
			updown = 1
		end
		movePos[1] = { ePos[1] + (16 * updown), ePos[2], platPos[3] }
		movePos[2] = { ePos[1] + (16 * updown), ePos[2], ePos[3] + (16 * leftright) }
		movePos[3] = { ePos[1] - (16 * updown), ePos[2], ePos[3] + (16 * leftright) }
		for k,v in movePos do
			local terheight = GetTerrainHeight(v[1], v[3])
			local _, slope = GetSlopeAngle(platPos, v, platterheight, terheight)
			# If its in water
			if terheight < GetSurfaceHeight(v[1], v[3]) then
				platoon:AggressiveMoveToLocation(target:GetPosition())
				return
			# If the slope is too high
			elseif slope > .75 then
				platoon:AggressiveMoveToLocation(target:GetPosition())
				return
			end
		end
		
		platoon:MoveToLocation( movePos[1], false)
		platoon:MoveToLocation( movePos[2], false)
		platoon:MoveToLocation( movePos[3], false)
	end
	WaitSeconds(5)
end

#Unused
function OrderedRetreat(aiBrain, platoon)
	local bestBase = false
	local bestBaseName = ""
	local bestDistSq = 999999999
	local platPos = platoon:GetPlatoonPosition()

	for baseName, base in aiBrain.BuilderManagers do
		local distSq = VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3])

		if distSq < bestDistSq then
			bestBase = base
			bestBaseName = baseName
			bestDistSq = distSq    
		end
	end

	if bestBase then
		AIAttackUtils.GetMostRestrictiveLayer(platoon)
		local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, platoon.MovementLayer, platoon:GetPlatoonPosition(), bestBase.Position, 200)
		IssueClearCommands(platoon)

		if path and table.getn(path) > 1 then
			platoon:MoveToLocation(path[1], false)
		elseif path and table.getn(path) == 1 and VDist2Sq(path[1][1], path[1][3], platPos[1], platPos[3]) < 100 then
			IssueGuard( platoon, platPos )
		end
	end
end

#-----------------------------------------------------
#   Function: GetThreatAtPosition
#   Args:
#       aiBrain 		- AI Brain
#       pos     		- Position to check for threat
#		rings			- Rings to check
#		ttype			- Threat type
#		threatFilters	- Table of threats to filter
#   Description:
#       Checks for threat level at a location and allows filtering of threat types.
#   Returns:  
#       Threat level
#-----------------------------------------------------
function GetThreatAtPosition( aiBrain, pos, rings, ttype, threatFilters)
	local threat = aiBrain:GetThreatAtPosition( pos, rings, true, ttype )
	for k,v in threatFilters do
		local rthreat = aiBrain:GetThreatAtPosition( pos, rings, true, v )
		threat = threat - rthreat
	end
	return threat
end

#-----------------------------------------------------
#   Function: CheckForMapMarkers
#   Args:
#       aiBrain 		- AI Brain
#   Description:
#       Checks for Land Path Node map marker to verify the map has the appropriate AI markers.
#   Returns:  
#       nil
#-----------------------------------------------------
function CheckForMapMarkers(aiBrain)
	local startX, startZ = aiBrain:GetArmyStartPos()
	local LandMarker = AIUtils.AIGetClosestMarkerLocation(aiBrain, 'Land Path Node', startX, startZ)
	if not LandMarker then
		return false
	end
	return true
end

#-----------------------------------------------------
#   Function: AddCustomUnitSupport
#   Args:
#       aiBrain 		- AI Brain
#   Description:
#       Adds support for custom units.
#   Returns:  
#       nil
#-----------------------------------------------------
function AddCustomUnitSupport(aiBrain)
	aiBrain.CustomUnits = {}
	#Loop through active mods
	for i, m in __active_mods do
		#If mod has a CustomUnits folder
		local CustomUnitFiles = DiskFindFiles(m.location..'/lua/CustomUnits', '*.lua')
		#Loop through files in CustomUnits folder
		for k, v in CustomUnitFiles do
			local tempfile = import(v).UnitList
			#Add each files entry into the appropriate table
			for plat, tbl in tempfile do
				for fac, entry in tbl do
					if aiBrain.CustomUnits[plat] and aiBrain.CustomUnits[plat][fac] then
						table.insert(aiBrain.CustomUnits[plat][fac], { entry[1], entry[2] } )
					elseif aiBrain.CustomUnits[plat] then
						aiBrain.CustomUnits[plat][fac] = {}
						table.insert(aiBrain.CustomUnits[plat][fac], { entry[1], entry[2] } )
					else
						aiBrain.CustomUnits[plat] = {}
						aiBrain.CustomUnits[plat][fac] = {}
						table.insert(aiBrain.CustomUnits[plat][fac], { entry[1], entry[2] } )
					end
				end
			end
		end
	end
end

#Unused
function AddCustomFactionSupport(aiBrain)
	aiBrain.CustomFactions = {}
	for i, m in __active_mods do
		#LOG('*AI DEBUG: Checking mod: '..m.name..' for custom factions')
		local CustomFacFiles = DiskFindFiles(m.location..'/lua/CustomFactions', '*.lua')
		#LOG('*AI DEBUG: Custom faction files found: '..repr(CustomFacFiles))
		for k, v in CustomFacFiles do
			local tempfile = import(v).FactionList
			for x, z in tempfile do
				#LOG('*AI DEBUG: Adding faction: '..z.cat)
				table.insert(aiBrain.CustomFactions, z )
			end
		end
	end
end

#-----------------------------------------------------
#   Function: GetTemplateReplacement
#   Args:
#       aiBrain 		- AI Brain
#       building   		- Unit type to find a replacement for
#		faction			- AI Faction
#   Description:
#       Finds a custom engineer built unit to replace a default one.
#   Returns:  
#       Custom Unit or false
#-----------------------------------------------------
function GetTemplateReplacement(aiBrain, building, faction)
	local retTemplate = false
	local templateData = aiBrain.CustomUnits[building]
	#If there are Custom Units for this unit type and faction
	if templateData and templateData[faction] then
		local rand = Random(1,100)
		local possibles = {}
		#Add all the possibile replacements into a table
		for k,v in templateData[faction] do
			if rand <= v[2] then
				table.insert(possibles, v[1])
			end
		end
		#If we found a possibility
		if table.getn(possibles) > 0 then
			rand = Random(1,table.getn(possibles))
			local customUnitID = possibles[rand]
			retTemplate = { { building, customUnitID, } }
		end
	end
	return retTemplate
end

function GetEngineerFaction( engineer )
    if EntityCategoryContains( categories.UEF, engineer ) then
        return 'UEF'
    elseif EntityCategoryContains( categories.AEON, engineer ) then
        return 'Aeon'
    elseif EntityCategoryContains( categories.CYBRAN, engineer ) then
        return 'Cybran'
    elseif EntityCategoryContains( categories.SERAPHIM, engineer ) then
        return 'Seraphim'
    else
        return false
    end
end

function GetPlatoonTechLevel(platoonUnits)
	local highest = false
	for k,v in platoonUnits do
		if EntityCategoryContains(categories.TECH3, v) then
			highest = 3
		elseif EntityCategoryContains(categories.TECH2, v) and highest < 3 then
			highest = 2
		elseif EntityCategoryContains(categories.TECH1, v) and highest < 2 then
			highest = 1
		end
		if highest == 3 then break end
	end
	return highest
end

#-----------------------------------------------------
#   Function: CanRespondEffectively
#   Args:
#       aiBrain 		- AI Brain
#       location  		- Distress response location
#		platoon			- Platoon to check for
#   Description:
#       Checks to see if the platoon can attack units in the distress area.
#   Returns:  
#       true or false
#-----------------------------------------------------
function CanRespondEffectively(aiBrain, location, platoon)
	#Get units in area
	local targets = aiBrain:GetUnitsAroundPoint( categories.ALLUNITS, location, 32, 'Enemy' )
	#If threat of platoon is the same as the threat in the distess area
	if AIAttackUtils.GetAirThreatOfUnits(platoon) > 0 and aiBrain:GetThreatAtPosition(location, 0, true, 'Air') > 0 then
		return true
	elseif AIAttackUtils.GetSurfaceThreatOfUnits(platoon) > 0 and (aiBrain:GetThreatAtPosition(location, 0, true, 'Land') > 0 or aiBrain:GetThreatAtPosition(location, 0, true, 'Naval') > 0) then
		return true
	end
	#If no visible targets go anyway
	if table.getn(targets) == 0 then
		return true
	end
	return false
end

#-----------------------------------------------------
#   Function: AISendPing
#   Args:
#       position 		- Position to ping
#       pingType   		- Type of ping to send
#		army			- AI army
#   Description:
#       Function to handle AI map pings.
#   Returns:  
#       nil
#-----------------------------------------------------
function AISendPing(position, pingType, army)
	local PingTypes = {
       alert = {Lifetime = 6, Mesh = 'alert_marker', Ring = '/game/marker/ring_yellow02-blur.dds', ArrowColor = 'yellow', Sound = 'UEF_Select_Radar'},
       move = {Lifetime = 6, Mesh = 'move', Ring = '/game/marker/ring_blue02-blur.dds', ArrowColor = 'blue', Sound = 'Cybran_Select_Radar'},
       attack = {Lifetime = 6, Mesh = 'attack_marker', Ring = '/game/marker/ring_red02-blur.dds', ArrowColor = 'red', Sound = 'Aeon_Select_Radar'},
       marker = {Lifetime = 5, Ring = '/game/marker/ring_yellow02-blur.dds', ArrowColor = 'yellow', Sound = 'UI_Main_IG_Click', Marker = true},
   }
	local data = {Owner = army - 1, Type = pingType, Location = position}
	data = table.merged(data, PingTypes[pingType])
	import('/lua/simping.lua').SpawnPing(data)
end

function AIDelayChat(aigroup, ainickname, aiaction, targetnickname, delaytime)
	WaitSeconds(delaytime)
	AISendChat(aigroup, ainickname, aiaction, targetnickname)
end

#-----------------------------------------------------
#   Function: AISendChat
#   Args:
#       aigroup 		- Group to send chat to
#       ainickname  	- AI name
#		aiaction		- Type of AI chat
#		tagetnickname	- Target name
#   Description:
#       Function to handle AI sending chat messages.
#   Returns:  
#       nil
#-----------------------------------------------------
function AISendChat(aigroup, ainickname, aiaction, targetnickname, extrachat)
	if aigroup and not GetArmyData(ainickname):IsDefeated() and (aigroup !='allies' or AIHasAlly(GetArmyData(ainickname))) then
		if aiaction and AIChatText[aiaction] then
			local ranchat = Random(1, table.getn(AIChatText[aiaction]))
			local chattext
			if targetnickname then
				if IsAIArmy(targetnickname) then
					targetnickname = trim(string.gsub(targetnickname,'%b()', '' ))
				end
				chattext = string.gsub(AIChatText[aiaction][ranchat],'%[target%]', targetnickname )
			elseif extrachat then
				chattext = string.gsub(AIChatText[aiaction][ranchat],'%[extra%]', extrachat )
			else
				chattext = AIChatText[aiaction][ranchat]
			end
			table.insert(Sync.AIChat, {group=aigroup, text=chattext, sender=ainickname} )
		else
			table.insert(Sync.AIChat, {group=aigroup, text=aiaction, sender=ainickname} )
		end
	end
end

#-----------------------------------------------------
#   Function: AIRandomizeTaunt
#   Args:
#       aiBrain 		- AI Brain
#   Description:
#       Randmonly chooses a taunt and sends it to AISendChat.
#   Returns:  
#       nil
#-----------------------------------------------------
function AIRandomizeTaunt(aiBrain)
	local factionIndex = aiBrain:GetFactionIndex()
	tauntid = Random(1,table.getn(AITaunts[factionIndex]))
	aiBrain.LastVocTaunt = GetGameTimeSeconds()
	AISendChat('all', aiBrain.Nickname, '/'..AITaunts[factionIndex][tauntid])
end

#-----------------------------------------------------
#   Function: FinishAIChat
#   Args:
#       data	 		- Chat data table
#   Description:
#       Sends a response to a human ally's chat message.
#   Returns:  
#       nil
#-----------------------------------------------------
function FinishAIChat(data)
	local aiBrain = GetArmyBrain(data.Army)
	if data.NewTarget then
		if data.NewTarget == 'at will' then
			aiBrain.targetoveride = false
			AISendChat('allies', aiBrain.Nickname, 'Targeting at will')
		else
			if IsEnemy(data.NewTarget, data.Army) then
				aiBrain:SetCurrentEnemy( ArmyBrains[data.NewTarget] )
				aiBrain.targetoveride = true
				AISendChat('allies', aiBrain.Nickname, 'tcrespond', ArmyBrains[data.NewTarget].Nickname)
			elseif IsAlly(data.NewTarget, data.Army) then
				AISendChat('allies', aiBrain.Nickname, 'tcerrorally', ArmyBrains[data.NewTarget].Nickname)
			end
		end
	elseif data.NewFocus then
		aiBrain.Focus = data.NewFocus
		AISendChat('allies', aiBrain.Nickname, 'genericchat')
	elseif data.CurrentFocus then
		local focus = 'nothing'
		if aiBrain.Focus then
			focus = aiBrain.Focus
		end
		AISendChat('allies', aiBrain.Nickname, 'focuschat', nil, focus)
	elseif data.GiveEngineer and not GetArmyBrain(data.ToArmy):IsDefeated() then
		local cats = {categories.TECH3, categories.TECH2, categories.TECH1}
		local given = false
		for _, cat in cats do
			local engies = aiBrain:GetListOfUnits(categories.ENGINEER * cat - categories.COMMAND - categories.SUBCOMMANDER - categories.ENGINEERSTATION, false)
			for k,v in engies do
				if not v:IsDead() and v:GetParent() == v then
					if v.PlatoonHandle and aiBrain:PlatoonExists(v.PlatoonHandle) then
						v.PlatoonHandle:RemoveEngineerCallbacksSorian()
						v.PlatoonHandle:Stop()
						v.PlatoonHandle:PlatoonDisbandNoAssign()
					end
					if v.NotBuildingThread then
						KillThread(v.NotBuildingThread)
						v.NotBuildingThread = nil
					end
					if v.ProcessBuild then
						KillThread(v.ProcessBuild)
						v.ProcessBuild = nil
					end
					v.BuilderManagerData.EngineerManager:RemoveUnit(v)
					IssueStop({v})
					IssueClearCommands({v})
					AISendPing(v:GetPosition(), 'move', data.Army)
					AISendChat(data.ToArmy, aiBrain.Nickname, 'giveengineer')
					ChangeUnitArmy(v,data.ToArmy)
					given = true
					break
				end
			end
			if given then break end
		end
	elseif data.Command then
		if data.Text == 'target' then
			AISendChat(data.ToArmy, aiBrain.Nickname, 'target <enemy>: <enemy> is the name of the enemy you want me to attack or \'at will\' if you want me to choose targets myself.')
		elseif data.Text == 'focus' then
			AISendChat(data.ToArmy, aiBrain.Nickname, 'focus <strat>: <strat> is the name of the strategy you want me to use or \'at will\' if you want me to choose strategies myself. Available strategies: rush arty, rush nuke, air.')
		else
			AISendChat(data.ToArmy, aiBrain.Nickname, 'Available Commands: focus <strat or at will>, target <enemy or at will>, current focus, give me an engineer, command <target or strat>.')
		end
	end
end

#-----------------------------------------------------
#   Function: AIHandlePing
#   Args:
#       aiBrain 		- AI Brain
#       pingData   		- Ping data table
#   Description:
#       Handles the AIs reaction to a human ally's ping.
#   Returns:  
#       nil
#-----------------------------------------------------
function AIHandlePing(aiBrain, pingData)
	if pingData.Type == 'move' then
		nextping = (table.getn(aiBrain.TacticalBases) + 1)
		table.insert(aiBrain.TacticalBases,
			{
			Position = pingData.Location,
			Name = 'BasePing'..nextping,
			}
		)
		AISendChat('allies', ArmyBrains[aiBrain:GetArmyIndex()].Nickname, 'genericchat')
	elseif pingData.Type == 'attack' then
		table.insert(aiBrain.AttackPoints,
			{
			Position = pingData.Location,
			}
		)
		aiBrain:ForkThread(aiBrain.AttackPointsTimeout, pingData.Location)
		AISendChat('allies', ArmyBrains[aiBrain:GetArmyIndex()].Nickname, 'genericchat')
	elseif pingData.Type == 'alert' then
		table.insert(aiBrain.BaseMonitor.AlertsTable,
			{
			Position = pingData.Location,
			Threat = 80,
			}
		)
        aiBrain.BaseMonitor.AlertSounded = true
		aiBrain:ForkThread(aiBrain.BaseMonitorAlertTimeout, pingData.Location)
        aiBrain.BaseMonitor.ActiveAlerts = aiBrain.BaseMonitor.ActiveAlerts + 1
		AISendChat('allies', ArmyBrains[aiBrain:GetArmyIndex()].Nickname, 'genericchat')
	end
end

#-----------------------------------------------------
#   Function: FindClosestUnitPosToAttack
#   Args:
#       aiBrain 			- AI Brain
#       platoon    			- Platoon to find a target for
#		squad				- Platoon squad
#		maxRange			- Max Range
#		atkCat				- Categories to look for
#		selectedWeaponArc	- Platoon weapon arc
#		turretPitch			- platoon turret pitch
#   Description:
#       Finds the closest unit to attack that is not obstructed by terrain.
#   Returns:  
#       target or false
#-----------------------------------------------------
function FindClosestUnitPosToAttack( aiBrain, platoon, squad, maxRange, atkCat, selectedWeaponArc, turretPitch )
    local position = platoon:GetPlatoonPosition()
    if not aiBrain or not position or not maxRange then
        return false
    end
    local targetUnits = aiBrain:GetUnitsAroundPoint( atkCat, position, maxRange, 'Enemy' )
    local retUnit = false
    local distance = 999999
    for num, unit in targetUnits do
        if not unit:IsDead() then
            local unitPos = unit:GetPosition()
			#If unit is close enough, can be attacked, and not obstructed
            if (not retUnit or Utils.XZDistanceTwoVectors( position, unitPos ) < distance) and platoon:CanAttackTarget( squad, unit ) and (not turretPitch or not CheckBlockingTerrain(position, unitPos, selectedWeaponArc, turretPitch)) then
                retUnit = unit #:GetPosition()
                distance = Utils.XZDistanceTwoVectors( position, unitPos )
            end
        end
    end
    if retUnit then
        return retUnit
    end
    return false
end

#-----------------------------------------------------
#   Function: LeadTarget
#   Args:
#       platoon 		- TML firing missile
#       target  		- Target to fire at
#   Description:
#       Allows the TML to lead a target to hit them while moving.
#   Returns:  
#       Map Position or false
#	Notes:
#		TML Specs(MU = Map Units): Max Speed: 12MU/sec
#				                   Acceleration: 3MU/sec/sec
#				                   Launch Time: ~3 seconds
#-----------------------------------------------------
function LeadTarget(platoon, target)
	local TMLRandom = tonumber(ScenarioInfo.Options.TMLRandom) or 0
	local position = platoon:GetPlatoonPosition()
	local pos = target:GetPosition()
	
	#Get firing position height
	local fromheight = GetTerrainHeight(position[1], position[3])
	if GetSurfaceHeight(position[1], position[3]) > GetTerrainHeight(position[1], position[3]) then
		fromheight = GetSurfaceHeight(position[1], position[3])
	end
	#Get target position height
	local toheight = GetTerrainHeight(pos[1], pos[3])
	if GetSurfaceHeight(pos[1], pos[3]) > GetTerrainHeight(pos[1], pos[3]) then
		toheight = GetSurfaceHeight(pos[1], pos[3])
	end
	
	#Get height difference between firing position and target position
	local heightdiff = math.abs(fromheight - toheight)
	
	#Get target position and then again after 1 second
	#Allows us to get speed and direction
	local Tpos1 = {pos[1], 0, pos[3]}
	WaitSeconds(1)
	pos = target:GetPosition()
	local Tpos2 = {pos[1], 0, pos[3]}
	
	#Get distance moved on X and Y axis
	local xmove = (Tpos1[1] - Tpos2[1])
	local ymove = (Tpos1[3] - Tpos2[3])
	
	#Get distance from firing position to targets starting position and position it moved
	#to after 1 second
	local dist1 = VDist2Sq(position[1], position[3], Tpos1[1], Tpos1[3])
	local dist2 = VDist2Sq(position[1], position[3], Tpos2[1], Tpos2[3])
	dist1 = math.sqrt(dist1)
	dist2 = math.sqrt(dist2)
	
	#Adjust for level off time. 
	local distadjust = 0.25

	#Missile has a faster turn rate when targeting targets < 50 MU away
	#so will level off faster
	if dist2 < 50 then
		distadjust = 0.02
	end
	
	#Divide both distances by missiles max speed to get time to impact
	local time1 = (dist1 / 12) 
	local time2 = (dist2 / 12)
	
	#Adjust for height difference by dividing the height difference by the missiles max speed
	local heightadjust = heightdiff / 12
	
	#Speed up time is distance the missile will travel while reaching max speed
	#(~22.47 MU) divided by the missiles max speed which equals 1.8725 seconds flight time
	
	#total travel time + 1.87 (time for missile to speed up, rounded) + 3 seconds for launch
	#+ adjustment for turn rate + adjustment for height difference
	local newtime = time2 - (time1 - time2) + 4.87 + distadjust + heightadjust
	
	#Add some optional randomization to make the AI easier
	local randomize = (100 - Random(0, TMLRandom)) / 100
	newtime = newtime * randomize
	
	#Create target corrdinates
	local newx = xmove * newtime
	local newy = ymove * newtime
	
	#Cancel firing if target is outside map boundries
    if Tpos2[1] - newx < 0 or Tpos2[3] - newy < 0 or
	  Tpos2[1] - newx > ScenarioInfo.size[1] or Tpos2[3] - newy > ScenarioInfo.size[2] then
        return false
    end
	return {Tpos2[1] - newx, 0, Tpos2[3] - newy}
end

#Unused
function LeadTargetArtillery(platoon, unit, target)
	position = platoon:GetPlatoonPosition()
	mainweapon = unit:GetBlueprint().Weapon[1]
	pos = target:GetPosition()
	Tpos1 = {pos[1], 0, pos[3]}
	WaitSeconds(1)
	pos = target:GetPosition()
	Tpos2 = {pos[1], 0, pos[3]}
	xmove = (Tpos1[1] - Tpos2[1])
	ymove = (Tpos1[3] - Tpos2[3])
	dist1 = VDist2Sq(position[1], position[3], Tpos1[1], Tpos1[3])
	dist2 = VDist2Sq(position[1], position[3], Tpos2[1], Tpos2[3])
	dist1 = math.sqrt(dist1)
	dist2 = math.sqrt(dist2)
	# get firing angle, gravity constant = 100m/s = 5.12 MU/s
	firingangle1 = math.deg(math.asin((5.12 * dist1) / (mainweapon.MuzzleVelocity * mainweapon.MuzzleVelocity)) / 2)
	firingangle2 = math.deg(math.asin((5.12 * dist2) / (mainweapon.MuzzleVelocity * mainweapon.MuzzleVelocity)) / 2)
	# convert angle for high arc
	if mainweapon.BallisticArc == 'RULEUBA_HighArc' then
		firingangle1 = 90 - firingangle1
		firingangle2 = 90 - firingangle2
	end
	# get flight time
	time1 = mainweapon.MuzzleVelocity * math.deg(math.sin(firingangle1)) / 2.56
	time2 = mainweapon.MuzzleVelocity * math.deg(math.sin(firingangle2)) / 2.56
	newtime = time2 - (time1 - time2)
	newx = xmove * newtime
	newy = ymove * newtime
	return {Tpos2[1] - newx, 0, Tpos2[3] - newy}
end

#-----------------------------------------------------
#   Function: CheckBlockingTerrain
#   Args:
#       pos     		- Platoon position
#		targetPos		- Target position
#		firingArc		- Firing Arc
#		turretPitch		- Turret pitch
#   Description:
#       Checks to see if there is terrain blocking a unit from hiting a target.
#   Returns:  
#       true (there is something blocking) or false (there is not something blocking)
#-----------------------------------------------------
function CheckBlockingTerrain(pos, targetPos, firingArc, turretPitch)
	#High firing arc indicates Artillery unit
	if firingArc == 'high' then
		return false
	end
	#Distance to target
	local distance = VDist2Sq(pos[1], pos[3], targetPos[1], targetPos[3])
	distance = math.sqrt(distance)
	
	#This allows us to break up the distance into 5 points so we can check
	#5 points between the unit and target
	local step = math.ceil(distance / 5)
	local xstep = (pos[1] - targetPos[1]) / step
	local ystep = (pos[3] - targetPos[3]) / step
	
	#Loop through the 5 points to check for blocking terrain
	#Start at zero in case there is only 1 step. if we start at 1 with 1 step it wont check it
	for i = 0, step do
		if i > 0 then
			#We want to check the slope and angle between one point along the path and the next point
			local lastPos = {pos[1] - (xstep * (i - 1)), 0, pos[3] - (ystep * (i - 1))}
			local nextpos = {pos[1] - (xstep * i), 0, pos[3] - (ystep * i)}
			
			#Get height for both points
			local lastPosHeight = GetTerrainHeight( lastPos[1], lastPos[3] )
			local nextposHeight = GetTerrainHeight( nextpos[1], nextpos[3] )
			if GetSurfaceHeight( lastPos[1], lastPos[3] ) > lastPosHeight then
				lastPosHeight = GetSurfaceHeight( lastPos[1], lastPos[3] )
			end
			if GetSurfaceHeight( nextpos[1], nextpos[3] ) > nextposHeight then
				nextposHeight = GetSurfaceHeight( nextpos[1], nextpos[3] )
			else
				nextposHeight = nextposHeight + .5
			end
			#Get the slope and angle between the 2 points
			local angle, slope = GetSlopeAngle(lastPos, nextpos, lastPosHeight, nextposHeight)
			#There is an obstruction
			if angle > turretPitch then
				return true
			end
		end
	end
	return false
end

#-----------------------------------------------------
#   Function: GetSlopeAngle
#   Args:
#       pos     		- Starting position
#		targetPos		- Target position
#		posHeight		- Starting position height
#		targetHeight	- Target position height
#   Description:
#       Gets the slope and angle between 2 points.
#   Returns:  
#       slope and angle
#-----------------------------------------------------
function GetSlopeAngle(pos, targetPos, posHeight, targetHeight)
	#Distance between points
	local distance = VDist2Sq(pos[1], pos[3], targetPos[1], targetPos[3])
	distance = math.sqrt(distance)
	
	local heightDif
	
	#If heights are the same return 0
	#Otherwise we want the absolute value of the height difference
	if targetHeight == posHeight then
		return 0
	else
		heightDif = math.abs(targetHeight - posHeight)
	end
	
	#Get the slope and angle between the points
	local slope = heightDif / distance
	local angle = math.deg(math.atan(slope))

	return angle, slope
end

#Unused - Deprecated
function MajorLandThreatExists( aiBrain )
	local StartX, StartZ = aiBrain:GetArmyStartPos()
	local numET2 = aiBrain:GetNumUnitsAroundPoint( categories.STRUCTURE * categories.STRATEGIC * categories.TECH2, Vector(StartX,0,StartZ), 360, 'Enemy' )
	local numET3Art = aiBrain:GetNumUnitsAroundPoint( categories.STRUCTURE * categories.ARTILLERY * categories.TECH3, Vector(StartX,0,StartZ), 900, 'Enemy' )
	local numENuke = aiBrain:GetNumUnitsAroundPoint( categories.STRUCTURE * categories.NUKE * categories.SILO, Vector(StartX,0,StartZ), 100000, 'Enemy' )
	local numET4Art = aiBrain:GetNumUnitsAroundPoint( categories.STRUCTURE * categories.STRATEGIC * categories.EXPERIMENTAL, Vector(StartX,0,StartZ), 100000, 'Enemy' )
	local numET4Sat = aiBrain:GetNumUnitsAroundPoint( categories.STRUCTURE * categories.ORBITALSYSTEM * categories.EXPERIMENTAL, Vector(StartX,0,StartZ), 100000, 'Enemy' )
	local numET4Exp = aiBrain:GetNumUnitsAroundPoint( categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL), Vector(StartX,0,StartZ), 100000, 'Enemy' )
	local numET4AExp = aiBrain:GetNumUnitsAroundPoint( categories.EXPERIMENTAL * categories.AIR, Vector(StartX,0,StartZ), 100000, 'Enemy' )
	local numEDef = aiBrain:GetNumUnitsAroundPoint( categories.DEFENSE * categories.STRUCTURE * (categories.DIRECTFIRE + categories.ANTIAIR), Vector(StartX,0,StartZ), 150, 'Enemy' )
	local retcat = false
	if numET4Art > 0 then
		retcat = categories.STRUCTURE * categories.STRATEGIC * categories.EXPERIMENTAL #'STRUCTURE STRATEGIC EXPERIMENTAL'
	elseif numET4Sat > 0 then
		retcat = categories.STRUCTURE * categories.ORBITALSYSTEM * categories.EXPERIMENTAL #'STRUCTURE ORBITALSYSTEM EXPERIMENTAL'
	elseif numENuke > 0 then
		retcat = categories.STRUCTURE * categories.NUKE * categories.SILO #'STRUCTURE NUKE SILO'
	elseif numET4Exp > 0 then
		retcat = categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL) #'EXPERIMENTAL LAND + NAVAL'
	elseif numET4AExp > 0 then
		retcat = categories.EXPERIMENTAL * categories.AIR #'EXPERIMENTAL AIR'
	elseif numET3Art > 0 then
		retcat = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3 #'STRUCTURE ARTILLERY TECH3'
	elseif numET2 > 0 then
		retcat = categories.STRUCTURE * categories.STRATEGIC * categories.TECH2 #'STRUCTURE STRATEGIC TECH2'
	elseif numEDef > 0 then
		retcat = categories.DEFENSE * categories.STRUCTURE * (categories.DIRECTFIRE + categories.ANTIAIR)
	end
	return retcat
end

#Unused - Deprecated
function MajorAirThreatExists( aiBrain )
	local StartX, StartZ = aiBrain:GetArmyStartPos()
	local numET4Exp = aiBrain:GetUnitsAroundPoint( categories.EXPERIMENTAL * categories.AIR, Vector(StartX,0,StartZ), 100000, 'Enemy' )
	local retcat = false
	for k,v in numET4Exp do
		if v:GetFractionComplete() == 1 then
			retcat = categories.EXPERIMENTAL * categories.AIR #'EXPERIMENTAL AIR'
			break
		end
	end

	return retcat
end

#-----------------------------------------------------
#   Function: GetGuards
#   Args:
#       aiBrain 		- AI Brain
#       Unit     		- Unit
#   Description:
#       Gets number of units assisting a unit.
#   Returns:  
#       Number of assisters
#-----------------------------------------------------
function GetGuards(aiBrain, Unit)
	local engs = aiBrain:GetUnitsAroundPoint( categories.ENGINEER, Unit:GetPosition(), 10, 'Ally' )
	local count = 0
	local UpgradesFrom = Unit:GetBlueprint().General.UpgradesFrom
	for k,v in engs do
		if v:GetUnitBeingBuilt() == Unit then
			count = count + 1
		end
	end
	if UpgradesFrom and UpgradesFrom != 'none' then -- Used to filter out upgrading units
		local oldCat = ParseEntityCategory(UpgradesFrom)
		local oldUnit = aiBrain:GetUnitsAroundPoint( oldCat, Unit:GetPosition(), 0, 'Ally' )
		if oldUnit then
			count = count + 1
		end
	end
	return count
end

#-----------------------------------------------------
#   Function: GetGuardCount
#   Args:
#       aiBrain 		- AI Brain
#       Unit     		- Unit
#		cat				- Unit category to check for
#   Description:
#       Gets the number of units guarding a unit.
#   Returns:  
#       Number of guards
#-----------------------------------------------------
function GetGuardCount(aiBrain, Unit, cat)
	local guards = Unit:GetGuards()
	local count = 0
	for k,v in guards do
		if not v:IsDead() and EntityCategoryContains(cat, v) then
			count = count + 1
		end
	end
	return count
end

#-----------------------------------------------------
#   Function: Nuke
#   Args:
#       aiBrain 		- AI Brain
#   Description:
#       Finds targets for the AIs nuke launchers and fires them all simultaneously.
#   Returns:  
#       nil
#-----------------------------------------------------
function Nuke(aiBrain)
    local atkPri = { 'STRUCTURE STRATEGIC EXPERIMENTAL', 'EXPERIMENTAL ARTILLERY OVERLAYINDIRECTFIRE', 'EXPERIMENTAL ORBITALSYSTEM', 'STRUCTURE ARTILLERY TECH3', 'STRUCTURE NUKE TECH3', 'EXPERIMENTAL ENERGYPRODUCTION STRUCTURE', 'COMMAND', 'TECH3 MASSFABRICATION STRUCTURE', 'TECH3 ENERGYPRODUCTION STRUCTURE', 'TECH2 STRATEGIC STRUCTURE', 'TECH3 DEFENSE STRUCTURE', 'TECH2 DEFENSE STRUCTURE', 'TECH2 ENERGYPRODUCTION STRUCTURE' }
	local maxFire = false
	local Nukes = aiBrain:GetListOfUnits( categories.NUKE * categories.SILO * categories.STRUCTURE * categories.TECH3, true )
	local nukeCount = 0
	local launcher
	local bp
	local weapon
	local maxRadius
	#This table keeps a list of all the nukes that have fired this round
	local fired = {}
    for k, v in Nukes do
		if not maxFire then
			bp = v:GetBlueprint()
			weapon = bp.Weapon[1]
			maxRadius = weapon.MaxRadius
			launcher = v
			maxFire = true
		end
		#Add launcher to the fired table with a value of false
		fired[v] = false
        if v:GetNukeSiloAmmoCount() > 0 then
			nukeCount = nukeCount + 1
        end            
    end
	#If we have nukes
	if nukeCount > 0 then
		#This table keeps track of all targets fired at this round to keep from firing multiple nukes
		#at the same target unless we have to to overwhelm anti-nukes.
		local oldTarget = {}
		local target
		local fireCount = 0
		local aitarget
		local tarPosition
		local antiNukes
		#Repeat until all launchers have fired or we run out of targets
		repeat
			#Get a target and target position. This function also ensures that we fire at a new target
			#and one that we have enough nukes to hit the target
			target, tarPosition, antiNukes = AIUtils.AIFindBrainNukeTargetInRangeSorian( aiBrain, launcher, maxRadius, atkPri, nukeCount, oldTarget )
			if target then
				#Send a message to allies letting them know we are letting nukes fly
				#Also ping the map where we are targeting
				aitarget = target:GetAIBrain():GetArmyIndex()
				AISendChat('allies', ArmyBrains[aiBrain:GetArmyIndex()].Nickname, 'nukechat', ArmyBrains[aitarget].Nickname)
				AISendPing(tarPosition, 'attack', aiBrain:GetArmyIndex())
				#Randomly taunt the enemy
				if Random(1,5) == 3 and (not aiBrain.LastTaunt or GetGameTimeSeconds() - aiBrain.LastTaunt > 90) then
					aiBrain.LastTaunt = GetGameTimeSeconds()
					AISendChat(aitarget, ArmyBrains[aiBrain:GetArmyIndex()].Nickname, 'nuketaunt')
				end
				#Get anti-nukes int the area
				#local antiNukes = aiBrain:GetNumUnitsAroundPoint( categories.ANTIMISSILE * categories.TECH3 * categories.STRUCTURE, tarPosition, 90, 'Enemy' )
				local nukesToFire = {}
				for k, v in Nukes do
					#If we have nukes that have not fired yet
					if v:GetNukeSiloAmmoCount() > 0 and not fired[v] then
						table.insert(nukesToFire, v)
						nukeCount = nukeCount - 1
						fireCount = fireCount + 1
						fired[v] = true
					end
					#If we fired enough nukes at the target, or we are out of nukes
					if fireCount > (antiNukes + 2) or nukeCount == 0 or (fireCount > 0 and antiNukes == 0) then
						break
					end
				end
				ForkThread(LaunchNukesTimed, nukesToFire, tarPosition)
			end
			#Keep track of old targets
			table.insert( oldTarget, target )
			fireCount = 0
			#WaitSeconds(15)
		until nukeCount <= 0 or target == false
	end
end


#-----------------------------------------------------
#   Function: LaunchNukesTimed
#   Args:
#       nukesToFire 	- Table of Nukes
#       target			- Target to attack
#   Description:
#       Launches nukes so that they all reach the target at about the same time.
#   Returns:  
#       nil
#-----------------------------------------------------
function LaunchNukesTimed(nukesToFire, target)
	local nukes = {}
	for k,v in nukesToFire do
		local pos = v:GetPosition()
		local timeToTarget = Round(math.sqrt(VDist2Sq(target[1], target[3], pos[1], pos[3]))/40)
		table.insert(nukes,{unit = v, flightTime = timeToTarget})
	end
	table.sort(nukes, function(a,b) return a.flightTime > b.flightTime end)
	local lastFT = nukes[1].flightTime
	for k,v in nukes do
		WaitSeconds(lastFT - v.flightTime)
		IssueNuke( {v.unit}, target )
		lastFT = v.flightTime
	end
end

#-----------------------------------------------------
#   Function: FindUnfinishedUnits
#   Args:
#       aiBrain 		- AI Brain
#       locationType	- Location to look at
#		buildCat		- Building category to search for
#   Description:
#       Finds unifinished units in an area.
#   Returns:  
#       unit or false
#-----------------------------------------------------
function FindUnfinishedUnits(aiBrain, locationType, buildCat)
	local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
	local unfinished = aiBrain:GetUnitsAroundPoint( buildCat, engineerManager:GetLocationCoords(), engineerManager:GetLocationRadius(), 'Ally' )
	local retUnfinished = false
	for num, unit in unfinished do
		donePercent = unit:GetFractionComplete()
		if donePercent < 1 and GetGuards(aiBrain, unit) < 1 and not unit:IsUnitState('Upgrading') then
			retUnfinished = unit
			break
		end
	end
	return retUnfinished
end

#-----------------------------------------------------
#   Function: FindDamagedShield
#   Args:
#       aiBrain 		- AI Brain
#       locationType	- Location to look at
#		buildCat		- Building category to search for
#   Description:
#       Finds damaged shields in an area.
#   Returns:  
#       damaged shield or false
#-----------------------------------------------------
function FindDamagedShield(aiBrain, locationType, buildCat)
	local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
	local shields = aiBrain:GetUnitsAroundPoint( buildCat, engineerManager:GetLocationCoords(), engineerManager:GetLocationRadius(), 'Ally' )
	local retShield = false
	for num, unit in shields do
		if not unit:IsDead() and unit:ShieldIsOn() then
			shieldPercent = (unit.MyShield:GetHealth() / unit.MyShield:GetMaxHealth())
			if shieldPercent < 1 and GetGuards(aiBrain, unit) < 3 then
				retShield = unit
				break
			end
		end
	end
	return retShield
end

#-----------------------------------------------------
#   Function: NumberofUnitsBetweenPoints
#   Args:
#       start			- Starting point
#		finish			- Ending point
#		unitCat			- Unit category
#		stepby			- MUs to step along path by
#		alliance		- Unit alliance to check for
#   Description:
#       Counts units between 2 points.
#   Returns:  
#       Number of units
#-----------------------------------------------------
function NumberofUnitsBetweenPoints(aiBrain, start, finish, unitCat, stepby, alliance)
    if type(unitCat) == 'string' then
        unitCat = ParseEntityCategory(unitCat)
    end

	local returnNum = 0
	
	#Get distance between the points
	local distance = math.sqrt(VDist2Sq(start[1], start[3], finish[1], finish[3]))
	local steps = math.floor(distance / stepby)
	
	local xstep = (start[1] - finish[1]) / steps
	local ystep = (start[3] - finish[3]) / steps
	#For each point check to see if the destination is close
	for i = 0, steps do
		local numUnits = aiBrain:GetNumUnitsAroundPoint( unitCat, {finish[1] + (xstep * i),0 , finish[3] + (ystep * i)}, stepby, alliance )
		returnNum = returnNum + numUnits
	end
	
	return returnNum
end

#-----------------------------------------------------
#   Function: DestinationBetweenPoints
#   Args:
#       destination 	- Destination
#       start			- Starting point
#		finish			- Ending point
#   Description:
#       Checks to see if the destination is between the 2 given path points.
#   Returns:  
#       true or false
#-----------------------------------------------------
function DestinationBetweenPoints(destination, start, finish)
	#Get distance between the points
	local distance = VDist2Sq(start[1], start[3], finish[1], finish[3])
	distance = math.sqrt(distance)
	
	#This allows us to break the distance up and check points every 100 MU
	local step = math.ceil(distance / 100)
	local xstep = (start[1] - finish[1]) / step
	local ystep = (start[3] - finish[3]) / step
	#For each point check to see if the destination is close
	for i = 1, step do
		#DrawCircle( {start[1] - (xstep * i), 0, start[3] - (ystep * i)}, 5, '0000ff' )
		#DrawCircle( {start[1] - (xstep * i), 0, start[3] - (ystep * i)}, 100, '0000ff' )
		if VDist2Sq(start[1] - (xstep * i), start[3] - (ystep * i), finish[1], finish[3]) <= 10000 then break end
		if VDist2Sq(start[1] - (xstep * i), start[3] - (ystep * i), destination[1], destination[3]) < 10000 then
			return true
		end
	end	
	return false
end

#-----------------------------------------------------
#   Function: GetNumberOfAIs
#   Args:
#       aiBrain		 	- AI Brain
#   Description:
#       Gets the number of AIs in the game.
#   Returns:  
#       Number of AIs
#-----------------------------------------------------
function GetNumberOfAIs(aiBrain)
	local numberofAIs = 0
	for k,v in ArmyBrains do
		if not v:IsDefeated() and not ArmyIsCivilian(v:GetArmyIndex()) and v:GetArmyIndex() != aiBrain:GetArmyIndex() then
			numberofAIs = numberofAIs + 1
		end
	end
	return numberofAIs
end

#-----------------------------------------------------
#   Function: GetNumberOfAIs
#   Args:
#       x			 	- Number to round
#		places			- Number of places to round to
#   Description:
#       Rounds a number to the specifed places.
#   Returns:  
#       Rounded number
#-----------------------------------------------------
function Round(x, places)
	if places then
		shift = 10 ^ places
		result = math.floor( x * shift + 0.5 ) / shift
		return result
	else
		result = math.floor( x + 0.5 )
		return result
	end
end

#-----------------------------------------------------
#   Function: Trim
#   Args:
#       s			 	- String to trim
#   Description:
#       Trims blank spaces around a string.
#   Returns:  
#       String
#-----------------------------------------------------
function trim(s)
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function GetRandomEnemyPos(aiBrain)
	for k, v in ArmyBrains do
		if IsEnemy(aiBrain:GetArmyIndex(), v:GetArmyIndex()) and not v:IsDefeated() then
			if v:GetArmyStartPos() then
				local ePos = v:GetArmyStartPos()
				return ePos[1], ePos[3]
			end
		end
	end
	return false
end

#-----------------------------------------------------
#   Function: GetArmyData
#   Args:
#       army		 	- Army
#   Description:
#       Returns army data for an army.
#   Returns:  
#       Army data table
#-----------------------------------------------------
function GetArmyData(army)
    local result
    if type(army) == 'string' then
        for i, v in ArmyBrains do
            if v.Nickname == army then
                result = v
                break
            end
        end
    end
    return result
end

#-----------------------------------------------------
#   Function: IsAIArmy
#   Args:
#       army		 	- Army
#   Description:
#       Checks to see if the army is an AI.
#   Returns:  
#       true or false
#-----------------------------------------------------
function IsAIArmy(army)
    if type(army) == 'string' then
        for i, v in ArmyBrains do
			if v.Nickname == army and v.BrainType == 'AI' then
				return true
			end
        end
	elseif type(army) == 'number' then
		if ArmyBrains[army].BrainType == 'AI' then
			return true		
		end
	end
    return false
end

#-----------------------------------------------------
#   Function: AIHasAlly
#   Args:
#       army		 	- Army
#   Description:
#       Checks to see if an AI has an ally.
#   Returns:  
#       true or false
#-----------------------------------------------------
function AIHasAlly(army)
	for k, v in ArmyBrains do
		if IsAlly(army:GetArmyIndex(), v:GetArmyIndex()) and army:GetArmyIndex() != v:GetArmyIndex() and not v:IsDefeated() then
			return true
		end
	end
	return false
end

#-----------------------------------------------------
#   Function: TimeConvert
#   Args:
#       temptime	 	- Time in seconds
#   Description:
#       Converts seconds into eaier to read time.
#   Returns:  
#       Converted time
#-----------------------------------------------------
function TimeConvert(temptime)
	hours = math.floor(temptime / 3600)
	minutes = math.floor(temptime/60)
	seconds = math.floor(math.mod(temptime, 60))
	hours = tostring(hours)
	if minutes < 10 then
		minutes = '0'..tostring(minutes)
	else
		minutes = tostring(minutes)
	end
	if seconds < 10 then
		seconds = '0'..tostring(seconds)
	else
		seconds = tostring(seconds)
	end
	returntext = hours..':'..minutes..':'..seconds
	return returntext
end