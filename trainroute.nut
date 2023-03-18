﻿
class TrainRoute extends Route {
	static instances = [];
	static removed = []; // TODO: Save/Load
	static unsuitableEngineWagons = {};
	
	static RT_ROOT = 1;
	static RT_ADDITIONAL = 2;
	static RT_RETURN = 3;
	
	static USED_RATE_LIMIT = 20;
	
	static function Save(route) {
		local t = {};
		t.id <- route.id;
		t.routeType <- route.routeType;
		t.cargo <- route.cargo;
		t.srcHgStation <- route.srcHgStation.id;
		t.destHgStation <- route.destHgStation.id;
		t.pathSrcToDest <- route.pathSrcToDest.array_; //path.Save();
		t.pathDestToSrc <- route.pathDestToSrc == null ? null : route.pathDestToSrc.array_; //path.Save();
		t.subCargos <- route.subCargos;
		t.transferRoute <- route.isTransfer;
		t.latestEngineVehicle <- route.latestEngineVehicle;
		t.latestEngineSet <- route.latestEngineSet;
		t.engineVehicles <- route.engineVehicles;
		t.additionalRoute <- route.additionalRoute != null ? route.additionalRoute.id : null;
		t.parentRoute <- route.parentRoute != null ? route.parentRoute.id : null;
		t.isClosed <- route.isClosed;
		t.isRemoved <- route.isRemoved;
		t.failedUpdateRailType <- route.failedUpdateRailType;
		t.updateRailDepot <- route.updateRailDepot;
		t.startDate <- route.startDate;
		t.destHgStations <- [];
		foreach(station in route.destHgStations) {
			t.destHgStations.push(station.id);
		}
		t.pathDistance <- route.pathDistance;
		t.forkPaths <- [];
		foreach(path in route.forkPaths) {
			t.forkPaths.push(path.array_);
		}
		t.depots <- route.depots;
		t.returnRoute <- route.returnRoute != null ? route.returnRoute.Save() : null;
		t.reduceTrains <- route.reduceTrains;
		t.maxTrains <- route.maxTrains;
		t.slopesTable <- route.slopesTable;
		t.usedRateHistory <- route.usedRateHistory;
		t.engineSetsCache <- route.engineSetsCache;
		t.engineSetsDate <- route.engineSetsDate;
		t.engineSetAllRailCache <- route.engineSetAllRailCache;
		t.engineSetAllRailDate <- route.engineSetAllRailDate;
		t.lastDestClosedDate <- route.lastDestClosedDate;
		t.additionalTiles <- route.additionalTiles;
		t.lastConvertRail <- route.lastConvertRail;
		t.lastChangeDestDate <- route.lastChangeDestDate;
		t.cannotChangeDest <- route.cannotChangeDest;
		t.oldCargoProduction <- route.oldCargoProduction;
		return t;
	}
	
	static function SaveStatics(data) {
		local arr = [];
		foreach(route in TrainRoute.instances) {
			if(route.id == null) { // Removeが完了したroute
				continue;
			}
			arr.push(TrainRoute.Save(route));
		}
		data.trainRoutes <- arr;		

		arr = [];
		foreach(route in TrainRoute.removed) {
			arr.push(TrainRoute.Save(route));
		}
		data.removedTrainRoute <- arr; //いまのところIsInfrastractureMaintenance:trueの時しか使用されない
		
		data.unsuitableEngineWagons <- TrainRoute.unsuitableEngineWagons;
	}
	
	static function Load(t) {
		local destHgStations = [];
		foreach(stationId in t.destHgStations) {
			if(stationId != null) {
				destHgStations.push(HgStation.worldInstances[stationId]);
			}
		}
		local trainRoute = TrainRoute(
			t.routeType, 
			t.cargo, 
			HgStation.worldInstances[t.srcHgStation], 
			HgStation.worldInstances[t.destHgStation], 
			BuildedPath(Path.Load(t.pathSrcToDest)),
			t.pathDestToSrc == null ? null : BuildedPath(Path.Load(t.pathDestToSrc)));
		trainRoute.id = t.id;
		TrainRoute.idCounter.Skip(trainRoute.id);
		trainRoute.subCargos = t.subCargos;
		trainRoute.isTransfer = t.transferRoute;
		trainRoute.latestEngineVehicle = t.latestEngineVehicle;
		trainRoute.latestEngineSet = t.latestEngineSet != null ? delegate TrainEstimation : t.latestEngineSet : null;
		trainRoute.engineVehicles = t.engineVehicles;
		/*if(trainRoute.srcHgStation.GetName().find("0045") != null) {
			foreach(s in destHgStations) {
				HgLog.Info("destHgStations:"+s);
			}
		}*/
		trainRoute.isClosed = t.isClosed;
		trainRoute.isRemoved = t.rawin("isRemoved") ? t.isRemoved : false;
		trainRoute.failedUpdateRailType = t.rawin("failedUpdateRailType") ? t.failedUpdateRailType : false;
		trainRoute.updateRailDepot = t.updateRailDepot;
		trainRoute.startDate = t.startDate;
		trainRoute.destHgStations = destHgStations;
		trainRoute.pathDistance = t.pathDistance;
		trainRoute.forkPaths = [];
		foreach(path in t.forkPaths) {
			trainRoute.forkPaths.push(BuildedPath(Path.Load(t.pathSrcToDest)));
		}
		trainRoute.depots = t.depots;
		if(t.returnRoute != null) {
			trainRoute.returnRoute = TrainReturnRoute.Load(t.returnRoute, trainRoute);
		}
		trainRoute.reduceTrains = t.rawin("reduceTrains") ? t.reduceTrains : false;
		trainRoute.maxTrains = t.rawin("maxTrains") ? t.maxTrains : null;
		trainRoute.slopesTable = t.slopesTable;
		if(t.engineSetsCache != null) {
			local engineSets = [];
			foreach(engineSet in t.engineSetsCache) {
				engineSets.push(delegate TrainEstimation : engineSet);
			}
			trainRoute.engineSetsCache = engineSets;
		}

		trainRoute.engineSetsDate = t.engineSetsDate;
		trainRoute.engineSetAllRailCache = t.engineSetAllRailCache != null ? delegate TrainEstimation : t.engineSetAllRailCache : null;
		trainRoute.engineSetAllRailDate = t.engineSetAllRailDate;
		trainRoute.lastDestClosedDate = t.lastDestClosedDate;
		trainRoute.additionalTiles = t.additionalTiles;
		trainRoute.cannotChangeDest = t.cannotChangeDest;
		trainRoute.oldCargoProduction = t.oldCargoProduction;
		trainRoute.lastConvertRail = t.rawin("lastConvertRail") ? t.lastConvertRail : null;
		trainRoute.lastChangeDestDate = t.lastChangeDestDate;
		//trainRoute.usedRateHistory = t.rawin("usedRateHistory") ? t.usedRateHistory : [];
		return trainRoute;
	}
	
	static function LoadStatics(data) {
		TrainRoute.instances.clear();
		local idMap = {};
		foreach(t in data.trainRoutes) {
			local trainRoute = TrainRoute.Load(t);
			idMap[t.id] <- trainRoute;
			TrainRoute.instances.push(trainRoute);

			if(!trainRoute.isRemoved) {
				PlaceDictionary.Get().AddRoute(trainRoute);
				if(trainRoute.returnRoute != null) {
					PlaceDictionary.Get().AddRoute(trainRoute.returnRoute);
				}
				foreach(dest in trainRoute.destHgStations) {
					if(dest != trainRoute.destHgStation) {
						dest.AddUsingRoute(trainRoute); // 削除されないようにするため
					}
				}
			}
		}
		TrainRoute.removed.clear();
		if(data.rawin("removedTrainRoute")) {
			foreach(t in data.removedTrainRoute) {
				local trainRoute = TrainRoute.Load(t);
				TrainRoute.removed.push(trainRoute);
			}
		}

		// 今は使われていない
		foreach(t in data.trainRoutes) {
			local trainRoute = idMap[t.id];
			if(t.additionalRoute != null) {
				trainRoute.additionalRoute = idMap[t.additionalRoute];
			}
			if(t.parentRoute != null) {
				trainRoute.parentRoute = idMap[t.parentRoute];
			}
			HgLog.Info("load route:"+trainRoute);
		}
		
		TrainRoute.unsuitableEngineWagons.clear();
		HgTable.Extend(TrainRoute.unsuitableEngineWagons, data.unsuitableEngineWagons);
	}
	
	static function GetAll() {
		local routes = [];
		routes.extend(TrainRoute.instances);
		foreach(trainRoute in TrainRoute.instances) {
			if(trainRoute.returnRoute != null) {
				routes.push(trainRoute.returnRoute);
			}
		}
		return routes;
	}
	
	static function IsUnsuitableEngineWagon(trainEngine, wagonEngine) {
		return TrainRoute.unsuitableEngineWagons.rawin(trainEngine+"-"+wagonEngine);
	}
	
	static function GetTrainRoutes(railType) {
		local result = [];
		foreach(route in TrainRoute.instances) {
			if(route.GetRailType() == railType) {
				result.push(route);
			}
		}
		return result;
	}
	
	
	function AddUnsuitableEngineWagon(trainEngine, wagonEngine) {
		TrainRoute.unsuitableEngineWagons.rawset(trainEngine+"-"+wagonEngine,0);
	}
	
	function GetEstimator(self) {
		local result = TrainEstimator();
		result.skipWagonNum = 5;
		result.limitTrainEngines = 1;
		result.limitWagonEngines = 1;
		result.checkRailType = true;
		return result;
	}
	/*
	function EstimateEngineSet(self, cargo, distance, production, isBidirectional, infrastractureTypes=null) {
		local trainEstimator = trainEstimator();
		trainEstimator.cargo = cargo;
		trainEstimator.productions = [production];
		trainEstimator.isBidirectional = isBidirectional;
		trainEstimator.distance = distance;
		trainEstimator.skipWagonNum = 5;
		trainEstimator.limitTrainEngines = 1;
		trainEstimator.limitWagonEngines = 1;
		trainEstimator.checkRailType = true;
		local engineSets = trainEstimator.GetEngineSetsOrder();
		if(engineSets.len() >= 1) {
			return engineSets[0];
		}
		return null;
	}*/
	
	
	static idCounter = IdCounter();
	
	id = null;
	routeType = null;
	cargo = null;
	srcHgStation = null;
	destHgStation = null;
	pathSrcToDest = null;
	pathDestToSrc = null;
	
	startDate = null;
	subCargos = null;
	destHgStations = null;
	forkPaths = null;
	isTransfer = null;
	pathDistance = null;
	depots = null;
	returnRoute = null;
	latestEngineVehicle = null;
	engineVehicles = null;
	latestEngineSet = null;
	additionalRoute = null;
	parentRoute = null;
	isClosed = null;
	isRemoved = null;
	updateRailDepot = null;
	failedUpdateRailType = null;
	reduceTrains = null;
	maxTrains = null;
	slopesTable = null;
	trainLength = null;
	usedRateHistory = null;
	engineSetsCache = null;
	engineSetsDate = null;
	engineSetAllRailCache = null;
	engineSetAllRailDate = null;
	lastDestClosedDate = null;
	additionalTiles = null;
	lastConvertRail = null;
	lastChangeDestDate = null;
	cannotChangeDest = null;
	oldCargoProduction = null;
	
