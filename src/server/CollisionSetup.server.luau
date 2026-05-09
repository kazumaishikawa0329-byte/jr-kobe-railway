-- コリジョングループの初期化（CarManager・TrainBuilder より先に実行）
-- 車と電車のパーツが物理的に干渉しないよう分離する

local PhysicsService = game:GetService("PhysicsService")

PhysicsService:RegisterCollisionGroup("Car")
PhysicsService:RegisterCollisionGroup("Train")
PhysicsService:CollisionGroupSetCollidable("Car", "Train", false)

print("[CollisionSetup] Car-Train コリジョン分離完了")
