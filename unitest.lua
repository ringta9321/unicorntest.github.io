local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Configuration
local SPEED = 1250  -- Studs/second
local DISTANCE = 75000  -- 75K studs backward
local NO_CLIP = true  -- Disable collisions
local SCAN_INTERVAL = 0.1  -- Unicorn scan frequency
local HEIGHT_OFFSET = 3  -- Studs above ground level
local MOVEMENT_DIRECTION = -1  -- -1 for negative Z, 1 for positive Z

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local fallbackUsed = false  -- Track whether fallback was applied
local unicornFound = false  -- Track if a unicorn was found
local closestDistance = math.huge  -- For determining closest fallback

-- Disable collisions
if NO_CLIP then
    RunService.Stepped:Connect(function()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

-- Check if the model is a Unicorn
local function isUnicorn(model)
    return model and model:IsA("Model") and (
        model.Name:lower():find("unicorn") or
        model:FindFirstChild("Horn") or
        (model:FindFirstChildWhichIsA("MeshPart") and 
         model:FindFirstChildWhichIsA("MeshPart").MeshId:lower():find("unicorn"))
    )
end

-- Function to sit on the nearest seat
local function trySit(target, seatType)
    local seat = target:FindFirstChild(seatType)
    if seat and seat:IsA("Seat") then
        rootPart.CFrame = seat.CFrame
        task.wait(0.5)  -- Allow time for the character to align and sit
        return true
    end
    return false
end

-- Scan for fallback options (horse or chair)
local function checkFallbackOptions()
    -- Fallback Option 1: Locate Model_Horse
    local horse = Workspace.Baseplates.Baseplate.CenterBaseplate.Animals:FindFirstChild("Model_Horse")
    if horse and horse:IsA("Model") then
        local distance = (horse.PrimaryPart.Position - rootPart.Position).Magnitude
        if distance < closestDistance and trySit(horse, "VehicleSeat") then
            closestDistance = distance
            fallbackUsed = true
            print("Sitting on Horse!")
            return
        end
    end

    -- Fallback Option 2: Locate Chair in Workspace.RuntimeItems
    local chair = Workspace.RuntimeItems:FindFirstChild("Chair")
    if chair then
        local seat = chair:FindFirstChild("Seat")
        if seat then
            local distance = (seat.Position - rootPart.Position).Magnitude
            if distance < closestDistance and trySit(chair, "Seat") then
                closestDistance = distance
                fallbackUsed = true
                print("Sitting on Chair!")
                return
            end
        end
    end

    -- Log message if no suitable fallback is found
    if not fallbackUsed then
        print("Fallback failed: No suitable seat found!")
    end
end

-- Tween backward and scan for Unicorns
local function tweenBackward()
    local startPos = rootPart.Position
    local startCFrame = CFrame.new(startPos.X, startPos.Y + HEIGHT_OFFSET, startPos.Z)
    local endCFrame = CFrame.new(
        startPos.X, 
        startPos.Y + HEIGHT_OFFSET, 
        startPos.Z + (DISTANCE * MOVEMENT_DIRECTION)  -- Negative Z movement
    )

    -- Setup scanning
    local lastScan = 0
    local heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
        lastScan = lastScan + deltaTime
        if lastScan >= SCAN_INTERVAL then
            lastScan = 0
            for _, descendant in ipairs(Workspace:GetDescendants()) do
                if isUnicorn(descendant) then
                    unicornFound = true
                    warn("🦄 UNICORN FOUND AT:", descendant:GetPivot().Position)

                    -- Check for fallback seat
                    checkFallbackOptions()
                    heartbeat:Disconnect()
                    return
                end
            end
        end
    end)

    -- Create tween
    local tweenInfo = TweenInfo.new(
        DISTANCE / SPEED,  -- Duration
        Enum.EasingStyle.Linear
    )
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = endCFrame})
    tween:Play()
    tween.Completed:Wait()

    -- Disconnect heartbeat and final checks
    heartbeat:Disconnect()
    if not unicornFound then
        warn("Completed backward movement of "..DISTANCE.." studs - no unicorns found.")
    elseif unicornFound and not fallbackUsed then
        print("Unicorn found, but no fallback option was used!")
    end
end

-- Start the movement
tweenBackward()