	averageUsedRate = null;
	usedRateCache = null;
	destRoute = null;
	hasRailDest = null;
	lastCheckProduction = null;

	constructor(routeType, cargo, srcHgStation, destHgStation, pathSrcToDest, pathDestToSrc){
		Route.constructor();
		this.id = idCounter.Get();
		this.routeType = routeType;
		this.cargo = cargo;
		this.srcHgStation = srcHgStation;
		this.destHgStation = destHgStation;
		this.pathSrcToDest = pathSrcToDest;
		this.pathDestToSrc = pathDestToSrc;
		this.pathSrcToDest.route = this;
		if(this.pathDestToSrc != null) {
			this.pathDestToSrc.route = this;
		}
		this.subCargos = [];
		this.destHgStations = [destHgStation];
		this.forkPaths = [];
		this.engineVehicles = {};
		this.isClosed = false;
		this.isRemoved = false;
		this.depots = [];
		this.failedUpdateRailType = false;
		this.reduceTrains = false;
		this.usedRateHistory = [];
		this.slopesTable = {};
		this.trainLength = 7;
		this.additionalTiles = [];
		this.cannotChangeDest = false;
		this.pathDistance = pathSrcToDest.path.GetRailDistance();
	}
	
	function Initialize() {
		InitializeSubCargos();
	}
	
	function InitializeSubCargos() {
		subCargos = CalculateSubCargos();
	}
	
	function GetLatestEngineSet() {
		return latestEngineSet;
	}
	
	function CalculateSubCargos() {
		HgLog.Info("CalculateSubCargos:"+this);
		local result = [];
		local railType = GetRailType();
		local depot = srcHgStation.GetDepotTile();
		local engineList = AIEngineList(AIVehicle.VT_RAIL);
		engineList.Valuate(AIEngine.CanRunOnRail, railType);
		engineList.KeepValue(1);
		foreach(subCargo in Route.CalculateSubCargos()) {
			foreach(engine,_ in engineList) {
				if(AIVehicle.GetBuildWithRefitCapacity(depot, engine, subCargo) >= 1) {
					result.push(subCargo);
					HgLog.Info("subCargo:"+AICargo.GetName(subCargo)+" "+this);
					break;
				}
			}
		}
		return result;
	}
	
	function GetCargos() {
		local result = [cargo];
		result.extend(subCargos);
		return result;
	}
	
	
	function HasCargo(cargo) {
		if(cargo == this.cargo) {
			return true;
		}
		if(!IsTransfer() /*transferルートは要求があれば応えられる事を意味する*/ && GetCargoCapacity(cargo) == 0) {
			return false; // このルートへのtransferを停止させる
		}
		foreach(subCargo in subCargos) {
			if(subCargo == cargo) {
				return true;
			}
		}
		return false;
	}

	
	function GetVehicleType() {
		return AIVehicle.VT_RAIL;
	}
	
	function GetLabel() {
		return "Rail";
	}
	
	function GetBuilderClass() {
		return TrainRouteBuilder;
	}
	
	function GetMaxTotalVehicles() {
		return HogeAI.Get().maxTrains;
	}

	function GetThresholdVehicleNumRateForNewRoute() {
		return 0.9;
	}

	function GetThresholdVehicleNumRateForSupportRoute() {
		return 0.9;
	}

	function GetBuildingTime(distance) {
		//return distance / 2 + 100; // TODO expectedproductionを満たすのに大きな時間がかかる
//		return distance * 3 / 2 + 2100;
		return distance + 500;
	}
	
	function AddDepot(depot) {
		if(depot != null) {
			depots.push(depot);
		}
	}
	
	function AddDepots(depots) {
		if(depots != null) {
			this.depots.extend(depots);
		}
	}
	
	function AddAdditionalTiles(tiles) {
		additionalTiles.extend(tiles);
	}
	
	function IsNotAdditional() {
		return parentRoute == null;
	}
	
	function IsClosed() {
		return isClosed;
	}
	
	function IsRemoved() {
		return isRemoved;
	}
	
	function GetMaxRouteCapacity(cargo) {
		local engineSet = GetLatestEngineSet();
		if(engineSet == null) {
			return 0;
		}
		if(GetCargoCapacity(cargo) == 0) {
			return 200; // うまく計算できない
		} else {
			return engineSet.GetMaxRouteCapacity(cargo) * GetPlatformLength() * 16 / engineSet.length;
		}
	}
	
	function GetUsableCargos() {
		local result = [];
		foreach(cargo in GetCargos()) {
			if(cargo == this.cargo || GetProductionCargo(cargo) >= 1) {
				result.push(cargo);
			}
		}
		return result;
	}
	
	function GetCargoLoadRate() {
	
		local cargos = GetCargos();
		local cargoLoad = {};
		local cargoCapa = {};
		local result = {};
		foreach(cargo in cargos) {
			cargoLoad[cargo] <- 0;
			cargoCapa[cargo] <- 0;
		}
		local count = 0;
		foreach(vehicle,_ in engineVehicles) {
			if(AIVehicle.GetState (vehicle) != AIVehicle.VS_RUNNING) {
				continue;
			}
			local loaded = false;
			foreach(cargo in cargos) {
				if(AIVehicle.GetCargoLoad(vehicle, cargo) >= 1) {
					loaded = true;
					break;
				}
			}
			if(loaded) {
				count ++;
				foreach(cargo in cargos) {
					cargoLoad[cargo] += AIVehicle.GetCargoLoad(vehicle, cargo);
					cargoCapa[cargo] += AIVehicle.GetCapacity(vehicle, cargo);
				}
			}
		}
		local result = {};
		foreach(cargo in cargos) {
			if(count <= 4) { // 対象vehicleが少ないと不正確
				result[cargo] <- 100;
			} else if(cargoLoad.rawin(cargo)) {
				result[cargo] <- cargoCapa[cargo] == 0 ? 0 : cargoLoad[cargo] * 100 / cargoCapa[cargo];
			} else {
				result[cargo] <- 0;
			}
		}
		return result;
	}
	
	function EstimateCargoProductions() {
		local cargos = GetCargos();
		local latestEngineSet = GetLatestEngineSet();
		local oldEstimateCargoProduction = {};
		if(latestEngineSet != null && oldCargoProduction != null) {
			foreach(cargo in cargos) {
				oldEstimateCargoProduction[cargo] <- GetCargoCapacity(cargo) * latestEngineSet.vehiclesPerRoute * 30 / latestEngineSet.days;
			}
		} else {
			oldCargoProduction = {};
			foreach(cargo in cargos) {
				oldEstimateCargoProduction[cargo] <- 0;
				oldCargoProduction[cargo] <- 0;
			}
		}
		local cargoLoadRate = GetCargoLoadRate();
		local cargoProduction = GetCargoProductions();
		local result = {};
		foreach(cargo in cargos) {
			local waiting = srcHgStation.GetCargoWaiting(cargo);
			if(IsBiDirectional()) {
				waiting += destHgStation.GetCargoWaiting(cargo);
				waiting /= 2;
			}
			local newProduction = (cargoProduction.rawin(cargo) ? cargoProduction[cargo] : 0)
			local deltaProduction = newProduction - (oldCargoProduction.rawin(cargo) ? oldCargoProduction[cargo] : 0);
			local production = max(50, oldEstimateCargoProduction[cargo] * cargoLoadRate[cargo] / 100 + deltaProduction + waiting / 8);
			if( newProduction > 0  || cargo == this.cargo) {
				result[cargo] <- production;
			}
		}
		return result;
	
/*
	
		local result = [];
		local subCargos = [];
		local resultProductions = [];
		local cargos = GetCargos();
		local loadRates = CalculateLoadRates();
		local loads = loadRates[0];
		local capas = loadRates[1];
		local waitings = [];
		local totalProduction = 0;
		local totalLoad = 0;
		local totalWaiting = 0;
		local productions = [];
		foreach(index, cargo in cargos) {
			local production = GetProductionCargo(cargo);
			if(this.cargo == cargo) {
				production = max(50, production); // 生産0でルートを作る事があるので、これが無いとBuildFirstTrainに失敗してルートが死ぬ
			}
			productions.push(production);
			totalProduction += production;
			totalLoad += loads[index];
			local waiting = srcHgStation.GetCargoWaiting(cargo) + (IsBiDirectional() ? destHgStation.GetCargoWaiting(cargo) : 0);
			waitings.push(waiting);
			totalWaiting += waiting;
		}
		
		foreach(index, cargo in cargos) {
			local production = 0;
			if(capas[index] == 0 || totalLoad == 0) {
				production = productions[index] + waitings[index]/5;
			} else {
				production = totalProduction * loads[index] / totalLoad + waitings[index]/5;
			}
			if(cargo == this.cargo) {
				resultProductions.push(production);
			} else if(production >= 1) {
				resultProductions.push(production);
				subCargos.push(cargo);
			}
		}
		return {subCargos = subCargos, productions = resultProductions};*/
	}
	
	function GetRoundedProduction(production) {
		if(production == 0) {
			return 0;
		}
		local index = HogeAI.Get().GetEstimateProductionIndex(production);
		return HogeAI.Get().productionEstimateSamples[index];
	}

	function CalculateLoadRates() {
		local cargos = GetCargos();
		local load = [];
		local capa = [];
		foreach(cargo in cargos) {
			load.push(0);
			capa.push(0);
		}
		foreach(vehicle,_ in engineVehicles) {
			foreach(index, cargo in cargos) {
				capa[index] += AIVehicle.GetCapacity(vehicle, cargo);
				load[index] += AIVehicle.GetCargoLoad(vehicle, cargo);
			}
		}
		return [load,capa];
	}
	
	function GetVehicles() {
		return engineVehicles;
	}

	function InvalidateEngineSet() {
		engineSetsCache = null;
	}

	function ChooseEngineSet() {
		local a = GetEngineSets();
		if(a.len() == 0){ 
			return null;
		}
		latestEngineSet = a[0];
		return a[0];
	}
	
	function IsValidEngineSetCache() {
		return engineSetsCache != null && ( AIDate.GetCurrentDate() < engineSetsDate || TrainRoute.instances.len()<=1) && engineSetsCache.len() >= 1;
	}
	
