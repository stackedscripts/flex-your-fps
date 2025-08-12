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
