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