	function GetEngineSets(isAll=false, additionalDistance=null) {
		local production = GetRoundedProduction(max(50,GetProduction()));
		if(!isAll && additionalDistance==null && IsValidEngineSetCache() 
				&& (lastCheckProduction==null || production < lastCheckProduction * 3 / 2)) {
			return engineSetsCache;
		}
		lastCheckProduction = production;
		InitializeSubCargos(); // 使えるcargoが増えているかもしれないので再計算をする。
	
		local execMode = AIExecMode();
		local trainEstimator = TrainEstimator();
		trainEstimator.route = this;
		trainEstimator.cargo = cargo;
		trainEstimator.distance = GetDistance() + (additionalDistance != null ? additionalDistance : 0);
		trainEstimator.pathDistance = pathDistance + (additionalDistance != null ? additionalDistance : 0);
		trainEstimator.cargoProduction = EstimateCargoProductions();
		trainEstimator.isBidirectional = IsBiDirectional();
		trainEstimator.isTransfer = isTransfer;
		trainEstimator.railType = GetRailType();
		trainEstimator.isRoRo = !IsTransfer();
		trainEstimator.platformLength = GetPlatformLength();
		trainEstimator.selfGetMaxSlopesFunc = this;
		trainEstimator.additonalTrainEngine = latestEngineSet != null ? latestEngineSet.trainEngine : null;
		trainEstimator.additonalWagonEngine = latestEngineSet != null ? latestEngineSet.wagonEngineInfos[0].engine : null;
		if(isAll) {
			trainEstimator.limitWagonEngines = null;
			trainEstimator.limitTrainEngines = null;	
			trainEstimator.isLimitIncome = false;
		} else if(latestEngineSet == null) {
			trainEstimator.limitWagonEngines = 20;
			trainEstimator.limitTrainEngines = 10;		
		}
		trainEstimator.isSingleOrNot = IsSingle();
		trainEstimator.ignoreIncome = IsTransfer();
		trainEstimator.cargoIsTransfered = GetCargoIsTransfered();
		
		if(additionalDistance != null) {
			return trainEstimator.GetEngineSetsOrder();
		}
		
		engineSetsCache = trainEstimator.GetEngineSetsOrder();
		engineSetsDate = AIDate.GetCurrentDate() + (IsSingle() ? 3000 : 1000) + AIBase.RandRange(500);

		return engineSetsCache;
	}
	
	function ChooseEngineSetAllRailTypes() {
		
		if(engineSetAllRailCache != null) {
			if(AIDate.GetCurrentDate() < engineSetAllRailDate) {
				return engineSetAllRailCache;
			}
		}
		local execMode = AIExecMode();
		HgLog.Info("Start ChooseEngineSetAllRailTypes "+this);
		local trainEstimator = TrainEstimator();
		trainEstimator.route = this;
		trainEstimator.cargo = cargo;
		trainEstimator.distance = GetDistance();
		trainEstimator.pathDistance = pathDistance;
		trainEstimator.cargoProduction = EstimateCargoProductions();
		//trainEstimator.subProductions = GetRoundedSubProductions();
		trainEstimator.isBidirectional = IsBiDirectional();
		trainEstimator.isTransfer = isTransfer;
		trainEstimator.platformLength = GetPlatformLength();
		trainEstimator.selfGetMaxSlopesFunc = this;
		trainEstimator.additonalTrainEngine = latestEngineSet != null ? latestEngineSet.trainEngine : null;
		trainEstimator.additonalWagonEngine = latestEngineSet != null ? latestEngineSet.wagonEngineInfos[0].engine : null;
		trainEstimator.limitWagonEngines = 2;
		trainEstimator.limitTrainEngines = 5;
		trainEstimator.checkRailType = true;
		trainEstimator.isSingleOrNot = IsSingle();
		trainEstimator.ignoreIncome = IsTransfer()
		trainEstimator.cargoIsTransfered = GetCargoIsTransfered();

		local sets = trainEstimator.GetEngineSetsOrder();
		if(sets.len()==0) {
			HgLog.Warning("Not found engineSet.(ChooseEngineSetAllRailTypes) "+this);
			if(IsTransfer()) {
				HgLog.Warning("dest route: "+GetDestRoute()+" "+this);
			}
			return null;
		}
		local railTypeSet = {};
		foreach(set in sets) {
			//HgLog.Info(set+" ");
			if(!railTypeSet.rawin(set.railType)) {
				railTypeSet[set.railType] <- set;
			} else {
				local s = railTypeSet[set.railType];
				if(s.value < set.value) {
					railTypeSet[set.railType] = set;
				}
			}
		}
		local currentRailType = GetRailType();
		if(railTypeSet.rawin(currentRailType)) {
			local current = railTypeSet[currentRailType];
			if(current.value + abs( current.value / 10 ) < sets[0].value) {
				engineSetAllRailCache = sets[0];
			} else {
				engineSetAllRailCache = current;
			}
		} else {
			engineSetAllRailCache = sets[0];
		}
		if(engineSetAllRailCache.routeIncome < 0) {
			HgLog.Warning("Estimate routeIncome:"+engineSetAllRailCache.routeIncome+"<0 "+this);
		}
		engineSetAllRailDate = AIDate.GetCurrentDate() + (IsSingle() ? 6000 : 1600) + AIBase.RandRange(400);
		return engineSetAllRailCache;
	}
	
	function GetPlatformLength() {
		return min(srcHgStation.platformLength, destHgStation.platformLength);
	}
	
	function BuildFirstTrain() {
		if(HogeAI.Get().ecs && !IsSingle()) { // ecsでは駅評価を高めないと生産量が増えないので最初から2台作る
			local result = _BuildFirstTrain();
			if(result) {
				CloneAndStartTrain();
			}
			return result;
		} else {
			return _BuildFirstTrain();
		}
	}
	
	function _BuildFirstTrain() {
		latestEngineVehicle = BuildTrain(); //TODO 最初に失敗すると復活のチャンスなし。orderが後から書き変わる事があるがそれが反映されないため。orderを状態から組み立てられる必要がある
		if(latestEngineVehicle == null) {
			HgLog.Warning("BuildFirstTrain failed. "+this);
			return false;
		}
		BuildOrder(latestEngineVehicle);
		if(!AIVehicle.StartStopVehicle(latestEngineVehicle)) {
			HgLog.Warning("StartStopVehicle failed."+this+" "+AIError.GetLastErrorString());
			if(AIError.GetLastError() == AIError.ERR_NEWGRF_SUPPLIED_ERROR) {
				foreach(wagonEngineInfo in latestEngineSet.wagonEngineInfos) {
					AddUnsuitableEngineWagon(latestEngineSet.trainEngine, wagonEngineInfo.engine);
				}
				AIVehicle.SellWagonChain(latestEngineVehicle, 0);
				return BuildFirstTrain(); //リトライ
			}
		}
		engineVehicles.rawset(latestEngineVehicle,latestEngineSet);
		if(startDate == null) {
			startDate = AIDate.GetCurrentDate();
		}
		return true;
	}
	
	function BuildNewTrain() {
		local newTrain = BuildTrain();
		if(newTrain == null) {
			return false;
		}
		if(!AIVehicle.IsValidVehicle(latestEngineVehicle)) {
			HgLog.Warning("Invalid latestEngineVehicle."+this);
			foreach(v,_ in engineVehicles) {
				if(AIVehicle.IsValidVehicle(v)) {
					latestEngineVehicle = v;
					HgLog.Info("New latestEngineVehicle found."+this);
					break;
				}
			}
		}
		if(!AIOrder.ShareOrders(newTrain, latestEngineVehicle)) {
			HgLog.Warning("ShareOrders failed.(BuildNewTrain)"+this+" "+AIError.GetLastErrorString());
			BuildOrder(newTrain); // 他の列車とオーダーが共有されなくなるのでChangeDestinationなどがうまくいかなくなる。Sellすべきかもしれない
		}
		if(!AIVehicle.StartStopVehicle(newTrain)) {
			HgLog.Warning("StartStopVehicle failed.(BuildNewTrain)"+this+" "+AIError.GetLastErrorString());
			if(AIError.GetLastError() == AIError.ERR_NEWGRF_SUPPLIED_ERROR) {
				foreach(wagonEngineInfo in latestEngineSet.wagonEngineInfos) {
					AddUnsuitableEngineWagon(latestEngineSet.trainEngine, wagonEngineInfo.engine);
				}
				AIVehicle.SellWagonChain(newTrain, 0);
				return BuildNewTrain(); //リトライ
			}
			return false;
		}
		engineVehicles.rawset(newTrain,latestEngineSet);	
		latestEngineVehicle = newTrain;
		oldCargoProduction = GetCargoProductions(); // 列車新造時点での推定値を保存
		return true;
	}
	
	
	function CloneAndStartTrain() {
		if(latestEngineVehicle == null) {
			BuildFirstTrain();
			return;
		}
		if(IsSingle()) {
			return;
		}
		
		local engineSet = ChooseEngineSet();
		if(!HasVehicleEngineSet(latestEngineVehicle, engineSet)) {
			//HgLog.Info("BuildTrain HasVehicleEngineSet == false "+this);
			BuildNewTrain();	
		} else {
			local remain = TrainRoute.GetMaxTotalVehicles() - AIGroup.GetNumVehicles( AIGroup.GROUP_ALL, TrainRoute.GetVehicleType());
			if(remain <= 2) {
				return;
			}
			if(CloneTrain() == null) {
				engineSetsCache = null;
				BuildNewTrain();
			}
		}
	}
	
	function CloneTrain() {
		local execMode = AIExecMode();
		if(!AIVehicle.IsValidVehicle(this.latestEngineVehicle)) {
			HgLog.Warning("CloneVehicle failed. Invalid latestEngineVehicle("+this.latestEngineVehicle+") "+this);
			return null;
		}
		local engineVehicle = null;
		for(local need=20000;; need+= 10000) {
			local r = HogeAI.WaitForMoney(need);
			engineVehicle = AIVehicle.CloneVehicle(srcHgStation.GetDepotTile(), this.latestEngineVehicle, true);
			if(AIError.GetLastError()!=AIError.ERR_NOT_ENOUGH_CASH || !r) {
				break;
			}
		}
		if(!AIVehicle.IsValidVehicle(engineVehicle)) {
			HgLog.Warning("CloneVehicle failed. "+AIError.GetLastErrorString()+" "+this);
			return null;
		}
		if( AIOrder.GetOrderCount(engineVehicle) == 0 ) {
			HgLog.Warning("AIOrder.GetOrderCount(engineVehicle) == 0 "+this);
			return null;
		}
		engineVehicles.rawset( engineVehicle, engineVehicles[this.latestEngineVehicle] );
		AIVehicle.StartStopVehicle(engineVehicle);
		latestEngineVehicle = engineVehicle;		
		return engineVehicle;
	}
	
	function BuildEngineVehicle(engineVehicles, trainEngine, explain) {
		HogeAI.WaitForPrice(AIEngine.GetPrice(trainEngine));
		local depotTile = srcHgStation.GetDepotTile();
		local engineVehicle = AIVehicle.BuildVehicle(depotTile, trainEngine);
		if(!AIVehicle.IsValidVehicle(engineVehicle)) {
			local error = AIError.GetLastError();
			HgLog.Warning("BuildVehicle failed. "+explain+" "+AIError.GetLastErrorString()+" "+this);
			if(engineVehicles.len() >= 1) {
				AIVehicle.SellWagonChain(engineVehicles[0], 0);
			}
			if(error == AIVehicle.ERR_VEHICLE_TOO_MANY) {
				return null;
			}
			return false;
		}
		AIVehicle.RefitVehicle(engineVehicle, cargo);
		if(engineVehicles.len() >= 1 && !AIVehicle.MoveWagon(engineVehicle, 0, engineVehicles[0], engineVehicles.len()-1)) {
			HgLog.Warning("MoveWagon engineVehicle failed. "+explain + " "+AIError.GetLastErrorString()+" "+this);
			AIVehicle.SellWagonChain(engineVehicles[0], 0);
			AIVehicle.SellWagonChain(engineVehicle, 0);
			return false;
		}
		engineVehicles.push(engineVehicle);
		return true;
	}

