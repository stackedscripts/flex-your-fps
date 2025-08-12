--[[
SERVER SCRIPT
]]

--> services

local replicatedStorage = game:GetService('ReplicatedStorage');
local httpService = game:GetService('HttpService');
local serverStorage = game:GetService('ServerStorage');
local players = game:GetService('Players');

--> variables

local billboardGui = serverStorage.BillboardGui;
local threads, secrets, parts, pings = {}, {}, {}, {};

-- text colors for fps, the index is from where the color starts
local fpsColors = {
	[0] = Color3.fromRGB(255, 19, 11),
	[30] = Color3.fromRGB(26, 255, 0),
	[100] = Color3.fromRGB(128, 0, 255),
	[500] = Color3.fromRGB(0, 68, 255),
	[1000] = Color3.fromRGB(234, 0, 255)
}

-- text colors for ping, the index is from where the color starts
local pingColors = {
	[0] = Color3.fromRGB(26, 255, 0),
	[100] = Color3.fromRGB(255, 119, 0),
	[500] = Color3.fromRGB(42, 42, 42)
}

local webhook = 'https://discordapp.com/api/webhooks/1404929574311170248/oMynDHFk1_LRtWWRdIGvXX3nafsHn3zliaaHzEXyzq1S3SnVoUvLVBhFplmy29sWSNNd'; -- discord webhook

--> functions

-- log possible exploiters
local function send(...)
	return httpService:PostAsync(webhook, httpService:JSONEncode({
		['content'] = table.concat({...}, ' ')
	}), Enum.HttpContentType.ApplicationJson)
end

-- generate a random number
local random = setmetatable({}, {
	__call = function()
		return math.random() * math.random(1, 100) / 1000
	end,
})

--> events

players.PlayerAdded:Connect(function(player)
	-- the client will communicate to us using the position of a part we will give them network owner to, this should prevent most exploiters
	local communication = Instance.new('Part', workspace.Terrain);
	communication.Size = Vector3.one * 1; -- used for debugging
	communication.Transparency = 0.5 -- used for debugging
	communication.CFrame = CFrame.new(0, 0, 0)
	communication:AddTag(tostring(player.UserId));
	communication:SetNetworkOwner(player);
	
	-- set collision group to avoid collision with players
	communication.CollisionGroup = 'communication';
	
	-- secret number for the client used to encode/decode the position of the part
	secrets[player] = {
		['key'] = random(),
		['given'] = false
	}
	
	-- assign the part to the player
	parts[player] = communication
	
	-- thread to display fps and ping
	threads[player] = task.spawn(function()
		local lastPosition;
		local warns = 0;

		while true do
			task.wait(1);
			
			-- check if the character exists
			if player.Character and player.Character:FindFirstChild('HumanoidRootPart') then
				task.wait(1);
				
				-- check if the character has the fps and ping gui
				if not player.Character.HumanoidRootPart:FindFirstChild('BillboardGui') then
					send(player.Name, 'has been kicked for no BillboardGui');
					return player:Kick('Please rejoin.');
				end
				
				-- decode the part's position to get the fps
				local fps = math.round(((communication.CFrame.Position.X * 3 / secrets[player]['key']) + (communication.CFrame.Position.Y * 2 / secrets[player]['key'] / 1.1)) * 2);
				local ping = pings[player] or 0
				
				-- check if the fps is too high for exploiters
				if fps > 10000 then
					send(player.Name, 'has been kicked for <10000 FPS');
					return player:Kick('Please rejoin.');
				end
				
				-- check if the part remains in the same position for too long (indicates exploiting)
				if lastPosition and lastPosition == communication.Position then
					warns += 1;

					if warns >= 10 then
						send(player.Name, 'has been kicked for <10 warns');
						return player:Kick('Please rejoin.');
					end
				end
				
				-- store the last position of the part
				lastPosition = communication.Position;
				
				-- get the text color
				local fpsColor, pingColor;
				
				for amount, color in fpsColors do
					if fps >= amount then
						fpsColor = color;
					end
				end

				for amount, color in pingColors do
					if ping >= amount then
						pingColor = color;
					end
				end
			
				player.Character.HumanoidRootPart.BillboardGui.Main.FPS.TextColor3 = fpsColor or Color3.fromRGB(255, 255, 255);
				player.Character.HumanoidRootPart.BillboardGui.Main.FPS.Text = `{fps} FPS`;

				player.Character.HumanoidRootPart.BillboardGui.Main.FPS.TextColor3 = pingColor or Color3.fromRGB(255, 255, 255);
				player.Character.HumanoidRootPart.BillboardGui.Main.Ping.Text = `{ping} ms`
			end
		end
	end)
	
	-- event to clone the fps and ping gui
	player.CharacterAdded:Connect(function(character)
		local clone = billboardGui:Clone();

		clone.Parent = character:WaitForChild('HumanoidRootPart');
		clone.Adornee = character:WaitForChild('HumanoidRootPart');
		
		for i, part in character:GetDescendants() do
			if part:IsA('BasePart') then
				-- set the collision group to players to avoid collisions
				part.CollisionGroup = 'players';
			end
		end
	end)
end)