	function BuildTrain(mode = 0) {
		local isAll = false;
		if(mode == 1) {
			engineSetsCache = null;
		} else if(mode == 2) {
			isAll = true;
		}
		foreach(engineSet in GetEngineSets(isAll)) {
			local trainEngine = engineSet.trainEngine;
			local unsuitable = false;
			foreach(wagonEngineInfo in engineSet.wagonEngineInfos) {
				if(TrainRoute.IsUnsuitableEngineWagon(trainEngine, wagonEngineInfo.engine)) {
					unsuitable = true;
					break;
				}
			}
			if(unsuitable) {
				continue;
			}
			local depotTile = srcHgStation.GetDepotTile();
			local explain = engineSet.tostring();
			HgLog.Info("BuildTrain "+explain+" "+this);

			
			local numEngineVehicle = engineSet.numLoco;
			local engineVehicles = [];
			
			local success = true;
			for(local i=0; i<numEngineVehicle; i++) {
				local r = BuildEngineVehicle(engineVehicles, trainEngine, explain);
				if(r == null) {
					return null; // ERR_VEHICLE_TOO_MANYの場合
				} else if(!r) {
					success = false;
					break;
				}
			}
			
			if(!success) {
				// AddUnsuitableEngineWagon(trainEngine, engineSet.wagonEngineInfos[0].engine); wagonとの組み合わせの問題ではない
				continue;
			}
			local engineVehicle = engineVehicles[0];
			
			foreach(wagonEngineInfo in engineSet.wagonEngineInfos) {
				for(local i=0; i<wagonEngineInfo.numWagon; i++) {
					HogeAI.WaitForPrice(AIEngine.GetPrice(wagonEngineInfo.engine));
					local wagon = AIVehicle.BuildVehicleWithRefit(depotTile, wagonEngineInfo.engine, wagonEngineInfo.cargo);
					if(!AIVehicle.IsValidVehicle(wagon))  {
						// AddUnsuitableEngineWagon(trainEngine, wagonEngineInfo.engine); wagonとの組み合わせの問題ではない
						HgLog.Warning("BuildVehicleWithRefit wagon failed. "+explain+" "+AIError.GetLastErrorString()+" "+this);
						success = false;
						break;
					}
					local realLength = AIVehicle.GetLength(wagon);
					local trainInfo = TrainInfoDictionary.Get().GetTrainInfo(wagonEngineInfo.engine);
					if(realLength != trainInfo.length) { // 時代で変わる？
						HgLog.Warning("Wagon length different:"+realLength+"!="+trainInfo.length+" "+AIEngine.GetName(wagonEngineInfo.engine)+" "+explain+" "+this);
						trainInfo.length = realLength;
					}
					if(!AIVehicle.MoveWagon(wagon, 0, engineVehicle, AIVehicle.GetNumWagons(engineVehicle)-1)) {
						AddUnsuitableEngineWagon(trainEngine, wagonEngineInfo.engine);
						HgLog.Warning("MoveWagon failed. "+explain + " "+AIError.GetLastErrorString()+" "+this);
						AIVehicle.SellWagonChain(wagon, 0);
						success = false;
						break;
					}
					if(AIVehicle.GetLength(engineVehicle) > GetPlatformLength() * 16) {
						HgLog.Warning("Train length over platform length."
							+AIVehicle.GetLength(engineVehicle)+">"+(GetPlatformLength() * 16)+" "+explain+" "+this);
						AIVehicle.SellWagonChain(wagon, 0);
						success = false;
						break;
					}
				}
				if(!success) {
					break;
				}
			}
			if(!success) {
				AIVehicle.SellWagonChain(engineVehicle, 0);
				continue;
			}
			
			latestEngineSet = engineSet;
			if(engineSetsCache != null && engineSetsCache.len() >= 1) {
				engineSetsCache[0] = engineSet; // ChooseEngineSet()で実際に作られたengineSetが返るようにする
			}
			if(returnRoute != null) {
				returnRoute.InitializeSubCargos();
			}
			return engineVehicle;
		}
		
		if(mode == 0) {
			HgLog.Warning("BuildTrain failed. Clear cache and retry. ("+AIRail.GetName(GetRailType())+") "+this);
			return BuildTrain(1);
		} else if(mode == 1) {
			HgLog.Warning("BuildTrain failed. Try all enginsets. ("+AIRail.GetName(GetRailType())+") "+this);
			return BuildTrain(2);
		}
		
		HgLog.Warning("BuildTrain failed. No suitable engineSet. ("+AIRail.GetName(GetRailType())+") "+this);
		engineSetsCache = null;
		return null;
	}
	

	function GetTotalWeight(trainEngine, wagonEngine, trainNum, wagonNum, cargo) {
		return AIEngine.GetWeight(trainEngine) * trainNum + (AIEngine.GetWeight(wagonEngine) + TrainRoute.GetCargoWeight(cargo,AIEngine.GetCapacity(wagonEngine))) * wagonNum;
	}
	
	function GetMaxSlopes(length, pathIn=null) {
		local path = pathIn == null ? pathSrcToDest.path : pathIn;
		local tileLength = ceil(length.tofloat() / 16).tointeger();
		if(slopesTable.rawin(tileLength)) {
			return slopesTable[tileLength];
		}
		local result = 0;
		result = max(result, path.GetSlopes(tileLength));
		//result = max(result, pathDestToSrc.path.GetSlopes(length));
		if(parentRoute != null) {
			result = max(result, parentRoute.GetMaxSlopes(length));
		}
		if(pathDestToSrc != null && pathIn == null && (returnRoute != null || IsBiDirectional())) {
			result = max(result, GetMaxSlopes(length, pathDestToSrc.path));
		}
		HgLog.Info("GetMaxSlopes("+length+","+tileLength+")="+result+" "+this);
		slopesTable[tileLength] <- result;
		return result;
	}
		
	function IsBiDirectional() {
		return !isTransfer && destHgStation.place != null && destHgStation.place.GetProducing().IsTreatCargo(cargo);
	}
	
	function IsSingle() {
		return pathDestToSrc == null;
	}
	
	function IsTransfer() {
		return isTransfer;
	}
	
	function IsRoot() {
		return !IsTransfer(); // 今のところ呼ばれる事は無い。
	}
		
	function BuildOrder(engineVehicle) {
		local execMode = AIExecMode();
		AIOrder.AppendOrder(engineVehicle, srcHgStation.platformTile, AIOrder.OF_FULL_LOAD_ANY + AIOrder.OF_NON_STOP_INTERMEDIATE);
		AIOrder.SetStopLocation	(engineVehicle, AIOrder.GetOrderCount(engineVehicle)-1, AIOrder.STOPLOCATION_MIDDLE);
		AIOrder.AppendOrder(engineVehicle, srcHgStation.GetServiceDepotTile(), AIOrder.OF_SERVICE_IF_NEEDED);
		if(IsTransfer()) {
			AIOrder.AppendOrder(engineVehicle, destHgStation.platformTile, AIOrder.OF_NON_STOP_INTERMEDIATE + AIOrder.OF_TRANSFER + AIOrder.OF_NO_LOAD );
		} else if(IsBiDirectional()) {
			AIOrder.AppendOrder(engineVehicle, destHgStation.platformTile, AIOrder.OF_NON_STOP_INTERMEDIATE);
		} else {
			AIOrder.AppendOrder(engineVehicle, destHgStation.platformTile, AIOrder.OF_NON_STOP_INTERMEDIATE + AIOrder.OF_UNLOAD + AIOrder.OF_NO_LOAD);
		}
		AIOrder.SetStopLocation	(engineVehicle, AIOrder.GetOrderCount(engineVehicle)-1, AIOrder.STOPLOCATION_MIDDLE);
		//AIOrder.SetStopLocation	(engineVehicle, AIOrder.GetOrderCount(engineVehicle)-1, AIOrder.STOPLOCATION_NEAR);
		return true;
	}
	

	function AddDestination(destHgStation) {
		destHgStations.push(destHgStation);
		slopesTable.clear();
		pathDistance = pathSrcToDest.path.GetRailDistance();
		
		destHgStation.AddUsingRoute(this); // ChangeDestination失敗時に駅が消されるのを防ぐ

		ChangeDestination(destHgStation);
		
		local oldDest = this.destHgStation;
		this.destHgStation = destHgStation;
		InitializeSubCargos();
		this.destHgStation = oldDest;
		
		engineSetsCache = null;
		maxTrains = null;
		lastDestClosedDate = null;
		if(additionalRoute != null) {
			additionalRoute.slopesTable.clear();
		}
	}

	function ChangeDestination(destHgStation, checkAcceleration = true) {
		if(returnRoute != null) { // このメソッドはreturn routeがある場合に対応していない
			HgLog.Warning("Cannot ChangeDestination (return route exists) "+this);
			return;
		}

		if(checkAcceleration) {
			local engineSets = {};
			foreach(_,engineSet in engineVehicles) {
				engineSets.rawset(engineSet,0);
			}
			foreach(engineSet,_ in engineSets) {
				if(VehicleUtils.GetAcceleration(
						VehicleUtils.GetMaxSlopeForce(GetMaxSlopes(engineSet.length), engineSet.lengthWeights, engineSet.weight)
						10,
						engineSet.tractiveEffort,
						engineSet.power,
						engineSet.weight) < 0) { 
					cannotChangeDest = true;
					HgLog.Warning("Cannot ChangeDestination (steep slope)"+this);
					return;
				}
			}
			cannotChangeDest = false;
		}
	
		local execMode = AIExecMode();
		/*intervalでチェックする
		if(IsBiDirectional()) {
			foreach(station in this.destHgStation.stationGroup.hgStations) {
				foreach(route in station.GetUsingRoutesAsDest()) {
					if(route.IsTransfer()) {
						route.NotifyChangeDestRoute();
					}
				}
			}
		}*/

		HgLog.Info("ChangeDestination to "+destHgStation+" "+this);
		PlaceDictionary.Get().RemoveRoute(this);
		local oldDestHgStation = this.destHgStation;
		this.destHgStation = destHgStation;
		PlaceDictionary.Get().AddRoute(this);
		oldDestHgStation.AddUsingRoute(this);
		lastChangeDestDate = AIDate.GetCurrentDate();
		
		//oldDestHgStation.RemoveOnlyPlatform();// 残った列車がなぜか消えかかった駅で下ろそうとする。ささくれるので線路だけ残す(SendDepotを帰路だけにすれば消しても問題ないかもしれない)

		if(latestEngineVehicle != null) {
			local orderFlags = AIOrder.OF_NON_STOP_INTERMEDIATE + (IsBiDirectional() ? 0 : AIOrder.OF_UNLOAD + AIOrder.OF_NO_LOAD);
			local failed = false;
			if(AIOrder.GetOrderCount (latestEngineVehicle) >= 4) { // return routeがある場合、changeしないのでこちらにはこない？
				if(!AIOrder.InsertOrder(latestEngineVehicle, 3, destHgStation.platformTile, orderFlags)) {
					HgLog.Warning("InsertOrder failed:"+HgTile(destHgStation.platformTile)+" "+this);
					failed = true;
				} else {
					AIOrder.SetStopLocation	(latestEngineVehicle, 3, AIOrder.STOPLOCATION_MIDDLE);
				}
			} else {
				if(!AIOrder.AppendOrder(latestEngineVehicle, destHgStation.platformTile, orderFlags)) {
					HgLog.Warning("AppendOrder failed:"+HgTile(destHgStation.platformTile)+" "+this);
					failed = true;
				} else {
					AIOrder.SetStopLocation	(latestEngineVehicle, AIOrder.GetOrderCount(latestEngineVehicle)-1, AIOrder.STOPLOCATION_MIDDLE);
				}
			}
			if(!failed) {
				AIOrder.RemoveOrder(latestEngineVehicle, 2);
			}
		}
		if(additionalRoute != null) {
			additionalRoute.AddDestination(destHgStation);
		}
	}
	
	function IsChangeDestination() {
		return destHgStation != destHgStations[destHgStations.len()-1];
	}
	
	function AddForkPath(path) {
		forkPaths.push(path);
	}
	

	function GetLastDestHgStation() {
		return destHgStations[destHgStations.len()-1];
	}
	
	function IsAllVehicleNew() {
		foreach(engineVehicle, _ in engineVehicles) {
			if(!HasVehicleEngineSet(engineVehicle,latestEngineSet)) {
				return false;
			}
		}
		return true;
	}

	
	function AddReturnTransferOrder(transferSrcStation, destStation) {
		local execMode = AIExecMode();
		if(latestEngineVehicle != null) {
			// destStationでLOAD
			// PAXがいると詰まる AIOrder.SetOrderFlags( latestEngineVehicle, AIOrder.GetOrderCount(latestEngineVehicle)-1, AIOrder.OF_NON_STOP_INTERMEDIATE + AIOrder.OF_UNLOAD);
			// YARD
			AIOrder.AppendOrder( latestEngineVehicle, transferSrcStation.platformTile, AIOrder.OF_NON_STOP_INTERMEDIATE);
			AIOrder.SetStopLocation( latestEngineVehicle, AIOrder.GetOrderCount(latestEngineVehicle)-1, AIOrder.STOPLOCATION_MIDDLE);
			// 積載率0の時、return dest stationをスキップ
			local conditionOrderPosition = AIOrder.GetOrderCount(latestEngineVehicle);
			AIOrder.AppendConditionalOrder( latestEngineVehicle, 0);
			AIOrder.SetOrderCompareValue( latestEngineVehicle, conditionOrderPosition, 0);
			AIOrder.SetOrderCompareFunction( latestEngineVehicle, conditionOrderPosition, AIOrder.CF_EQUALS );
			AIOrder.SetOrderCondition( latestEngineVehicle, conditionOrderPosition, AIOrder.OC_LOAD_PERCENTAGE );
			// return dest station
			AIOrder.AppendOrder( latestEngineVehicle, destStation.platformTile, AIOrder.OF_NON_STOP_INTERMEDIATE + AIOrder.OF_UNLOAD + AIOrder.OF_NO_LOAD );
			AIOrder.SetStopLocation( latestEngineVehicle, AIOrder.GetOrderCount(latestEngineVehicle)-1, AIOrder.STOPLOCATION_MIDDLE);
		}
	}
	
	function RemoveReturnTransferOder() {
		local execMode = AIExecMode();
		if(latestEngineVehicle != null && AIOrder.GetOrderCount (latestEngineVehicle)>=5) {
			AIOrder.RemoveOrder(latestEngineVehicle, 5);
			AIOrder.RemoveOrder(latestEngineVehicle, 4);
			AIOrder.RemoveOrder(latestEngineVehicle, 3);
		}
	}
	
	function AddSendUpdateDepotOrder() {
		local execMode = AIExecMode();
		AIOrder.InsertOrder(latestEngineVehicle, 0, updateRailDepot, AIOrder.OF_NON_STOP_INTERMEDIATE | AIOrder.OF_STOP_IN_DEPOT );
		if(returnRoute != null) {
			AIOrder.SetOrderJumpTo(latestEngineVehicle, 5, 0); // return時に積載していないときにupdate depotへ飛ぶようにする
		}
	}
	
	function RemoveSendUpdateDepotOrder() {
		local execMode = AIExecMode();
		if(returnRoute != null) {
			AIOrder.SetOrderJumpTo(latestEngineVehicle, 5, 1);
		}
		AIOrder.RemoveOrder(latestEngineVehicle,0);
	}
	
	function AddAdditionalRoute(additionalRoute) {
		this.additionalRoute = additionalRoute;
		additionalRoute.parentRoute = this;
	}
	
	
	function GetLastRoute() {
		if(additionalRoute == null) {
			return this;
		} else {
			return additionalRoute.GetLastRoute();
		}
	}
	
	function GetLastSrcHgStation() {
		return additionalRoute==null ? srcHgStation : additionalRoute.GetLastSrcHgStation();
	}
	
	function GetSrcStationTiles() {
		local result = [srcHgStation.platformTile];
		if(additionalRoute != null) {
			result.extend(additionalRoute.GetSrcStationTiles());
		}
		return result;
	}
	
	function GetTakeAllPathSrcToDest() {
		local result = pathSrcToDest.path;
		if(additionalRoute != null) {
			result = result.SubPathEnd(additionalRoute.pathSrcToDest.path.GetTile());
		}
		return result;
	}

	function GetTakeAllPathDestToSrc() {
		local result = pathDestToSrc.path;
		if(additionalRoute != null) {
			result = result.SubPathStart(additionalRoute.pathDestToSrc.path.GetLastTile());
		}
		return result;
	}

	function GetPathAllDestToSrc() {
		if(parentRoute != null) {
			return pathDestToSrc.path.Combine(parentRoute.GetTakeAllPathDestToSrc());
		} else {
			return pathDestToSrc.path;
		}
	}
	
	
	function IsAllVehicleLocation(location) {
		
		foreach(engineVehicle, v in engineVehicles) {
			if(AIVehicle.GetLocation(engineVehicle) != location || !AIVehicle.IsStoppedInDepot(engineVehicle)) {
//				HgLog.Info("IsAllVehicleLocation false:"+HgTile(AIVehicle.GetLocation(engineVehicle))+" loc:"+HgTile(location));
				return false;
			}
		}
		return true;
	}
	
	function GetRailType() {
		return AIRail.GetRailType(srcHgStation.platformTile);
	}
	
	function StartUpdateRail(railType) {
		if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < 1000000) {
			return false;
		}
		/*if(IsSingle()) {
			return false;
		}*/
		local exec = AIExecMode();
		