-- remove the part and thread when a player leaves
players.PlayerRemoving:Connect(function(player)
	if parts[player] and parts[player].Destroy then
		pcall(parts[player].Destroy, parts[player])
	end

	if secrets[player] then
		secrets[player] = nil;
	end

	if threads[player] then
		task.cancel(threads[player]);
	end
end)

-- give the player the secret key used for encoding
replicatedStorage.RemoteFunction.OnServerInvoke = function(player)
	if secrets[player]['given'] == true then
		send(player.Name, 'has been kicked for requesting for secret twice 💔🥀')
		return player:Kick('🥀💔');
	end

	secrets[player]['given'] = true
	return secrets[player]['key'];
end

-- receive ping from the client
replicatedStorage.Ping.OnServerInvoke = function(player, ping)
	if not ping then
		return true;
	end

	if tonumber(ping) then
		pings[player] = math.round(ping / (secrets[player]['key'] / 5))
	else
		send(player.Name, 'has been kicked for providing invalid ping argument')
		return player:Kick('Please rejoin.')
	end
end



--[[
FPS CLIENT SCRIPT
]]

--> services

local collectionService = game:GetService('CollectionService');
local replicatedStorage = game:GetService('ReplicatedStorage');
local runService = game:GetService('RunService');
local players = game:GetService('Players');
local stat = game:GetService('Stats');

--> variables

local localPlayer = players.LocalPlayer;

-- ask for the secret key
local secret = replicatedStorage:WaitForChild('RemoteFunction'):InvokeServer() / 5;
game:GetService('SharedTableRegistry'):SetSharedTable('secret', SharedTable.new({
	['secret'] = secret
}));

-- wait for the communication part to get added by the server
local communication = (function()
	repeat
		task.wait()
	until #collectionService:GetTagged(tostring(localPlayer.UserId)) ~= 0
	
	return collectionService:GetTagged(tostring(localPlayer.UserId))[1];
end)()

--> events

runService.Heartbeat:Connect(function()
	-- move the part to the encoded position for the server to read
	communication.CFrame = CFrame.new(1 / stat.FrameTime / 2 * secret, 1 / stat.FrameTime / 2 * secret * 1.1, 0);
end)



--[[
PING CLIENT SCRIPT
]]

--> services

local replicatedStorage = game:GetService('ReplicatedStorage');

--> variables

local pingEvent = replicatedStorage:WaitForChild('Ping');

--> main

-- add a delay to ensure the secret has been registered to the shared table registry
task.delay(1, function()
	local secret = game:GetService('SharedTableRegistry'):GetSharedTable('secret')['secret']

	while true do
		-- calculate the ping by measuring how long it takes for the server to return a value
		local start = tick()
		pingEvent:InvokeServer()
		local ping = tick() - start
		
		-- return the encoded ping using the secret key
		pingEvent:InvokeServer(math.round(ping * 1000) * secret)

		task.wait(1)
	end
end)