		if(latestEngineVehicle != null) {
			HgLog.Info("StartUpdateRail "+AIRail.GetName(railType)+" "+this);
			
			local railType = AIRail.GetCurrentRailType();
			AIRail.SetCurrentRailType ( GetRailType() );
			if(IsSingle()) {
				updateRailDepot = pathSrcToDest.path.BuildDepot();
			} else {
				updateRailDepot = pathDestToSrc.path.BuildDepot();
			}
			AIRail.SetCurrentRailType(railType);
			if(updateRailDepot == null) {
				HgLog.Warning("Cannot build depot for railupdate "+this);
				return false;
			}
			AddSendUpdateDepotOrder();
		}
	}
	
	function ConvertRailType(railType) {
		HgLog.Info("ConvertRailType." + AIRail.GetName(railType) + "<=" + AIRail.GetName(GetRailType()) + " " + this);
		lastConvertRail = AIDate.GetCurrentDate();
		
		local execMode = AIExecMode();
		AIRail.SetCurrentRailType(railType);
		local facitilies = [];
		facitilies.push(srcHgStation);
		foreach(s in destHgStations) {
			facitilies.push(s);
		}
		facitilies.push(pathSrcToDest.path);
		if(pathDestToSrc != null) {
			facitilies.push(pathDestToSrc.path);
		}
		foreach(fork in forkPaths) {
			facitilies.push(fork.path);
		}
		facitilies.extend(returnRoute != null ? returnRoute.GetFacilities():[]);
		local tiles = [];
		foreach(f in facitilies) {
			if(f != null) {
				if("GetTiles" in f) {
					tiles.extend(f.GetTiles());
				} else {
					tiles.extend(f);
				}
			}
		} 
		tiles.extend(depots);
		tiles.extend(additionalTiles);
		
		foreach(t in tiles) {
			if(t==null || AIRail.GetRailType(t)==railType) {
				continue;
			}
			if(AIRail.IsLevelCrossingTile(t)) { // 失敗時にRailTypeが戻せないケースがあるので、先に踏切だけ試す。
				if(!BuildUtils.RetryUntilFree(function():(t,railType) {
					return AIRail.ConvertRailType(t,t,railType);
				}, 500)) {
					HgLog.Warning("ConvertRailType failed:"+HgTile(t)+" "+AIError.GetLastErrorString()+" "+this);
					return false;
				}
			}
		}
		local tileTable = {};
		foreach(tile in tiles) {
			if(tile==null || AIRail.GetRailType(tile)==railType) {
				continue;
			}
			tileTable.rawset(tile,0);
		}
	
		local convertedList = AITileList();
		while(tileTable.len() >= 1) {
			foreach(tile,_ in tileTable) {
				tileTable.rawdelete(tile);
				// destHgStationsの削除時に駅とのつなぎ目の部分が破壊されているのでここでチェック
				/*破壊しないことにした。if(!AIRail.IsRailTile(tile) && !AIRail.IsRailDepotTile(tile) && !AIBridge.IsBridgeTile(tile) && !AITunnel.IsTunnelTile(tile)) { 
					continue;
				}*/
				if(AIRail.GetRailType(tile)==railType ) {
					continue;
				}
				local end = tile;
				local match = null;
				foreach(d in HgTile.DIR4Index) {
					if(tileTable.rawin(tile+d)) {
						tileTable.rawdelete(tile+d);
						if(AIRail.GetRailType(tile+d)==railType) {
							continue;
						}
						match = d;
						break;
					}
				}
				if(match != null) {
					end = tile + match;
					for(local i=2;;i++) {
						local c = tile + match * i;
						if(!tileTable.rawin(c)) {
							break;
						}
						tileTable.rawdelete(c);
						if(AIRail.GetRailType(c)==railType) {
							break;
						}
						end = c;
					}
				}
				if(!BuildUtils.RetryUntilFree(function():(tile,end,railType) {
					return AIRail.ConvertRailType(tile,end,railType);
				}, 500)) {
					HgLog.Warning("ConvertRailType failed:"+HgTile(tile)+"-"+HgTile(end)+" "+AIError.GetLastErrorString()+" "+this);
					return false;
				}
				convertedList.AddRectangle(tile, end);
				break;
			}
		}
		convertedList.Valuate(AIRail.GetRailType); // 最終チェック。AIRail.ConvertRailTypeは一部失敗は成功を返してしまう為
		convertedList.RemoveValue(railType);
		if(convertedList.Count() >= 1) {
			local tile = convertedList.Begin();
			HgLog.Warning("ConvertRailType failed:"+HgTile(tile)+" "+AIError.GetLastErrorString()+" "+this);
			return false;
		}
		
		if(updateRailDepot != null) {
			foreach(t in tiles) {
				if(AIBridge.IsBridgeTile(t)) {
					local other = AIBridge.GetOtherBridgeEnd(t);
					local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(t, other) + 1);
					bridge_list.Valuate(AIBridge.GetMaxSpeed);
					bridge_list.Sort(AIList.SORT_BY_VALUE, false);
					local latestBridge = bridge_list.Begin();
					if(latestBridge != AIBridge.GetBridgeID(t)) {
						if(AIBridge.RemoveBridge(t)) {
							if(!RailBuilder.BuildBridgeSafe(AIVehicle.VT_RAIL, latestBridge, t, other)) {
								HgLog.Warning("RailBuilder.BuildBridgeSafe failed:"+HgTile(t)+" "+AIError.GetLastErrorString()+" "+this);
							}
						} else {
							HgLog.Warning("AIBridge.RemoveBridge failed:"+HgTile(t)+" "+AIError.GetLastErrorString()+" "+this);
						}
					}
				}
			}
		}
		/*
		foreach(t in tiles) {
			if(AIRail.GetRailType(t)==railType) {
				continue;
			}
			if(!BuildUtils.RetryUntilFree(function():(t,railType) {
				return AIRail.ConvertRailType(t,t,railType);
			}, 500)) {
				HgLog.Warning("ConvertRailType failed:"+HgTile(t)+" "+AIError.GetLastErrorString());
				return false;
			}
			if(updateRailDepot != null && AIBridge.IsBridgeTile(t)) {
				local other = AIBridge.GetOtherBridgeEnd(t);
				local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(t, other) + 1);
				bridge_list.Valuate(AIBridge.GetMaxSpeed);
				bridge_list.Sort(AIList.SORT_BY_VALUE, false);
				local latestBridge = bridge_list.Begin();
				if(latestBridge != AIBridge.GetBridgeID(t)) {
					AIBridge.RemoveBridge(t);
					AIBridge.BuildBridge(AIVehicle.VT_RAIL, latestBridge, t, other);
				}
			}
		}*/
		engineSetsCache = null;
		return true;
	}
	
	
	function IsAllVehicleInUpdateRailDepot() {
		if(additionalRoute != null) {
			if(!additionalRoute.IsAllVehicleInUpdateRailDepot()) {
				return false;
			}
		}
		return IsAllVehicleLocation(updateRailDepot);
	}
	
	function DoUpdateRailType(newRailType) {
		local execMode = AIExecMode();
		HgLog.Info("DoUpdateRailType: "+AIRail.GetName(newRailType)+" "+this);
		RemoveSendUpdateDepotOrder();
		if(!ConvertRailType(newRailType)) {
			updateRailDepot = null;
			return false;
		}
		engineSetsCache = null;
		local oldVehicles = [];
		foreach(engineVehicle,v in engineVehicles) {
			oldVehicles.push(engineVehicle);
		}
		if(!BuildNewTrain()) {
			HgLog.Warning("newTrain == null "+this);
			updateRailDepot = null;
			return false;
		}
		foreach(engineVehicle in oldVehicles) {
			SellVehicle(engineVehicle);
		}
		HgTile(updateRailDepot).RemoveDepot();
		updateRailDepot = null;
		

		return true;
	}
	
	function SellVehicle(vehicle) {
		if(vehicle == latestEngineVehicle && !isRemoved) {
			HgLog.Warning("SellVehicle failed (vehicle == latestEngineVehicle) "+this);
			return;
		}
		if(!AIVehicle.SellWagonChain(vehicle, 0)) {
			HgLog.Warning("SellWagonChain failed "+AIError.GetLastErrorString()+" "+this);
			return;
		}
		engineVehicles.rawdelete(vehicle);
	}
	
	function OnVehicleWaitingInDepot(engineVehicle) {
		local execMode = AIExecMode();
		if(isClosed || reduceTrains) {
			if(isRemoved || latestEngineVehicle != engineVehicle) { //reopenに備えてlatestEngineVehicleだけ残す
				SellVehicle(engineVehicle);
				if(engineVehicles.len() == 0) {
					HgLog.Warning("All vehicles removed."+this);
					if(isRemoved) {
						RemoveFinished();
					}
					
				}
			}
		} else if(updateRailDepot != null) {
			if(AIVehicle.GetLocation(engineVehicle) != updateRailDepot) {
				AIVehicle.StartStopVehicle(engineVehicle);
			}
		} else {
			RenewalTrain(engineVehicle);
		}
	}
	
	function RenewalTrain(engineVehicle) {
		local execMode = AIExecMode();
		if(latestEngineVehicle == null) {
			return;
		}
		if(engineVehicle == latestEngineVehicle) {
			if(!BuildNewTrain()) {
				return;
			}
		}
		SellVehicle(engineVehicle);
	}
	
	function IsEqualEngine(vehicle1, vehicle2) {
		return AIVehicle.GetEngineType(vehicle1) == AIVehicle.GetEngineType(vehicle2) &&
			AIVehicle.GetWagonEngineType (vehicle1,0) == AIVehicle.GetWagonEngineType(vehicle2,0);
	}

	
	function Close() {
		HgLog.Warning("Close route start:"+this);
		isClosed = true;
		local execMode = AIExecMode();
		/*
		foreach(engineVehicle, v in engineVehicles) {
			//HgLog.Info("SendVehicleToDepot for renewal:"+engineVehicle+" "+ToString());
			if((AIOrder.OF_STOP_IN_DEPOT & AIOrder.GetOrderFlags(engineVehicle, AIOrder.ORDER_CURRENT)) == 0) {
				if(AIOrder.ResolveOrderPosition(engineVehicle, AIOrder.ORDER_CURRENT) == 0) {
					AIVehicle.SendVehicleToDepot (engineVehicle);
				}
			}
		}*/
		if(destHgStation.place != null) {
			if(destHgStation.place.IsClosed()) {
				destHgStation.place = null;
			}
		}
		
		if(additionalRoute != null) {
			additionalRoute.Close();
		}
		if(returnRoute != null) {
			returnRoute.Close();
		}
	}	
	
	function Remove() {					
		HgLog.Info("Remove route: "+this);
		isRemoved = true;
		Close();
	}

	function RemoveFinished() {
		HgLog.Warning("RemoveFinished: "+this);
		PlaceDictionary.Get().RemoveRoute(this);
		if(returnRoute != null) {
			returnRoute.Remove();
		}
		ArrayUtils.Remove(TrainRoute.instances, this);
		//TrainRoute.removed.push(this); 町の評価を考えるとすぐに削除した方が良いため
		if(HogeAI.Get().IsInfrastructureMaintenance()) {
			Demolish(); 
		}
	}

	function Demolish() { // ScanRoutesから呼ばれる
		HgLog.Warning("Demolish " + this);
		local execMode = AIExecMode();
		srcHgStation.RemoveIfNotUsed();
		foreach(station in destHgStations) {
			station.RemoveIfNotUsed();
		}
		pathSrcToDest.Remove(true/*physicalRemove*/, false/*DoInterval*/);
		if(pathDestToSrc != null) {
			pathDestToSrc.Remove(true/*physicalRemove*/, false/*DoInterval*/);
		}
		local tiles = [];
		tiles.extend(depots);
		tiles.extend(additionalTiles);
		foreach(tile in tiles) {
			if(AIRail.IsRailDepotTile(tile)) {
				AITile.DemolishTile(tile);
			}
			if(AIRail.IsRailTile(tile)) {
				RailBuilder.RemoveRailTracksAll(tile);
			}
		}
		if(returnRoute != null) {
			returnRoute.Demolish();
		}
	}

	function ReOpen() {
		HgLog.Warning("ReOpen route:"+this);
		isClosed = false;
		PlaceDictionary.Get().AddRoute(this);
		if(returnRoute != null) {
			returnRoute.ReOpen();
		}
		//BuildFirstTrain();
	}
	
	
	function IsInStationOrDepotOrStop(isTransfer){
		local srcStationId = srcHgStation.GetAIStation() 
		foreach(vehicle, v in engineVehicles) {
			if(AIStation.GetStationID(AIVehicle.GetLocation(vehicle)) == srcStationId
					|| AIVehicle.IsInDepot(vehicle) /*|| AIMap.DistanceManhattan(AIVehicle.GetLocation(vehicle),srcHgStation.platformTile) < 12*/) {
				return true;
			}
			if(isTransfer && AIVehicle.GetCurrentSpeed(vehicle) == 0) {
				return true;
			}
		}
		return false;
	}
	
	function GetMaxSpeed() {
		if(latestEngineVehicle == null) {
			return null;
		}
		local trainEngine = AIVehicle.GetEngineType( latestEngineVehicle );
		local wagonEngine = AIVehicle.GetWagonEngineType( latestEngineVehicle, 1 );
		local maxSpeed = AIEngine.GetMaxSpeed(trainEngine);
		local wagonMaxSpeed = AIEngine.GetMaxSpeed(wagonEngine);
		if(wagonMaxSpeed > 0) {
			maxSpeed = min(maxSpeed, wagonMaxSpeed);
		}
		local railMaxSpeed = AIRail.GetMaxSpeed(GetRailType());
		if(railMaxSpeed > 0) {
			maxSpeed = min(maxSpeed, railMaxSpeed);
		}
		return maxSpeed;
	}
	
	
	function RemoveReturnRoute() {
		
		if(returnRoute != null) {
			returnRoute.Remove();
			returnRoute = null;
		}
	}
	
	function IsAllVehiclePowerOnRail(newRailType) {
		foreach(vehicle,_ in engineVehicles) {
			local engine = AIVehicle.GetEngineType(vehicle);
			if(!AIEngine.HasPowerOnRail(engine, newRailType) || !AIEngine.CanRunOnRail(engine, newRailType)) {
				return false;
			}
		}
		return true;
	}
	
	function RollbackUpdateRailType(railType) {
		HgLog.Warning("RollbackUpdateRailType "+this+" additionalRoute:"+additionalRoute+" v:"+engineVehicles.len());
		failedUpdateRailType = true;
		updateRailDepot = null;
		ConvertRailType(railType);
		foreach(engineVehicle,v in engineVehicles) {
			if(AIVehicle.IsStoppedInDepot(engineVehicle)) {
				AIVehicle.StartStopVehicle(engineVehicle);
			}
		}
		if(additionalRoute != null) {
			additionalRoute.RollbackUpdateRailType(railType);
		}
	}
	
	function CalculateAverageUsedRate(usedRate) {
		local result = null;
		if(usedRateHistory.len() == 5) {
			local a = [];
			local sum = 0;
			foreach(i,e in usedRateHistory) {
				if(i == 0) {
					continue;
				}
				sum += e;
				a.push(e);
			}
			usedRateHistory = a;
			sum += usedRate;
			result = sum / 5;
		}
		usedRateHistory.push(usedRate);
		return result;
	}
	
	function IsCloneTrain() {
		local result = (maxTrains == null || maxTrains > engineVehicles.len())
			&& !IsInStationOrDepotOrStop(IsTransfer()) 
			&& (averageUsedRate == null || averageUsedRate < TrainRoute.USED_RATE_LIMIT)
			&& (latestEngineSet==null || IsWaitingCargoForCloneTrain() );
		if(!result) {
			return false;
		}
		if(IsTransfer()) {
			local destRoute = GetDestRoute();
			if(destRoute != false) {
				local needs = false;
				foreach(cargo in GetCargos()) {
					if(GetCargoCapacity(cargo) >= 1 && !IsDestOverflow(cargo)) {
						needs = true;
						break;
					}
				}
				if(!needs) {
					return false;
				}
			}
		}
		return result;
	}


	function IsWaitingCargoForCloneTrain() {
		foreach(cargo in GetCargos()) {
			local capacity = GetCargoCapacity(cargo);
			if(capacity == 0) {
				continue;
			}
			local station = srcHgStation.GetAIStation();
			local waiting = AIStation.GetCargoWaiting(station, cargo);
			if(waiting > capacity / 2) {
				return true;
			}
			if(waiting > capacity / 4 && AIStation.GetCargoRating (station, cargo) < 40) {
				return true;
			}
		}
		return false;
	}
		
	function CheckCloneTrain() {
		if(isClosed || isRemoved || updateRailDepot!=null || IsSingle()) {
			return;
		}
		
		
		if(IsCloneTrain()) {
			local numClone = 1;
			if(latestEngineSet != null) {
				if(latestEngineSet.vehiclesPerRoute - engineVehicles.len() >= 9) {
					numClone = 4;
				} else if(latestEngineSet.vehiclesPerRoute - engineVehicles.len() >= 6) {
					numClone = 3;
				} else if(latestEngineSet.vehiclesPerRoute - engineVehicles.len() >= 3) {
					numClone = 2;
				}
			}
			local waiting = AIStation.GetCargoWaiting(srcHgStation.GetAIStation(), cargo);
			local capacity = GetCargoCapacity(cargo);
			numClone = max(1,min( numClone, waiting / capacity ));
			for(local i=0; i<numClone; i++) {
				CloneAndStartTrain();
			}
		}
	}
	
	function CheckTrains() {
		local execMode = AIExecMode();
		local engineSet = null;

		if(isClosed) {
			foreach(engineVehicle, v in engineVehicles) {
				//HgLog.Info("SendVehicleToDepot(isClosed):"+engineVehicle+" "+ToString());
				SendVehicleToDepot(engineVehicle);
			}
		}
		foreach(engineVehicle, _ in engineVehicles) {
			if(!AIVehicle.IsValidVehicle (engineVehicle)) {
				HgLog.Warning("Invalid veihicle found "+engineVehicle+" at "+this);
				engineVehicles.rawdelete(engineVehicle);
				if(latestEngineVehicle == engineVehicle) {
					HgLog.Warning("latestEngineVehicle == engineVehicle "+this);
					if(engineVehicles.len() == 0) {
						HgLog.Warning("engineVehicles.len() == 0 "+this);
					} else {
						foreach(engineVehicle, _ in engineVehicles) {
							latestEngineVehicle = engineVehicle;
							break;
						}
					}
				}
				continue;
			}
			if(AIVehicle.IsStoppedInDepot(engineVehicle)) {
				OnVehicleWaitingInDepot(engineVehicle);
			}
		}
		
		if(isClosed || updateRailDepot!=null) {
			return;
		}


		if(AIBase.RandRange(100) < 10 && CargoUtils.IsPaxOrMail(cargo)) { // 作った時には転送が無い時がある
			foreach(townCargo in [HogeAI.Get().GetPassengerCargo(), HogeAI.Get().GetMailCargo()]) {
				if(NeedsAdditionalProducingCargo(townCargo, null, false)) {
					CommonRouteBuilder.CheckTownTransferCargo(this,srcHgStation,townCargo);
				}
				if(IsBiDirectional() && NeedsAdditionalProducingCargo(townCargo, null, true)) {
					CommonRouteBuilder.CheckTownTransferCargo(this,destHgStation,townCargo);
				}
			}
		}
		
		local isBiDirectional = IsBiDirectional();
		
		if(lastChangeDestDate != null && lastChangeDestDate + 120 < AIDate.GetCurrentDate()) {
			local removed = [];
			foreach(station in destHgStations) {
				if(station != destHgStation && station != destHgStations[destHgStations.len()-1]) {
					if(HogeAI.Get().ecs && station.place != null && !(station.place instanceof TownCargo)) {
						continue;
					}
					if(station.place != null && station.place instanceof TownCargo && !CargoUtils.IsPaxOrMail(cargo)) {
						continue;
					}
					/* SendDepotのタイミングによってはどうしても分岐側へ移動して本線を詰まらせる事があるので削除しない。
					platformだけの削除もRailUpdateの兼ね合いがあるので難しい
					if(!station.IsRemoved()) {
						station.RemoveUsingRoute(this);
						station.Remove();
						//station.RemoveOnlyPlatform();
						removed.push(station);
					}*/
				}
			}
			foreach(removedStation in removed) {
				ArrayUtils.Remove(destHgStations, removedStation);
			}
			lastChangeDestDate = null;
		}
		
		if(!HogeAI.HasIncome(20000) || !ExistsMainRouteExceptSelf()) {
			//HgLog.Warning("Cannot renewal train "+this);
			return;
		}
		
		engineSet = ChooseEngineSet();
//		HgLog.Warning("ChooseEngineSet "+engineSet+" "+this);
		if(engineSet == null) {
			HgLog.Warning("No usable engineSet ("+AIRail.GetName(GetRailType())+") "+this);
			return;
		}
		if(engineSet.price > HogeAI.Get().GetUsableMoney()) {
			return; // すぐに買えない場合はリニューアルしない。車庫に列車が入って収益性が著しく悪化する場合がある
		}
		foreach(engineVehicle, v in engineVehicles) {
			if(!HasVehicleEngineSet(engineVehicle,engineSet) || AIVehicle.GetAgeLeft (engineVehicle) <= 600) {
				if(isBiDirectional || AIVehicle.GetCargoLoad(engineVehicle,cargo) == 0) {
					//HgLog.Info("SendVehicleToDepot(renewal or age):"+engineVehicle+" "+this);
					SendVehicleToDepot(engineVehicle);
				}
			}
		}
	}
	
	function ExistsMainRouteExceptSelf() {
		foreach(route in TrainRoute.instances) {
			if(route.IsTransfer()) {
				continue;
			}
			if(route != this) {
				return true;
			}
		}
		return false;
	}

	
	function HasVehicleEngineSet(vehicle, engineSet) {
		if(engineSet == null) { // 作れるlocoが無くなるとnullになる
			return true;
		}
		if(!engineVehicles.rawin(vehicle)) {
			HgLog.Warning("!engineVehicles.rawin("+vehicle+") "+this);
			return false;
		}
		local vehicleEngineSet = engineVehicles[vehicle];
		if(vehicleEngineSet == engineSet) {
			return true;
		}
		if(vehicleEngineSet.engine != engineSet.engine) {
			return false;
		}
		if(vehicleEngineSet.numLoco != engineSet.numLoco) {
			return false;
		}
		foreach(index,wagonInfo in engineSet.wagonEngineInfos) {
			if(vehicleEngineSet.wagonEngineInfos.len() <= index) {
				return false;
			}
			local vehicleWagonInfo = vehicleEngineSet.wagonEngineInfos[index];
			if(vehicleWagonInfo.engine != wagonInfo.engine) {
				return false;
			}
			if(vehicleWagonInfo.numWagon != wagonInfo.numWagon) {
				return false;
			}
		}
		return true;
		
		/*
		
		if(vehicleEngineSet.numLoco != engineSet.numLoco) {
			return false;
		}
		
		
		local wagons = AIVehicle.GetNumWagons(vehicle);
		local totalNum = engineSet.numLoco;
		foreach(wagonEngineInfo in engineSet.wagonEngineInfos) {
			totalNum += wagonEngineInfo.numWagon;
		}
		if(totalNum != wagons) {
			//HgLog.Info(engineSet.numLoco+"+"+engineSet.numWagon+"!="+wagons+" route:"+this);
			return false;
		}
		local trainEngine = AIVehicle.GetEngineType(vehicle);
		if(engineSet.trainEngine != trainEngine) {
			//HgLog.Info(AIEngine.GetName(trainEngine)+" newLogo:"+AIEngine.GetName(engineSet.trainEngine)+" route:"+this);
			return false;
		}
		local index = engineSet.numLoco;
		foreach(wagonEngineInfo in engineSet.wagonEngineInfos) {
			if(index < wagons && wagonEngineInfo.numWagon >= 1) {
				local wagonEngine = AIVehicle.GetWagonEngineType(vehicle, index);
				if(wagonEngine != wagonEngineInfo.engine) {
					//HgLog.Info(AIEngine.GetName(wagonEngine)+" newWagon:"+AIEngine.GetName(wagonEngineInfo.engine)+" route:"+this);
					return false;
				}
				index += wagonEngineInfo.numWagon;
			}
		}
		//HgLog.Info("HasVehicleEngineSet return true "+AIEngine.GetName(trainEngine)+" route:"+this);
		return true;*/
	}
	
	function SendVehicleToDepot(vehicle) {
		if(IsUpdatingRail()) {
			return;
		}
		if((AIOrder.OF_STOP_IN_DEPOT & AIOrder.GetOrderFlags(vehicle, AIOrder.ORDER_CURRENT)) == 0) {
			if(AIOrder.ResolveOrderPosition(vehicle, AIOrder.ORDER_CURRENT) != 2 ) { //行きにSendToDepotが入るとささくれに入る
				AIVehicle.SendVehicleToDepot (vehicle);
			}
/* 
			if(IsBiDirectional() || returnRoute != null) {
				AIVehicle.SendVehicleToDepot (vehicle);
			} else {
				if(AIOrder.ResolveOrderPosition(vehicle, AIOrder.ORDER_CURRENT) == 0) {
					AIVehicle.SendVehicleToDepot (vehicle);
				}
			}*/
		}
	}
	
	function IsUpdatingRail() {
		return updateRailDepot != null;
	}
	
	
	function CheckRailUpdate() {
		if(latestEngineVehicle == null || isBuilding || isClosed || failedUpdateRailType || IsChangeDestination()) {
			return;
		}
		if(lastConvertRail != null && AIDate.GetCurrentDate() < lastConvertRail + 15 * 365) {
			//HgLog.Info("lastConvertRail:"+DateUtils.ToString(lastConvertRail)+" "+this);
			// 一度コンバートしてから15年間はkeep
			return;
		}
		
		local currentRailType = GetRailType();

		if(updateRailDepot != null) {
			if(IsAllVehicleInUpdateRailDepot()) {
				local newEngineSet = ChooseEngineSetAllRailTypes();
				if(newEngineSet==null) {
					HgLog.Warning("newEngineSet==null (ChooseEngineSetAllRailTypes)");
					return;
				}
				local newRailType = newEngineSet.railType;
				if(!DoUpdateRailType(newRailType)) {
					RollbackUpdateRailType(currentRailType);
				} else {
					if(additionalRoute != null) {
						if(!additionalRoute.DoUpdateRailType(newRailType)) {
							RollbackUpdateRailType(currentRailType);
						}
					}
				}
			}
			return;
		}

/*		if(AIBase.RandRange(100)>=5) { // この先は重いのでたまにやる
			return;
		}*/

		local newEngineSet = ChooseEngineSetAllRailTypes();
		if(newEngineSet==null) {
			if(HogeAI.Get().IsInfrastructureMaintenance()) {
				HgLog.Warning("Rmove TrainRoute(EngineSet not available)."+this);
				Remove();
			}
			return;
		}
		if(newEngineSet.routeIncome < 0 && !IsTransfer()
				&& (destHgStation.place == null 
						|| destHgStation.place instanceof TownCargo || destHgStation.place.GetProducing().GetRoutesUsingSource().len() == 0)) {
			HgLog.Warning("Rmove TrainRoute(Not profitable)."+this);
			Remove();
			return;
		}
		
		local newEngine = newEngineSet.trainEngine;
		local newRailType = newEngineSet.railType;
		
		if(AIEngine.HasPowerOnRail(newEngine, currentRailType) &&
				(AIRail.GetMaxSpeed(currentRailType) == 0
				|| (AIRail.GetMaxSpeed(newRailType) >= 1 && AIRail.GetMaxSpeed(currentRailType) >= AIRail.GetMaxSpeed(newRailType)))) {
			return;
		}
		
		if(newRailType != currentRailType) {
			HgLog.Info("Engine:"+AIEngine.GetName(newEngine)+" request new railType."+this);
			if(IsAllVehiclePowerOnRail(newRailType)) {
				if(!ConvertRailType(newRailType)) {
					ConvertRailType(currentRailType);
					failedUpdateRailType = true;
				}
				if(additionalRoute != null) {
					if(!additionalRoute.ConvertRailType(newRailType)) {
						additionalRoute.ConvertRailType(currentRailType);
						ConvertRailType(currentRailType);
						failedUpdateRailType = true;
					}
				}
				if(!failedUpdateRailType) {
					engineSetsCache = null;
				}
			} else {
				StartUpdateRail(newRailType);
				if(additionalRoute != null) {
					additionalRoute.StartUpdateRail(newRailType);
				}
			}
		}
	}
	

	function CheckClose() {
		if(isRemoved || IsBuilding()) {
			return;
		}
		/*
		if(srcHgStation.GetName().find("0172") != null) {
			HgLog.Warning("IsTransfer:"+IsTransfer()+" IsBiDirectional:"+IsBiDirectional());
			Initialize();
		}*/

		if(srcHgStation.place != null && srcHgStation.place.IsClosed()) {
			HgLog.Warning("Route Remove (src place closed)"+this);
			Remove();
			return;
		}
	
		if(IsTransfer() || IsSingle()) {
			Route.CheckClose();
/*			local destRoute = GetDestRoute();
			if(destRoute == false || destRoute.IsRemoved()) {
				Remove();
				return;
			}
			if(isClosed) {
				if(!destRoute.IsClosed() && destRoute.HasCargo(cargo)) {
					ReOpen();
				}
			} else {
				if(destRoute.IsClosed() || !destRoute.HasCargo(cargo)) {
					Close();
				}
			}*/
		} else {
			local currentStationIndex;
			for(currentStationIndex=destHgStations.len()-1; currentStationIndex>=0 ;currentStationIndex--) {
				if(destHgStations[currentStationIndex] == destHgStation) {
					break;
				}
			}
			local acceptableStationIndex;
			for(acceptableStationIndex=destHgStations.len()-1; acceptableStationIndex>=0 ;acceptableStationIndex--) {
				if(destHgStations[acceptableStationIndex].IsRemoved()) { // destへの転送路線が削除されると一緒にRemoveされることがある
					continue;
				}
				local accepting = false;
				if(destHgStations[acceptableStationIndex].stationGroup.IsAcceptingCargo(cargo) && HasCargo(cargo)) {
					accepting = true;
				}
				//HgLog.Info("CloseCheck:"+destHgStations[acceptableStationIndex]+" IsAccepting:"+accepting+" "+this);
				if(accepting) {
					if(acceptableStationIndex == currentStationIndex) {
						break;
					}
					// TODO return routeの問題
					ChangeDestination(destHgStations[acceptableStationIndex], cannotChangeDest);
					break;
				}
			}
			if(currentStationIndex != acceptableStationIndex && currentStationIndex == destHgStations.len()-1) {
				lastDestClosedDate = AIDate.GetCurrentDate();
				//CheckStockpiled();
			}
			
			if(isClosed) {
				if(acceptableStationIndex != -1) {
					ReOpen();
				}
			} else {
				if(acceptableStationIndex == -1 && returnRoute != null) {
					if(destHgStations[destHgStations.len()-1].place != null && destHgStations[destHgStations.len()-1].place.IsClosed()) {
						HgLog.Warning("Route Remove (dest place closed)"+this);
						Remove(); //TODO 最終以外が単なるCloseの場合、Removeは不要。ただしRemoveしない場合、station.placeは更新する必要がある。レアケースなのでとりあえずRemove
					} else {
						//if(!HogeAI.Get().ecs) { 新規ルート作成を促す //ソース元の生産の健全性を保つため一時的クローズはしない(ECS)
							Close();
						//}
					}
				}
			}
		}
	}

	function NotifyAddTransfer(callers=null) {
		Route.NotifyAddTransfer(callers);
		engineSetsCache = null;
	}
	
}

class TrainReturnRoute extends Route {
	originalRoute = null;
	srcHgStation = null;
	destHgStation = null;
	srcArrivalPath = null;
	srcDeparturePath = null;
	destArrivalPath = null;
	destDeparturePath = null;

	depots = null;
	subCargos = null;
	
	constructor(originalRoute, srcHgStation, destHgStation, srcArrivalPath, srcDeparturePath, destArrivalPath, destDeparturePath) {
		Route.constructor();
		this.originalRoute = originalRoute;
		this.srcHgStation = srcHgStation;
		this.destHgStation = destHgStation;
		this.srcArrivalPath = srcArrivalPath;
		this.srcDeparturePath = srcDeparturePath;
		this.destArrivalPath = destArrivalPath;
		this.destDeparturePath = destDeparturePath;
		this.srcArrivalPath.route = this;
		this.srcDeparturePath.route = this;
		this.destArrivalPath.route = this;
		this.destDeparturePath.route = this;
		this.depots = [];
	}
	

	
	function Save() {
		local t = {};
		t.srcHgStation <- srcHgStation.id;
		t.destHgStation <- destHgStation.id;
		t.srcArrivalPath <- srcArrivalPath.path.Save();
		t.srcDeparturePath <- srcDeparturePath.path.Save();
		t.destArrivalPath <- destArrivalPath.path.Save();
		t.destDeparturePath <- destDeparturePath.path.Save();
		t.depots <- depots;
		t.subCargos <- subCargos;
		return t;
	}
	
	static function Load(t, originalRoute) {
		local result = TrainReturnRoute(
			originalRoute,
			HgStation.worldInstances[t.srcHgStation],
			HgStation.worldInstances[t.destHgStation],
			BuildedPath(Path.Load(t.srcArrivalPath)),
			BuildedPath(Path.Load(t.srcDeparturePath)),
			BuildedPath(Path.Load(t.destArrivalPath)),
			BuildedPath(Path.Load(t.destDeparturePath)));
		result.depots = t.rawin("depots") ? t.depots : [];
		result.subCargos = t.subCargos;
		return result;
	}

	function AddDepots(depots) {
		this.depots.extend(depots);
	}

	function Initialize() {
		InitializeSubCargos();
	}
	
	function InitializeSubCargos() {
		subCargos = [];
		local acceptingCargos = CalculateSubCargos();
		foreach(subCargo in acceptingCargos) {
			if(originalRoute.HasCargo(subCargo)) {
				subCargos.push(subCargo);
			}
		}
	}
	
	function GetLatestEngineSet() {
		return originalRoute.GetLatestEngineSet();
	}

	function ChooseEngineSet() {
		return originalRoute.ChooseEngineSet();
	}

	function Close() {
	}
	
	function ReOpen() {
	}
	
	function IsTransfer() {
		return false;
	}
	
	function IsBiDirectional() {
		return false;
	}
	
	function IsSingle() {
		return false;
	}
	
	function GetVehicleType() {
		return AIVehicle.VT_RAIL;
	}
		
	function GetCargoCapacity(cargo) {
		return originalRoute.GetCargoCapacity(cargo);
	}
	
	/* function IsOverflow(isDest = false, hgStation = null) {
		if(hgStation == null) {
			hgStation = isDest ? destHgStation : srcHgStation;
		}
		return AIStation.GetCargoWaiting (hgStation.GetAIStation(), cargo) > originalRoute.GetOverflowQuantity();
	}*/
	
	function IsClosed() {
		return IsRemoved() || originalRoute.IsClosed();
	}
	
	function IsRemoved() {
		return this != originalRoute.returnRoute || originalRoute.IsRemoved();
	}
	
	function _get(idx) {
		switch (idx) {
			case "cargo":
				return originalRoute.cargo;
			case "lastDestClosedDate": // TODO: return routeのdest closeには対応していない。一時的に受け入れ拒否された場合にsrcへcargoをそのまま持ち帰ってしまうのでrouteが死ぬ
				return null;
			default: 
				throw("the index '" + idx + "' does not exist");
		}
	}
	
	function GetCargos() {
	
		if(originalRoute == null) {
			return [];
		}
		local result = [originalRoute.cargo];
		local vehicle = originalRoute.latestEngineVehicle;
		if(vehicle == null) {
			return result;
		}
		foreach(subCargo in subCargos) {
			if( AIVehicle.GetCapacity(vehicle, subCargo) >= 1 ) {
				result.push(subCargo);
			}
		}
		return result;
	}
	
	function IsReturnRoute(isDest) {
		return !isDest;
	}

	
	function GetFacilities() {
		return [srcHgStation, destHgStation, srcArrivalPath.path, srcDeparturePath.path, destArrivalPath.path, destDeparturePath.path, depots];
	}
	
	function Remove(){
		if(originalRoute == null) {
			HgLog.Warning("ReturnRoute.Remove() originalRoute == null "+this);
			return;
		}
		PlaceDictionary.Get().RemoveRoute(this);
		originalRoute.RemoveReturnTransferOder();
		originalRoute.returnRoute = null;
	}
	
	function Demolish(){
		srcHgStation.RemoveIfNotUsed();
		destHgStation.RemoveIfNotUsed();
		srcArrivalPath.Remove();
		srcDeparturePath.Remove();
		destArrivalPath.Remove();
		destDeparturePath.Remove();
	}

	function _tostring() {
		return "ReturnRoute:"+destHgStation.GetName() + "<-"+srcHgStation.GetName()+"["+AICargo.GetName(cargo)+"]";
	}
}

class TrainRouteBuilder extends RouteBuilder {

	function GetRouteClass() {
		return TrainRoute;
	}

	function DoBuild() {
		return HogeAI.Get().BuildRouteAndAdditional(dest,src,cargo,options);
	}
	
}
