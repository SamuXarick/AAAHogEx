﻿
class RoadRoute extends CommonRoute {
	static instances = [];
	static used = {};
	static pendingDemolishLines = {};
	static roadTypeDepot = {};
	static engineInfos = {};
	static compatibleRoadTypes = {};

	static function SaveStatics(data) {
		local a = [];
		foreach(route in RoadRoute.instances) {
			a.push(route.Save());
		}
		data.roadRoutes <- a;
		data.roadUsed <- RoadRoute.used;
		data.roadTypeDepot <- RoadRoute.roadTypeDepot;
		data.engineInfos <- RoadRoute.engineInfos;
		data.pendingDemolishLines <- RoadRoute.pendingDemolishLines;
	}
	
	static function LoadStatics(data) {
		RoadRoute.instances.clear();
		foreach(t in data.roadRoutes) {
			local route = RoadRoute();
			route.Load(t);
			
			HgLog.Info("load:"+route);
			
			RoadRoute.instances.push(route);	
			PlaceDictionary.Get().AddRoute(route);
		}
		if(data.rawin("roadUsed")) {
			HgTable.Extend(RoadRoute.used, data.roadUsed);
		}
		if(data.rawin("pendingDemolishLines")) {
			HgTable.Extend(RoadRoute.pendingDemolishLines, data.pendingDemolishLines);
		}
		if(data.rawin("roadTypeDepot")) {
			HgTable.Extend(RoadRoute.roadTypeDepot,data.roadTypeDepot);
		}
		if(data.rawin("engineInfos")) {
			HgTable.Extend(RoadRoute.engineInfos,data.engineInfos);
		}
	}
	
	static function AddUsedTile(tile,isTram=false) {
		local cnt = 1;
		local usedMap = RoadRoute.GetUsedMap(isTram);
		if(usedMap.rawin(tile)) {
			cnt = usedMap[tile] + 1;
		}
		usedMap.rawset(tile, cnt);
		HgLog.Info("RoadRoute.AddUsedTile:"+HgTile(tile)+" cnt:"+cnt+" isTram:"+isTram);
	}
	
	static function RemoveUsedTile(tile,isTram=false) {
		local usedMap = RoadRoute.GetUsedMap(isTram);
		if(usedMap.rawin(tile)) {
			local cnt = usedMap[tile] - 1;
			if(cnt >= 1) {
				usedMap.rawset(tile, cnt);
				HgLog.Info("RoadRoute.RemoveUsedTile:"+HgTile(tile)+" cnt:"+cnt+" isTram:"+isTram);
				return false;
			} else {
				usedMap.rawdelete(tile);
			}
		}
		HgLog.Info("RoadRoute.RemoveUsedTile:"+HgTile(tile)+" cnt:0 isTram:"+isTram);
		return true;
	}
	
	
	static function IsUsedTile(tile,isTram=false) {
		local usedMap = RoadRoute.GetUsedMap(isTram);
		return usedMap.rawin(tile) && usedMap[tile] >= 1;
	}

	static function GetUsedMap(isTram) {
		if(!RoadRoute.used.rawin(isTram)) {
			RoadRoute.used.rawset(isTram,{});
		}
		return RoadRoute.used.rawget(isTram);
	}
	
	static function GetPendingDemolishLines(isTram) {
		if(!RoadRoute.pendingDemolishLines.rawin(isTram)) {
			RoadRoute.pendingDemolishLines.rawset(isTram,[]);
		}
		return RoadRoute.pendingDemolishLines.rawget(isTram);
	}
	
	static function IsTramCurrent() {
		return AIRoad.GetRoadTramType(AIRoad.GetCurrentRoadType()) == AIRoad.ROADTRAMTYPES_TRAM;
	}
	
	static function IsRoadTypeTram(roadType) {
		return AIRoad.GetRoadTramType(roadType) == AIRoad.ROADTRAMTYPES_TRAM;
	}
	
	static function GetTileRoadType(tile, isTram) {
		local roadTypes = AIRoadTypeList( isTram ? AIRoad.ROADTRAMTYPES_TRAM : AIRoad.ROADTRAMTYPES_ROAD );
		foreach(roadType,_ in roadTypes) {
			if(AIRoad.HasRoadType(tile,roadType)) {
				return roadType;
			}
		}
		return null;
	}
	
	static function GetEngineDepot(engine) {
		local roadType = AIEngine.GetRoadType(engine);
		if(!RoadRoute.roadTypeDepot.rawin(roadType)) {
			
			local execMode = AIExecMode();
			local oldRoadType = AIRoad.GetCurrentRoadType();
			AIRoad.SetCurrentRoadType(roadType);
			local depot = RoadRoute.CreateSampleDepot();
			if(depot == null) {
				AIRoad.SetCurrentRoadType(oldRoadType);
				HgLog.Warning("CreateDepot failed (GetSampleDepot) "+AIError.GetLastErrorString()+" "+AIRoad.GetName(roadType));
				return null;
			}
			AIRoad.SetCurrentRoadType(oldRoadType);
			RoadRoute.roadTypeDepot[roadType] <- depot;
		}
		return RoadRoute.roadTypeDepot[roadType];
	}
	
	static function CreateSampleDepot() {
		local exec = AIExecMode();
		for(local i=0; i<32; i++) {
			local x = AIBase.RandRange(AIMap.GetMapSizeX()-20) + 10;
			local y = AIBase.RandRange(AIMap.GetMapSizeY()-20) + 10;
			local depotTile = AIMap.GetTileIndex (x, y);
			HogeAI.WaitForMoney(1000);
			if(AIRoad.BuildRoadDepot ( depotTile,  depotTile+1)) {
				return depotTile;
			}
		}
		return null;
	}
	
	static function CanGoUpSlope(engine,cargo,capacity) {
		local engineInfo;
		if(!RoadRoute.engineInfos.rawin(engine)) {
			engineInfo = {};
			RoadRoute.engineInfos.rawset(engine,engineInfo);
		} else {
			engineInfo = RoadRoute.engineInfos[engine];
		}
		if(engineInfo.rawin("canGoUpSlope")) {
			return engineInfo.canGoUpSlope;
		}
		local weight = VehicleUtils.GetCommonCargoWeight(cargo,capacity) + AIEngine.GetWeight(engine);
		local capacityForTE = RoadRoute.GetCapacityForTractiveEffort(engine,cargo);
		local tractiveEffort = AIEngine.GetMaxTractiveEffort(engine) / AIEngine.GetWeight(engine);
		local maxTractiveEffort = tractiveEffort * (AIEngine.GetWeight(engine) + VehicleUtils.GetCommonCargoWeight(cargo,capacityForTE));
		HgLog.Info(AIEngine.GetName(engine)
				+" cargo:"+AICargo.GetName(cargo)
				+" TE:"+tractiveEffort
				+" weight:"+weight
				+" capaForTE:"+capacityForTE
				+" MaxTE:"+maxTractiveEffort
				+" slopeforce:"+VehicleUtils.GetRoadSlopeForce(weight));
		
		if(maxTractiveEffort * 1000 < VehicleUtils.GetRoadSlopeForce(weight)) {
			HgLog.Warning("CanNotGoUpSlope");
			engineInfo.canGoUpSlope <- false;
		} else {
			engineInfo.canGoUpSlope <- true;
		}
		return engineInfo.canGoUpSlope;
	}
	
	static function GetCapacityForTractiveEffort(engine, cargo) {
		local depot = RoadRoute.GetEngineDepot(engine);
		if(depot != null) {
			local result = AIVehicle.GetBuildWithRefitCapacity(depot, engine, cargo);
			HgLog.Warning("GetBuildWithRefitCapacity "+AIEngine.GetName(engine)+" "+AICargo.GetName(cargo)+" "+result);
			if(result != -1) {
				return result;
			}
			HgLog.Warning("GetBuildWithRefitCapacity failed (GetCapacityForTractiveEffort) "+AIError.GetLastErrorString()+" "+AIEngine.GetName(engine));
		}
		return AIEngine.GetCapacity(engine);
	}
	
	static function GetRoadCruiseSpeed(engine,cargo,capacity) {
		local maxTe = AIEngine.GetMaxTractiveEffort(engine);
		local power = AIEngine.GetPower(engine);
		local weight = VehicleUtils.GetCommonCargoWeight(cargo,capacity) + AIEngine.GetWeight(engine);
		local coeff = AIEngine.HasPowerOnRoad(engine, AIRoad.ROADTYPE_TRAM) ? 40 : 75;
		local axleFriction  = 10 * weight;
		local maxSpeed = AIEngine.GetMaxSpeed(engine);
		local minSpeed = 0;
		
		while(true) {
			local speed = (maxSpeed + minSpeed) / 2;
			if(speed<=3 || maxSpeed - minSpeed < 5) {
				return speed;
			}
			local rollingFriction = (coeff * (128 + speed) / 128) * weight;
			local airDrag = 30 * speed;
			local force = min(maxTe * 1000, (power * 746) / (speed * 5/18));
			local acc = force - rollingFriction - axleFriction - airDrag;
			if(acc == 0) {
				return speed;
			} else if(acc < 0) {
				maxSpeed = speed;
			} else {
				minSpeed = speed;
			}
		}
	}
	
	static function GetCompatibleRoadTypes(roadType) {
		if(RoadRoute.compatibleRoadTypes.rawin(roadType)) {
			return RoadRoute.compatibleRoadTypes[roadType];
		}
		local result = {};
		local engines = AIEngineList(AIVehicle.VT_ROAD);
		engines.Valuate(AIEngine.HasPowerOnRoad, roadType);
		engines.KeepValue(1);
		foreach(t in AIRoadTypeList(AIRoad.GetRoadTramType(roadType))) {
			local tmpEngines = AIList();
			tmpEngines.AddList(engines);
			tmpEngines.Valuate(AIEngine.HasPowerOnRoad, t);
			tmpEngines.KeepValue(1);
			if(engines.Count() == tmpEngines.Count()) result.rawset(t,0);
		}
		RoadRoute.compatibleRoadTypes.rawset(roadType, result);
		return result;
	}
	
	static function IsCompatibleRoadType(roadTypeA, roadTypeB) {
		return RoadRoute.GetCompatibleRoadTypes(roadTypeA).rawin(roadTypeB);
	}
	
	depots = null;
	roadType = null;
	usedTiles = null;
	myTileNum = null;
	lastRebuildDate = null;
	
	constructor() {
		CommonRoute.constructor();
		depots = [];
		usedTiles = [];
		isDestFullLoadOrder = true;
		myTileNum = 0;
	}
	
	function Load(t) {
		CommonRoute.Load(t);
		depots = saveData.depots;
		roadType = saveData.roadType;
		usedTiles = saveData.usedTiles;
		myTileNum = saveData.myTileNum ;
		lastRebuildDate = saveData.lastRebuildDate;
		usedTiles = saveData.usedTiles ;
	}
	
	function UpdateSavedData() {
		CommonRoute.UpdateSavedData();

		saveData.depots <- depots;
		saveData.roadType <- roadType;
		saveData.usedTiles <- usedTiles;
		saveData.myTileNum <- myTileNum;
		saveData.lastRebuildDate <- lastRebuildDate;
		saveData.usedTiles <- usedTiles;
	}
	
	function Initialize() {
		CommonRoute.Initialize();
		saveData.roadType = roadType = AIRoad.GetCurrentRoadType();
		HgLog.Info("Initialize roadType:"+AIRoad.GetName(roadType)+" "+this);
	}
	
	function GetVehicleType() {
		return AIVehicle.VT_ROAD;
	}
	
	function GetMaxTotalVehicles() {
		return HogeAI.Get().maxRoadVehicle;
	}

	function GetThresholdVehicleNumRateForNewRoute() {
		return 0.8; //既存ルートでこれから増える分があるので　CommonRoute.IsSupportModeVt(AIVehicle.VT_ROAD) ? 0.80 : 0.95;
	}

	function GetThresholdVehicleNumRateForSupportRoute() {
		return 0.9;
	}
	
	function GetLabel() {
		return "Road";
	}

	function GetBuilderClass() {
		return RoadRouteBuilder;
	}
	
	function GetInfrastractureTypes(engine) {
		if((typeof this) == "instance" && this instanceof RoadRoute) {
			foreach(i in RoadRouteBuilder.GetHasPowerRoadTypes(engine)) {
				if(i == roadType) {
					return [roadType];
				}
			}
			return [];
		}
		return RoadRouteBuilder.GetHasPowerRoadTypes(engine);
	}
	
	function GetInfrastractureCost(infrastractureType, distance) {
		local a = InfrastructureCost.Get().GetCostPerDistanceRoad(infrastractureType);
		local totalDistance = a[0];
		local costPerDistance = a[1];
		if(totalDistance != 0) {
			return (costPerDistance * totalDistance * (pow((totalDistance + distance).tofloat() / totalDistance, 1.49) - 1)).tointeger();
		} else {
			return distance * costPerDistance;
		}
	}
	
	function GetRouteInfrastractureCost() {
		if(!HogeAI.Get().IsInfrastructureMaintenance()) return 0;
		local usedMap = RoadRoute.GetUsedMap(IsTram());
		local pre = null;
		local roadTypeAcc = {};
		local isTram = IsTram();
		local roadTypes = AIRoadTypeList( isTram ? AIRoad.ROADTRAMTYPES_TRAM : AIRoad.ROADTRAMTYPES_ROAD );
		local currentRoadType = GetRoadType();
		foreach(r,_ in roadTypes) {
			roadTypeAcc.rawset(r,0.0);
		}
		roadTypeAcc.rawset(currentRoadType, 0.0);
		foreach(tile in usedTiles) {
			if(usedMap.rawin(tile)) {
				if(AICompany.IsMine( AITile.GetOwner(tile) )) {
					local roadType = RoadRoute.GetTileRoadType(tile,isTram);
					if(roadType == null) {
						//町道にドライブスルーステーションがあるとここくる
						//HgLog.Warning("unknown roadType:"+HgTile(tile)+" isTram:"+isTram+" "+this);
						continue;
					}
					local count = usedMap.rawget(tile);
					local pieces = 2.0;
					if(pre != null) {
						local length = AIMap.DistanceManhattan(pre,tile);
						if(length >= 2) pieces = (length+1) * 8.0;
					}
					roadTypeAcc[roadType] += pieces / count;
				}
			}
			pre = tile;
		}
		
		roadTypeAcc[currentRoadType] += depots.len() * 2;
		roadTypeAcc[currentRoadType] += 12 * 2; // road station;
		local result = 0;
		foreach(rt, acc in roadTypeAcc) {
			result += (InfrastructureCost.GetCostPerRoad(rt) * acc).tointeger();
		}
		return result;
	}
	
	function GetInfrastractureSpeed(infrastractureType) {
		return AIRoad.GetMaxSpeed(infrastractureType) / 2; // The speed is in OpenTTD's internal speed unit. This is mph / 0.8, which is roughly 0.5 km/h. To get km/h multiply this number by 2.01168.
	}

	function EstimateMaxRouteCapacity(infrastractureType, engineCapacity) {
		return engineCapacity * 10; //5;
	}

	
	function GetRoadType() {
		return roadType;
	}
	
	function IsTram() {
		return AIRoad.GetRoadTramType(roadType) == AIRoad.ROADTRAMTYPES_TRAM;
	}

	function GetInfrastractureType() {
		return roadType;
	}

	function SetPath(path) {
		local needDepot = GetDistance() >= 150 && HogeAI.Get().IsEnableVehicleBreakdowns();
		local execMode = AIExecMode();
		local count = 0;
		local isTram = IsTram();
		usedTiles = path.GetTiles();
		while(path != null) {
			if(needDepot && count % 100 == 99) {
				local depot = path.BuildDepot(GetVehicleType());
				if(depot != null) {
					depots.push(depot);
					HgLog.Info("Build middle depot."+HgTile(depot)+" "+this);
				} else {
					HgLog.Warning("Build middle depot failed."+this);
				}
			}
			local tile = path.GetTile();
			local cnt = RoadRoute.AddUsedTile(tile,isTram);
			if(AICompany.IsMine(AITile.GetOwner(path.GetTile()))) {
				myTileNum ++;
			}
			count ++;
			path = path.GetParent();
		}
	}

	function AppendSrcToDestOrder(vehicle) {
		if(HogeAI.Get().IsEnableVehicleBreakdowns()) {
			foreach(depot in depots) {
				AIOrder.AppendOrder(vehicle, depot, AIOrder.OF_NON_STOP_INTERMEDIATE );
			}
		}
	}
	
	function AppendDestToSrcOrder(vehicle) {
		if(HogeAI.Get().IsEnableVehicleBreakdowns()) {
			foreach(i,depot in depots) {
				AIOrder.AppendOrder(vehicle, depots[depots.len()-i-1], AIOrder.OF_NON_STOP_INTERMEDIATE );
			}
		}
	}
	
	function OnVehicleLost(vehicle) {
		HgLog.Warning("RoadRoute OnVehicleLost  "+this);
		local execMode = AIExecMode();
		//if(HogeAI.Get().IsInfrastructureMaintenance()) return; // ゴミ道路が収益を圧迫する
		if(isRemoved) return; // 道路の再作成は無駄
		
		/*if(lastRebuildDate != null && lastRebuildDate + 7 > AIDate.GetCurrentDate()) 複数個所で同時に来る事ある {
			//AppendRemoveOrder(vehicle);
			return;
		}*/
		lastRebuildDate = AIDate.GetCurrentDate();
		
		local roadBuilder = RoadBuilder();
		roadBuilder.engine = AIVehicle.GetEngineType(vehicle);
		
		local dest = AIOrder.GetOrderDestination(vehicle, AIOrder.ORDER_CURRENT);
		HgLog.Warning("BuildPath dest: "+HgTile(dest)+" src:"+HgTile(AIVehicle.GetLocation(vehicle))+" "+this);
		if(!roadBuilder.BuildPath([AIVehicle.GetLocation(vehicle)], [dest], true)) {
		//if(!roadBuilder.BuildPath(destHgStation.GetEntrances(), srcHgStation.GetEntrances(), true)) {
			HgLog.Warning("RoadRoute removed.(Rebuild road failed) "+this);
			Remove();
		} else {
			/*if(!BuildDepot(roadBuilder.path)) {
				HgLog.Warning("RoadRoute removed.(BuildDepot failed) "+this);
				Remove();
				UpdateSavedData();
				return;
			}*/
			//TODO: 故障有効モデルの途中depotへのorderだと壊れるかもしれない。orderの再構築も必要になるRoute.Removeでいいかも
			local isTram = IsTram();
			foreach(tile in usedTiles) {
				RoadRoute.RemoveUsedTile(tile, isTram);
			}
			//BuildDestDepot(roadBuilder.path);
			usedTiles = ArrayUtils.Or(usedTiles,roadBuilder.path.GetTiles());
			foreach(tile in usedTiles) {
				RoadRoute.AddUsedTile(tile,isTram);
			}
			HgLog.Warning("Rebuild road route succeeded");
		}
		UpdateSavedData();
	}

	function CreateDepotNear(location) {
		local execMode = AIExecMode();
		local oldRoadType = AIRoad.GetCurrentRoadType();
		AIRoad.SetCurrentRoadType(roadType);
		local result = RoadRoute.BuildDepotNear(location);
		AIRoad.SetCurrentRoadType(oldRoadType);	
		return result;
	}

	static function BuildDepotNear(location) {
		local nexts = AIList();
		nexts.Sort(AIList.SORT_BY_VALUE, true);
		local checked = {};
		nexts.AddItem(location, 0);
		
		while(nexts.Count() >= 1) {
			local cur = nexts.Begin();
			local distance = nexts.GetValue(cur);
			nexts.RemoveTop(1);
			if(distance >= 30) {
				continue;
			}
			local depot = RoadRoute.BuildDepotOn(cur);
			if(depot != null) {
				return depot;
			}
			checked.rawset(cur, true);
			foreach(d in HgTile.DIR4Index) {
				local next = cur + d;
				if(!checked.rawin(next)) {
					if(AIRoad.AreRoadTilesConnected(cur, next)) {
						nexts.AddItem(next, distance + 1);
					}
				}
			}
		}
		return null;
	}
	
	function BuildDepotOn(tile) {
		foreach(d in HgTile.DIR4Index) {
			local next = tile + d;
			if(HgTile.BuildRoadDepot(next,tile)) {
				return next;
			}
		}
		return null;
	}

	function Demolish() {
		local oldRoadType = AIRoad.GetCurrentRoadType();
		local execMode = AIExecMode();
		AIRoad.SetCurrentRoadType(roadType);
		_Demolish();
		AIRoad.SetCurrentRoadType(oldRoadType);
	}
	
	function _Demolish() {
		
		local isTram = IsTram();
		HgLog.Warning("Demolish RoadRoute:"+this+" isTram:"+isTram);

		local removableLines = [];
		local line = [];
		foreach(tile in usedTiles) {
			if(RoadRoute.RemoveUsedTile(tile,isTram) && (isTram || AICompany.IsMine(AITile.GetOwner(tile))) 
					/*&& !AITown.IsValidTown(AITile.GetTownAuthority(tile))*/) {
				line.push(tile);
			} else if(line.len() >= 1) {
				removableLines.push(line);
				line = [];
			}
		}
		if(line.len() >= 1) {
			removableLines.push(line);
		}
		RoadRoute.DemolishLines(removableLines, isTram);
		foreach(depot in depots) {
			if( AIVehicleList_Depot(depot).Count() == 0 ) {
				local front = AIRoad.GetRoadDepotFrontTile(depot)
				AIRoad.RemoveRoadDepot(depot);
				AIRoad.RemoveRoad(depot,front);
			}
		}
	}
	
	static function CheckPendingDemolishLines() {
		foreach(isTram in [true,false]) {
			local pendingLines = RoadRoute.GetPendingDemolishLines(isTram);
			local targetLines = clone pendingLines;
			pendingLines.clear();
			RoadRoute.DemolishLines(targetLines,isTram);
		}
	}
	
	static function DemolishLines(lines,isTram) {
		local execMode = AIExecMode();
		local old = AIRoad.GetCurrentRoadType();
		local roadTypes = AIRoadTypeList(isTram?AIRoad.ROADTRAMTYPES_TRAM:AIRoad.ROADTRAMTYPES_ROAD)
		if(roadTypes.Count() >= 1) {
			AIRoad.SetCurrentRoadType(roadTypes.Begin());
			RoadRoute._DemolishLines(lines,isTram);
			AIRoad.SetCurrentRoadType(old);
		}
	}

	static function _DemolishLines(lines,isTram) {
		if(lines.len() == 0) {
			return;
		}
		
		local pendingLines = RoadRoute.GetPendingDemolishLines(isTram);
		local vehicles = AIVehicleList();
		vehicles.Valuate(AIVehicle.GetVehicleType);
		vehicles.KeepValue(AIVehicle.VT_ROAD);
		vehicles.Valuate(function(v){return AIRoad.GetRoadTramType(AIVehicle.GetRoadType(v));});
		vehicles.KeepValue(isTram ? AIRoad.ROADTRAMTYPES_TRAM : AIRoad.ROADTRAMTYPES_ROAD);
		
		foreach(removeTiles in lines) {
			vehicles.Valuate(AIVehicle.GetLocation);
			local vehicleLocations = {};
			foreach(vehicle,location in vehicles) {
				vehicleLocations.rawset(location,true);
			}
			local skip = false;
			foreach(tile in removeTiles) {
				if(vehicleLocations.rawin(tile)) { // TODO 橋やトンネルにいた場合検知できない
					HgLog.Warning("Cannot remove road.(Found vehicle on road "+HgTile(tile)+")");
					skip = true;
					break;
				}
			}
			if(skip) {
				pendingLines.push(removeTiles);
				continue;
			}
			foreach(tile in removeTiles) {
				if(!isTram && !AICompany.IsMine(AITile.GetOwner(tile))) {
					HgLog.Info("Not own tile:"+HgTile(tile));
					continue;
				}
				if(RoadRoute.IsUsedTile(tile,isTram)) {
					HgLog.Info("UsedTile tile:"+HgTile(tile));
					continue; // 削除が遅延していケースで、削除が決まった後から別路線が作られるケースがある
				}
				if(!isTram && AIRoad.IsRoadStationTile(tile)) {
					HgLog.Info("RemoveRoadStation:"+HgTile(tile));
					if(!BuildUtils.RemoveRoadStationSafe(tile)) {
						HgLog.Warning("RemoveRoadStation failed:"+HgTile(tile)+" "+AIError.GetLastErrorString());
						pendingLines.push([tile]);
						continue;
					}
				}
				if(AIBridge.IsBridgeTile(tile)) {
					HgLog.Info("Remove Bridge:"+HgTile(tile));
					if(!BuildUtils.RemoveBridgeSafe(tile)) {
						HgLog.Warning("RemoveBridgeSafe failed:"+HgTile(tile)+" "+AIError.GetLastErrorString());
						pendingLines.push([tile]);
					}
				} else if(AITunnel.IsTunnelTile(tile)) {
					HgLog.Info("Remove Tunnel:"+HgTile(tile));
					if(!BuildUtils.RemoveTunnelSafe(tile)) {
						HgLog.Warning("RemoveTunnelSafe failed:"+HgTile(tile)+" "+AIError.GetLastErrorString());
						pendingLines.push([tile]);
					}
				} else if(AIRoad.IsRoadTile(tile)) {
					HgLog.Info("Demolish Road:"+HgTile(tile));
					RoadRoute.DemolishArroundDepot(tile);
					if(!RoadRoute.DemolishRoadTileSafe(tile)) { 
						HgLog.Warning("DemolishTile failed:"+HgTile(tile));
						pendingLines.push([tile]);
					}
					//AITile.DemolishTile(pre); 重なっている線路や軌道も破壊してしまう
					//AITile.DemolishTile(tile);
				} else {
					HgLog.Info("Unknown tile:"+HgTile(tile));
				}
			}
		}	
	}
	
	static function DemolishRoadTileSafe(tile) {
		local res = true;
		foreach(d in [1,AIMap.GetMapSizeX()]) {
			BuildUtils.RemoveRoadSafe(tile-d,tile+d);
		}
		foreach(d in HgTile.DIR4Index) {
			if(AIRoad.AreRoadTilesConnected(tile,tile + d)) {
				res = false;
			}
		}
		// RemoveRoadは坂道で残る事があるので
		/*トラムと道路が重なってるとどっちも消えてまずい
		if(AIRoad.IsRoadTile(tile) && !AIRail.IsRailTile(tile)) {
			if(!BuildUtils.DemolishTileSafe(tile)) {
				HgLog.Warning("DemolishTileSafe failed:"+HgTile(tile)+" "+AIError.GetLastErrorString());
				res = false;
			}
		}*/
		return res;
	}
	
	static function SellVehiclesInDepot(tile) {
		for(local i=0; i<10; i++) {
			local retry = false;
			local vehicles = AIVehicleList();			
			vehicles.Valuate(AIVehicle.GetLocation);
			vehicles.KeepValue(tile);
			HgLog.Info("SellVehiclesInDepot:"+vehicles.Count()+" "+HgTile(tile));	
			foreach(v,_ in vehicles) {
				local route = Route.GetRouteByVehicle(v);
				if(route == null) {
					HgLog.Warning("vehicle does not belong route.");
					return;
				}
				if(AIVehicle.IsStoppedInDepot(v)) {
					route.SellVehicle(v);
				} else if(AIVehicle.IsInDepot(v)) {
					AIVehicle.StartStopVehicle(v);
					route.SellVehicle(v);
				} else {
					route.AppendRemoveOrder(v);
					retry = true;
				}
			}	
			if(retry) {
				HogeAI.Get().WaitDays(1);
				continue;
			}
			return;
		}
		HgLog.Warning("SellVehiclesInDepot retry count exceeded."+HgTile(tile));	
	}

	static function DemolishArroundDepot(tile) {
		foreach(d in HgTile.DIR4Index) {
			local depotTile = tile + d;
			if(AIRoad.IsRoadDepotTile(depotTile) && AICompany.IsMine( AITile.GetOwner(depotTile) )
					&& AIRoad.AreRoadTilesConnected(depotTile, tile)) {
				RoadRoute.SellVehiclesInDepot(depotTile);
				if(!AITile.DemolishTile(depotTile)) {
					HgLog.Warning("Demolish RoadDepot failed:"+HgTile(depotTile)+" "+AIError.GetLastErrorString());
				} else {
					HgLog.Info("RoadDepot demolished:"+HgTile(depotTile));				
				}
			}
		}
	}

	
	
	static function GetRoadRoutes(roadType) {
		local result = [];
		foreach(route in RoadRoute.instances) {
			if(route.GetRoadType() == roadType) {
				result.push(route);
			}
		}
		return result;
	}
	
}

class RoadRouteBuilder extends CommonRouteBuilder {
	
	static function BuildRoadUntilFree(p1,p2) {
		return BuildUtils.WaitForMoney( function():(p1,p2) {
			return BuildUtils.RetryUntilFree( function():(p1,p2) {
				return AIRoad.BuildRoad(p1,p2);
			});
		});
	}
	
	constructor(dest, srcPlace, cargo, options = {}) {
		CommonRouteBuilder.constructor(dest, srcPlace, cargo, options);
		if(HogeAI.Get().IsInfrastructureMaintenance()) {
			//checkSharableStationFirst = true;
		}
		checkSharableStationFirst = true;
	}
	
	function GetRouteClass() {
		return RoadRoute;
	}
	
	function CreateStationFactory(target,engineSet) { 
		if(RoadRoute.IsTramCurrent()) {
			return RoadStationFactory(cargo,false,engineSet); // Tramは線路がpiecestationで終わっているとUターンできない
		} else {
			// TODO: 他経路を妨害する
			if(HogeAI.Get().roiBase && target instanceof TownCargo /*&& AITown.GetPopulation(target.town) < 1300*/ && !HogeAI.Get().IsDistantJoinStations()) {
				return RoadStationFactory(cargo,true,engineSet);
			}
			return PriorityStationFactory([RoadStationFactory(cargo,false,engineSet), RoadStationFactory(cargo,true/*isPieceStation*/,engineSet)]);
		}
		//return RoadStationFactory(cargo);
	}
	
	function CreatePathBuilder(engine, cargo) {
		local result = RoadBuilder(engine, cargo);
		/*
		if(src.GetName().find("Tarnington Forest")!=null) {
			result.debug = true;
		}*/
		return result;
	}
	
	//static
	function GetHasPowerRoadTypes(engine) {
		local result = [];
		foreach(roadType,v in AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD )) {
			if(AIEngine.HasPowerOnRoad(engine, roadType)) {
				result.push(roadType);
			}
		}
		foreach(roadType,v in AIRoadTypeList(AIRoad.ROADTRAMTYPES_TRAM )) {
			if(AIEngine.HasPowerOnRoad(engine, roadType)) {
				result.push(roadType);
			}
		}
		return result;
	}
	
	function GetSuitableRoadType(engineSet) {
		local maxSpeed = AIEngine.GetMaxSpeed(engineSet.engine);
		local roadTypes = GetHasPowerRoadTypes(engineSet.engine);
		if(roadTypes.len()==0) {
			HgLog.Warning("No haspower road type. engine:"+AIEngine.GetName(engineSet.engine)+" "+this);
			return AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD).Begin();
		}
		if(roadTypes.len()==1) {
			return roadTypes[0];
		}
		local list = AIList();
		foreach(roadType in roadTypes) {
			local roadSpeed = AIRoad.GetMaxSpeed(roadType) / 2;// The speed is in OpenTTD's internal speed unit. This is mph / 0.8, which is roughly 0.5 km/h. To get km/h multiply this number by 2.01168.
			//HgLog.Info("roadSpeed:"+roadSpeed+" roadType:"+AIRoad.GetName(roadType)+" maxSpeed:"+maxSpeed);
			list.AddItem(roadType, roadSpeed==0 ? maxSpeed : min(roadSpeed,maxSpeed) );
		}
		list.Sort(AIList.SORT_BY_VALUE,false);
		list.KeepValue(list.GetValue(list.Begin()));
		list.Valuate( AIRoad.GetBuildCost, AIRoad.BT_ROAD ); // TODO: 建築コストが異常に高いケースは速度を落すべき（見積時にroadtypeも決定する）
		list.Sort(AIList.SORT_BY_VALUE,true);
		return list.Begin();
	}
	
	function BuildStart(engineSet) {
		local roadType = engineSet.infrastractureType; //GetSuitableRoadType(engineSet);
		HgLog.Info("BuildStart RoadType:"+AIRoad.GetName(roadType)+" "+this);
		AIRoad.SetCurrentRoadType(roadType);
	}
}

class RoadBuilder {	
	path = null;
	cargo = null;
	engine = null;
	ignoreTiles = null;
	maxCost = null;
	costDrivethroughstation = null;
	retryCount = null;
	pathFindLimit = null;
	retry = null;
	
	debug = null;
	
	constructor(engine=null, cargo=null) {
		this.engine = engine;
		this.cargo = cargo;
		this.retryCount = 0;
		this.ignoreTiles = [];
		this.pathFindLimit = HogeAI.Get().IsInfrastructureMaintenance() ? 300 : (HogeAI.Get().roiBase ? 100 : 50);
		this.retry = false;
		this.debug = false;
	}

	function FindPath(starts, goals, suppressInterval, isRetry=false) {
		local pathfinder = RoadPathFinder();
		pathfinder.debug = debug;
		pathfinder.engine = engine;
		pathfinder._estimate_rate = 2;
		pathfinder._cost_level_crossing = 1000;
		pathfinder._cost_drivethroughstation = costDrivethroughstation == null ? 1000 : costDrivethroughstation;
		pathfinder._cost_demolish_tile = 1000;
		pathfinder._cost_coast = 50;
		pathfinder._cost_slope = 50;
		pathfinder._cost_turn = 50;
		if(HogeAI.Get().roiBase || HogeAI.Get().IsInfrastructureMaintenance()) {
			pathfinder._cost_bridge_per_tile = 100;
			pathfinder._cost_tunnel_per_tile = 100;
		} else {
			pathfinder._cost_bridge_per_tile = 10;
			pathfinder._cost_tunnel_per_tile = 10;
		}
		if(!HogeAI.Get().IsRich()) {
			pathfinder._max_tunnel_length = 6;
			pathfinder._max_bridge_length = 10;
		} else {
			pathfinder._max_tunnel_length = 50;
			pathfinder._max_bridge_length = 50; //20;
		}
		if(maxCost != null) {
			pathfinder._max_cost = maxCost;
		}
		/* if(IsConsiderSlope()) { 検索が遅すぎる
			pathfinder._cost_slope = 200;
			pathfinder._cost_no_existing_road = 100;
			pathfinder._cost_coast = 100;
			pathfinder._estimate_rate = 1;
			pathFindLimit = HogeAI.Get().roiBase ? 200 : 100;
		}*/
		local distance = AIMap.DistanceManhattan(starts[0],goals[0]);
		if(HogeAI.Get().IsInfrastructureMaintenance() || HogeAI.Get().IsPreferReusingExistingRoads()) {
//			pathfinder._cost_no_existing_road = 40; //distance < 150 ? 200 : 40 // 距離が長いと200は成功しない
			pathfinder._cost_tile = 50;
			pathfinder._cost_no_existing_road = 140;
			if((HogeAI.Get().IsInflation() || HogeAI.Get().IsPreferReusingExistingRoads()) && !isRetry) {
				retry = true;
				pathfinder._estimate_rate = 1; //距離が長いと成功しなくなる
				pathFindLimit = 300; // 既存路が利用できるときのみ成功するのはむしろ合理的。max(300, distance * distance / 30);
			}
		} else {
			pathfinder._cost_tile = 50;
			pathfinder._cost_no_existing_road = 140;
//			pathfinder._cost_tile = 100;
//			pathfinder._cost_no_existing_road = 40;
		}
		/*
		if(distance > 200) {
			pathFindLimit = 400; // 3年とかかかったあげく失敗するとかヤバい
		}*/
		
		pathfinder.InitializePath(starts, goals, ignoreTiles);
		
		
		HgLog.Info("RoadRoute Pathfinding...limit:"+pathFindLimit+" distance:"+distance);
		local counter = 0;
		local path = false;
		while (path == false && counter < pathFindLimit) {
			path = pathfinder.FindPath(100);
			counter++;
			if(!suppressInterval) {
				HogeAI.DoInterval();
			}
		}
		if (path != null && path != false) {
			HgLog.Info("RoadRoute Path found. (" + counter + ")");
		} else {
			path = null;
			HgLog.Warning("RoadRoute Pathfinding failed.");
		}
		return path;
	}


	function BuildPath(starts ,goals, suppressInterval=false) {
		retry = false;
		local path = FindPath(starts ,goals, suppressInterval);
		if(path == null && retry) {
			path = FindPath(starts ,goals, suppressInterval, true);
		}
		if(path == null) return false;
		
		this.path = path = Path.FromPath(path);
		local execMode = AIExecMode();
		local isTram = RoadRoute.IsTramCurrent();
		local currentRoadType = AIRoad.GetCurrentRoadType();
		local maxSpeed = AIRoad.GetMaxSpeed(currentRoadType);
		local par;
		for (;path != null; path = par) {
			par = path.GetParent();
			if (par != null) {
				local isBridgeOrTunnel = AIBridge.IsBridgeTile(path.GetTile()) || AITunnel.IsTunnelTile(path.GetTile());
				if(isBridgeOrTunnel) {
					local roadType = RoadRoute.GetTileRoadType(path.GetTile(),isTram );
					 if(roadType != null && AIRoad.RoadVehHasPowerOnRoad(AIRoad.GetCurrentRoadType(), roadType)) {
						local end = AIBridge.IsBridgeTile(path.GetTile())
							? AIBridge.GetOtherBridgeEnd(path.GetTile()) : AITunnel.GetOtherTunnelEnd(path.GetTile());
						if(end == par.GetTile()) {
							continue; // 既存橋トンネルの再利用
						} else {
							// 多分橋トンネルの出口。次の道路を作る
						}
					}
				}
				if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
					HogeAI.WaitForMoney(1000);
					local connected = AIRoad.AreRoadTilesConnected( path.GetTile(), par.GetTile() );
					if(connected) {
						local roadType = RoadRoute.GetTileRoadType(path.GetTile(),isTram );
						if(roadType != null) {
							local localMaxSpeed = AIRoad.GetMaxSpeed(roadType);
							if(localMaxSpeed != 0 && (localMaxSpeed < maxSpeed || maxSpeed == 0)) {
								if(!AIRoad.ConvertRoadType(path.GetTile(), par.GetTile() , AIRoad.GetCurrentRoadType() )) {
									HgLog.Warning("ConvertRoadType failed:"+HgTile(par.GetTile())+" ("+AIError.GetLastErrorString()+")");
								}
							}
						}
						continue;
					}
					local builtRoad =  RoadRouteBuilder.BuildRoadUntilFree(path.GetTile(), par.GetTile());
					local error = AIError.GetLastError();
					if(!builtRoad && error != AIError.ERR_ALREADY_BUILT ) {
						if(error == AIError.ERR_AREA_NOT_CLEAR) {
							if(AICompany.IsMine(AITile.GetOwner(par.GetTile()))) {
								HgLog.Warning("BuildRoud failed(AICompany.IsMine):"+HgTile(par.GetTile())+" ("+AIError.GetLastErrorString()+")");
								return RetryBuildRoad(path, starts);
							}
							HgLog.Warning("Attempt DemolishTile:"+HgTile(par.GetTile())+" (BuildRoud failed:"+AIError.GetLastErrorString()+")");
							HogeAI.WaitForMoney(2000);
							if( !AITile.DemolishTile(par.GetTile())) {
								HgLog.Warning("DemolishTile failed."+HgTile(par.GetTile())+AIError.GetLastErrorString());
							}
							builtRoad = RoadRouteBuilder.BuildRoadUntilFree(path.GetTile(), par.GetTile());
						}
						if(!builtRoad) {
							HgLog.Warning("BuildRoad failed."+HgTile(path.GetTile())+" "+HgTile(par.GetTile())+" "+AIError.GetLastErrorString());
							return RetryBuildRoad(path, starts);
						}
						
					}
				} else {
					if (!isBridgeOrTunnel && AIRoad.IsRoadTile(path.GetTile()) && !AITile.IsStationTile(path.GetTile())) {
						AITile.DemolishTile(path.GetTile());
					}
					if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
						HogeAI.WaitForMoney(50000);
						if (!BuildUtils.BuildTunnelSafe(AIVehicle.VT_ROAD, path.GetTile())) {
							HgLog.Warning("BuildTunnel(Road) failed."+HgTile(path.GetTile())+" "+HgTile(par.GetTile())+" "+AIError.GetLastErrorString());
							return RetryBuildRoad(path, starts);
						}
					} else {
						local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
						bridge_list.Valuate(AIBridge.GetMaxSpeed);
						bridge_list.Sort(AIList.SORT_BY_VALUE, false);
						if (!BuildUtils.BuildBridgeSafe(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
							HgLog.Warning("BuildBridge(Road) failed."+HgTile(path.GetTile())+" "+HgTile(par.GetTile())+" "+AIError.GetLastErrorString());
							return RetryBuildRoad(path, starts);
						}
					}
				}
			}
		}
		HgLog.Info("BuildRoad Pathfinding succeeded");
		return true;
	}
	
	function RetryBuildRoad(curPath, goals) {
		if(retryCount >= 4) {
			HgLog.Warning("RetryBuildRoad retry count reach limit.");
			return false;
		}
		HgLog.Warning("RetryBuildRoad retryCount:"+retryCount);
		local startPath = this.path.SubPathEnd(curPath.GetTile());
		if(startPath == null) {
			HgLog.Warning("No start tiles("+curPath.GetTile()+")");
			return false;
		}
		local roadBuilder = RoadBuilder(engine,cargo);
		roadBuilder.ignoreTiles.extend(ignoreTiles);
		roadBuilder.ignoreTiles.push(curPath.GetTile());// 高すぎて失敗した可能性があるため、繰り返さないようにする => 失敗したという事はPathFinderのバグの可能性あり。その場合無限ループする
		roadBuilder.retryCount = retryCount + 1;
		local result = roadBuilder.BuildPath( startPath.GetTiles(), goals );
		if(result) {
			local newPath = roadBuilder.path.Reverse();
			this.path = this.path.CombineTo(newPath.GetTile(),newPath);
		} else {
			RoadRoute.DemolishLines([startPath.GetTiles()], RoadRoute.IsTramCurrent());
		}
		return result;
	}
	
	
	function IsConsiderSlope() {
		if(engine == null || cargo == null) {
			return false;
		}
		if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 100000 && Route.GetAllRoutes().len()>=1) {
			return false;
		}
		local speed = AIEngine.GetMaxSpeed(engine);
		if(speed == 0) {
			HgLog.Warning("IsConsiderSlope speed == 0 "+AIEngine.GetName(engine));
		}
		local weight = VehicleUtils.GetCargoWeight(cargo, AIEngine.GetCapacity(engine));
		return VehicleUtils.GetForce(AIEngine.GetMaxTractiveEffort(engine), AIEngine.GetPower(engine), AIEngine.GetMaxSpeed(engine)/2) 
			- VehicleUtils.GetRoadSlopeForce(weight) < 0;
	}
	
}

class TownBus {
	
	static instances = [];
	static savedDatas = [];
	static townMap = {};
	static canUseCargo = {};
	static busPrice = {};
	static engineCache = ExpirationTable(3*365);
	static ngTileList = AITileList();
	
	static function SaveStatics(data) {
		/*local array = [];
		foreach(townBus in TownBus.instances) {
			array.push(townBus.saveData);
		}*/
		data.townBus <- TownBus.savedDatas;
	}
	
	static function LoadStatics(data) {
		TownBus.instances.clear();
		foreach(t in data.townBus) {
			local townBus = TownBus(t.town, t.cargo);
			townBus.stations = t.stations;
			townBus.depot = t.depot;
			townBus.isTransfer = t.isTransfer;
			townBus.townBus = t.rawin("townBus") ? t.townBus : null;
			townBus.removeBus = t.removeBus;
			townBus.date = t.rawin("date") ? t.date : AIDate.GetCurrentDate();
			townBus.saveData = t;
			TownBus.savedDatas.push(t);
			TownBus.instances.push(townBus);
		}
	}

	
	static function CanUse(cargo = null) {
		if(HogeAI.Get().IsDisableRoad()) { // Tramのtownbusは今のところ未対応
			return false;
		}
		if(HogeAI.Get().IsInflation()) {
			return false; // インフレ時はtownbusのメンテコストが払えない
		}
		if(cargo==null) {
			cargo = HogeAI.GetPassengerCargo();
		}
		if(!CargoUtils.IsPaxOrMail(cargo)) {
			return false;
		}
		if(TownBus.canUseCargo.rawin(cargo)) {
			return TownBus.canUseCargo[cargo];
		}
		local engine = TownBus.GetStandardBusEngine(cargo);
		local result = engine != null && !RoadRoute.IsTooManyVehiclesForSupportRoute(RoadRoute);
		if(engine != null) {
			TownBus.busPrice.rawset(cargo, AIEngine.GetPrice(engine));
		}
		TownBus.canUseCargo.rawset(cargo, result);
		return result;
	}

	static function Exists(town,cargo) {
		return TownBus.townMap.rawin(town+":"+cargo);
	}

	static function Check(tile, ignoreTileList=null, cargo = null, forTransferRoute = null) {
		local authorityTown = AITile.GetTownAuthority (tile);
		if(!AITown.IsValidTown(authorityTown)) {
			return;
		}
		TownBus.CheckTown(authorityTown, ignoreTileList, cargo, forTransferRoute);
	}
	
	
	static function IsReadyEconomy() {
		return HogeAI.Get().IsRich() || (HogeAI.Get().GetUsableMoney() >= HogeAI.Get().GetInflatedMoney(200000) && HogeAI.Get().HasIncome(50000));
	}
	
	static function CheckTown(authorityTown, ignoreTileList=null, cargo = null, forTransferRoute = null) {
		//HgLog.Info("CheckTown:"+AITown.GetName(authorityTown));
		if(cargo == null || !AICargo.HasCargoClass(cargo, AICargo.CC_MAIL)) {
			cargo = HogeAI.GetPassengerCargo();
		}		
		local key = authorityTown+":"+cargo;
		if(TownBus.townMap.rawin(key)) {
			return TownBus.townMap[key].CheckRetry(authorityTown, ignoreTileList, cargo);
		}
		if(!TownBus.CanUse(cargo)) { // バスの無い世界線
			return null;
		}
		if(forTransferRoute != null) {
			local needs = false;
			if(HogeAI.Get().IsDistantJoinStations() && !HogeAI.Get().IsAvoidExtendCoverageAreaInTowns()) {
				if(forTransferRoute.GetVehicleType() == AIVehicle.VT_ROAD) {
					return null;
				}
				if(AITown.GetPopulation(authorityTown) > 3000){
					needs = true;
				}
			} else {
				if(AITown.GetPopulation(authorityTown) > 1300){
					needs = true;
				}
			}
			if(!TownCargo.CanGrowthTown(authorityTown) && !needs) {
				return null;
			}
		} else if(HgStation.townUsed.rawin(authorityTown)) {
			return null;
		}
		if( !TownBus.IsReadyEconomy() ) {
			return null;
		} 
	
	
		if(AIGroup.GetNumVehicles( AIGroup.GROUP_ALL, AIVehicle.VT_ROAD) >= RoadRoute.GetMaxTotalVehicles()) {
			return null;
		}
		local aiExec = AIExecMode();
		local townBus = TownBus(authorityTown, cargo);
		TownBus.instances.push(townBus);
		TownBus.savedDatas.push(townBus.saveData);
		if(!townBus.BuildBusStops()) {
			return null;
		}
		return townBus;
	}
		
	static function GetStandardBusEngine(cargo) {
		if(TownBus.engineCache.rawin("engine")) {
			return TownBus.engineCache.rawget("engine");
		}
		local engineSet = RoadRoute.EstimateEngineSet( RoadRoute, cargo, 100, 50, true, null, true );
		if(engineSet != null) {
			TownBus.engineCache.rawset("engine",engineSet.engine);
			return engineSet.engine;
		} else {
			TownBus.engineCache.rawset("engine",null);
			return null;
		}
	}

	town = null;
	cargo = null;
	stations = null;
	depot = null;
	isTransfer = null;
	townBus = null;
	removeBus = null;
	date = null;
	
	saveData = null;
	
	constructor(town, cargo) {
		this.town = town;
		this.cargo = cargo;
		this.stations = [];
		this.isTransfer = false;
		this.date = AIDate.GetCurrentDate();
		TownBus.townMap[town+":"+cargo] <- this;
		saveData = {
			town = null
			cargo = null
			stations = null
			depot = null
			isTransfer = null
			townBus = null
			removeBus = null
			date = null
		}
		Save();
	}
	
	function Save() {
		saveData.town = town;
		saveData.cargo = cargo;
		saveData.stations = stations;
		saveData.depot = depot;
		saveData.isTransfer = isTransfer;
		saveData.townBus = townBus;
		saveData.removeBus = removeBus;
		saveData.date = date;
	}
	
	function CheckRetry(authorityTown, ignoreTileList, cargo) {
		if(AIDate.GetCurrentDate() > date + 365 && (stations.len() < 2 || depot == null)) {
			TownBus.townMap.rawdelete(authorityTown+":"+cargo);
			return TownBus.CheckTown(authorityTown, ignoreTileList, cargo); // TODO: TownBus.instancesが増殖する
		} else {
			return this;
		}
	}
	
	function BuildBus() {
		if(!depot) {
			return false;
		}
		local notUsedStations = GetNotUsedStations();
		if(notUsedStations.len() < 2) {
			return false;
		}
		if(townBus != null) {
			HgLog.Warning("BuildBus failed(townbus exits)"+this);
			return false;
		}
		local busEngine = ChooseBusEngine();
		if(busEngine == null) {
			HgLog.Warning("Not found bus engine "+this);
			return false;
		}
		HogeAI.WaitForPrice(AIEngine.GetPrice(busEngine));
		local bus = AIVehicle.BuildVehicle(depot, busEngine);
		if(!AIVehicle.IsValidVehicle(bus)) {
			HgLog.Warning("BuildBus failed depot:"+HgTile(depot)+" "+AIError.GetLastErrorString()+" "+this);
			return false;
		}
		AIVehicle.RefitVehicle(bus, cargo);
		if(AICargo.HasCargoClass(cargo, AICargo.CC_MAIL)) {
			AIVehicle.SetName(bus, "MailVan#"+AIVehicle.GetUnitNumber(bus));
		} else {
			AIVehicle.SetName(bus, "TownBus#"+AIVehicle.GetUnitNumber(bus));
		}
		RebuildOrder(bus, notUsedStations);
		AIVehicle.StartStopVehicle(bus);
		townBus = bus;
		Save();
		return true;
	}
	
	function RebuildOrder(bus,notUsedStations) {
		while(AIOrder.GetOrderCount(bus) >= 1) {
			AIOrder.RemoveOrder(bus, 0);
		}
		if(HogeAI.Get().IsEnableVehicleBreakdowns()) {
			AIOrder.AppendOrder(bus, depot, AIOrder.OF_SERVICE_IF_NEEDED | AIOrder.OF_NON_STOP_INTERMEDIATE );
		}
		foreach(station in notUsedStations) {
			AIOrder.AppendOrder(bus, station, AIOrder.OF_NON_STOP_INTERMEDIATE);
		}
	}
	
	function GetNotUsedStations() {
		local result = [];
		foreach(station in stations) {
			if(!IsUsedStationTransfer(station)) {
				result.push(station);
			}
		}
		return result;
	}
	
	function GetOrderStations(bus) {
		local result = [];
		local orderCount = AIOrder.GetOrderCount(bus);
		for(local index = HogeAI.Get().IsEnableVehicleBreakdowns() ? 1 : 0; index < orderCount; index++) {
			result.push(AIOrder.GetOrderDestination(bus, index));
		}
		return result;
	}

	function IsUsedStationTransfer(stationTile) {
		local vehicleList = AIVehicleList_Station( AIStation.GetStationID(stationTile) );
/*		vehicleList.Valuate( AIVehicle.IsStoppedInDepot );
		vehicleList.RemoveValue(1);*/
		if(townBus != null) {
			vehicleList.RemoveItem(townBus);
		}
		return vehicleList.Count() >= 1;
	}

	function GetBus() {
		return townBus;
	}
	
	function ChooseBusEngine() {
		local engineSet = RoadRoute.EstimateEngineSet(RoadRoute, cargo, 
				max(10,AIMap.DistanceManhattan(stations[0],stations[1])),
				max(50,GetPlace().GetLastMonthProduction(cargo)/2), 
				true, null, true );
		return engineSet != null ? engineSet.engine : null;
	}
	
	function BuildBusStops() {
		local currentRoadType = AIRoad.GetCurrentRoadType();
		AIRoad.SetCurrentRoadType(GetRoadType()); // TODO tram対応
		local result = _BuildBusStops();
		AIRoad.SetCurrentRoadType(currentRoadType);
		return result;
	}
	
	function _BuildBusStops() {
	
		local aiTest = AITestMode();
		local pair = FindFirstStations(AITown.GetLocation(town));
		if(pair == null || pair[0][0] == pair[1][0]) {
			HgLog.Warning("Not found suitable bus stop tile."+this);
			return false;
		}
		
		local stationA = pair[0];
		local stationB = pair[1];
		
		local aiExec = AIExecMode();
		HogeAI.WaitForMoney(10000);
		local roadVehType = AICargo.HasCargoClass (cargo, AICargo.CC_PASSENGERS) ? AIRoad.ROADVEHTYPE_BUS : AIRoad.ROADVEHTYPE_TRUCK;
		if(!BuildUtils.RetryUntilFree(function():(stationA,roadVehType) {
			return AIRoad.BuildDriveThroughRoadStation(stationA[0], stationA[1], roadVehType , AIStation.STATION_NEW);
		})) {
			HgLog.Warning("failed BuildDriveThroughRoadStation"+HgTile(stationA[0])+" "+AIError.GetLastErrorString()+" "+this);
			return false;
		}
		
		SetStationName(stationA[0]);
		stations.push(stationA[0]);
		
		if(!BuildUtils.RetryUntilFree(function():(stationB,roadVehType) {
			return AIRoad.BuildDriveThroughRoadStation(stationB[0], stationB[1], roadVehType , AIStation.STATION_NEW);
		})) {
			HgLog.Warning("failed BuildDriveThroughRoadStation"+HgTile(stationB[0])+" "+AIError.GetLastErrorString()+" "+this);
			return false;
		}
		/* depot作成時にやる
		if(!MakeRouteToDepot(stationA[0]) || !MakeRouteToDepot(stationB[0])) {
			return false;
		}*/

		SetStationName(stationB[0]);
		stations.push(stationB[0]);
		HgLog.Info("BuildBusStops succeeded."+this);
		RoadRoute.AddUsedTile(stationA[0]);
		RoadRoute.AddUsedTile(stationB[0]);
		Save();
		return true;
	}
	
	function MakeRouteToDepot(station) {
		local busEngine = TownBus.GetStandardBusEngine(cargo);
		if(busEngine == null) {
			HgLog.Warning("failed MakeRouteToDepot busEngine == null "+this);
			return false;
		}
		local depot = GetDepot();
		if(!depot) {
			HgLog.Warning("failed MakeRouteToDepot (No depot) "+this);
			return false;
		}
		local roadBuilder = RoadBuilder(busEngine);
		if(!roadBuilder.BuildPath([station], [depot], true)) {
		HgLog.Warning("failed MakeRouteToDepot "+HgTile(depot)+" station:"+HgTile(station)+" "+this);
			return false;
		}
		RoadRoute.AddUsedTile(station);
		RoadRoute.AddUsedTile(depot);
		SetUsedTiles(roadBuilder.path);
		return true;
	}
	
	function SetUsedTiles(path) {
		while(path != null) {
			RoadRoute.AddUsedTile(path.GetTile());
			path = path.GetParent();
		}
	}

	function SetStationName(tile) {
		if(HogeAI.Get().IsDisabledPrefixedStatoinName()) {
			return;
		}
		local station = AIStation.GetStationID(tile);
		AIStation.SetName(station, StringUtils.SliceMaxLen("."+AIBaseStation.GetName(station),31));
	}
	
	function BuildBusDepot() {
		if(cargo != HogeAI.GetPassengerCargo()) {
			local key = town+":"+HogeAI.GetPassengerCargo();
			if(TownBus.townMap.rawin(key)) {
				depot = TownBus.townMap[key].depot;
				if(depot != null) {
					return depot;
				}
			}
		}
		HogeAI.WaitForMoney(10000);
		local execMode = AIExecMode();
		local currentRoadType = AIRoad.GetCurrentRoadType();
		AIRoad.SetCurrentRoadType(GetRoadType()); // TODO tram対応
		depot = RoadRoute.BuildDepotNear(AITown.GetLocation(town));
		AIRoad.SetCurrentRoadType(currentRoadType);
		Save();
		return depot != null;
	}

	
	function FindFirstStations(center) {
		local rect = Rectangle.Center(HgTile(center),6);
		local tileList = AITileList();
		tileList.AddRectangle(rect.lefttop.tile, rect.rightbottom.tile);
		tileList.Valuate(function(t):(center) {
			return abs(AIMap.DistanceManhattan(t,center)-3);
		});
		tileList.Sort(AIList.SORT_BY_VALUE,true);
		local s0 = FindStationTile(tileList);
		if(s0 == null) {
			return null;
		}
		local s0tile = s0[0];
		tileList.Valuate(function(t):(tileList,s0tile) {
			return tileList.GetValue(t) + max(7 - AIMap.DistanceMax(t,s0tile),0);
		});
		tileList.Sort(AIList.SORT_BY_VALUE,true);
		local s1 = FindStationTile(tileList);
		if(s1 == null) {
			return null;
		}
		return [s0,s1];
	}
	
	function FindStationTile(tileList,ownerCheck=true) {
		local dirs = [AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(0, 1)];
		local radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
		foreach(tile,_ in tileList) {
			if(!AIRoad.IsRoadTile (tile) || AITile.GetCargoAcceptance(tile,cargo, 1, 1, radius) <= 8 
					|| (ownerCheck && AITile.GetOwner(tile) != AICompany.COMPANY_INVALID)
					|| TownBus.ngTileList.HasItem(tile)
					|| RoadRoute.IsUsedTile(tile)) {
				continue;
			}
			foreach(dir in dirs) {
				if(AIRoad.BuildDriveThroughRoadStation (tile, tile + dir, AIRoad.ROADVEHTYPE_BUS , AIStation.STATION_NEW)) {
					return [tile,tile+dir];
				}
			}
		}
		if(ownerCheck) {
			return FindStationTile(tileList,false);
		}
		return null;
	}
	
	function GetHgStation(platformTile) {
		foreach(station in GetPlace().GetStations()) {
			if(station.platformTile == platformTile) {
				return station;
			}
		}
		return null;
	}
	
	function CreateTransferRoadRoute(number, srcStationTile, toHgStation, destRoute, path) {
		local execMode = AIExecMode();
	
		local depot = GetDepot();
		if(!depot) {
			HgLog.Warning("No depot(TownBus.CreateTransferRoadRoute)"+this);
			return false;
		}
		local srcHgStation = GetHgStation(srcStationTile);
		if(srcHgStation == null) {
			srcHgStation = PieceStation(srcStationTile);
			srcHgStation.name = CreateNewBusStopName(number);
			srcHgStation.place = GetPlace();
			srcHgStation.cargo = cargo;
			srcHgStation.builded = true;
			srcHgStation.BuildExec();
		}
		local roadRoute = RoadRoute();
		roadRoute.cargo = cargo;
		roadRoute.srcHgStation = srcHgStation;
		roadRoute.destHgStation = toHgStation;
		roadRoute.isTransfer = true;
		roadRoute.isBiDirectional = false;
		roadRoute.destRoute = destRoute;
		roadRoute.depot = depot;
		roadRoute.useDepotOrder = false;
		roadRoute.useServiceOrder = true;
		roadRoute.Initialize();
		roadRoute.SetPath(path);
		if(toHgStation instanceof RoadStation && roadRoute.BuildDestDepot(path)) {
			roadRoute.useServiceOrder = false;
		}
		local vehicle = roadRoute.BuildVehicleFirst();
		if(vehicle==null) {
			HgLog.Warning("BuildVehicle failed.(TownBus.CreateTransferRoadRoute)"+this);
			return false;
		}
		roadRoute.UpdateSavedData();
		RoadRoute.instances.push(roadRoute);
		PlaceDictionary.Get().AddRoute(roadRoute);
		HgLog.Info("TownBus.CreateTransferRoadRoute succeeded."+this);
		return true;
	}
	
	function CreateNewBusStopName(number) {
		local name = AITown.GetName(town);
		if(AICargo.HasCargoClass(cargo, AICargo.CC_MAIL)) {
			return StringUtils.SliceMaxLen(name,31-4) + " #M" + number;
		} else {
			return StringUtils.SliceMaxLen(name,31-3) + " #" + number;
		}
	}
	
	
	function GetDepot() {
		if(depot == null) {
			if(!BuildBusDepot()) {
				depot = false;
				Save();
			}
		}
		return depot;
	}
	
	function CheckInterval() {
		if(removeBus != null) {
			if(AIVehicle.IsStoppedInDepot(removeBus)) {
				AIVehicle.SellVehicle(removeBus);
				removeBus = null;
				Save();
			}
		}
		if(stations.len()<2 || depot == false) {
			return;
		}
		if(depot == null) {
			if(GetDepot() != false) {
				if(!BuildBus()) {
					return;
				}
			} else {
				return;
			}
		}
		CheckTransfer();
		
		if(!isTransfer && AIBase.RandRange(100) < 5 && HogeAI.Get().IsRich()) {
			CheckRenewal();
		}
	}

	function CheckTransfer() {
		
		if(isTransfer) { // 重い可能性がある。
			local bus = GetBus();
			local notUsedStations = GetNotUsedStations();
			local s1 = "";
			foreach(station in notUsedStations) {
				s1 += station + ",";
			}
			local s2 = "";
			if(bus != null) {
				foreach(station in GetOrderStations(bus)) {
					s2 += station + ",";
				}
			}
			if(s1 != s2) {
				local aiExec = AIExecMode();
				if(notUsedStations.len() >= 2) {
					if(bus == null) {
						BuildBus();
					} else {
						RebuildOrder(bus, notUsedStations);
					}
				} else if(bus != null) {
					RemoveBus();
				}
			}
		} else {
			if(townBus == null) {
				BuildBus();
			}
		}
	}
	
	function RemoveBus() {
		if(townBus == null) {
			return;
		}
		if(removeBus != null) {
			HgLog.Warning("RemoveBus failed.removeBus != null "+this); // 前のバスが残ってる？
			return;
		}
		if((AIOrder.OF_STOP_IN_DEPOT & AIOrder.GetOrderFlags(townBus, AIOrder.ORDER_CURRENT)) == 0) {
			AIVehicle.SendVehicleToDepot(townBus);
		}
		removeBus = townBus;
		townBus = null;
		Save();
	}

	function CheckRenewal() {
		local bus = GetBus();
		if(bus == null || removeBus != null) {
			return;
		}
		local aiExec = AIExecMode();
		local engine = ChooseBusEngine();
		if(engine != AIVehicle.GetEngineType(bus) || (HogeAI.Get().IsEnableVehicleBreakdowns() && AIVehicle.GetAgeLeft(bus) <= 600)) {
			RemoveBus();
			BuildBus(); //too many vehiclesの時にtownbusがいなくなる
		}
	}
	
	function GetPlace() {
		return TownCargo(town, cargo, true);
	}
	
	function CreateTransferRoutes(route, placeStation) {
		HogeAI.Get().supressInterval = true; // TownBus.CheckIntervalとの競合を防ぐ
		local currentRoadType = AIRoad.GetCurrentRoadType();
		AIRoad.SetCurrentRoadType(GetRoadType());
		
		_CreateTransferRoutes(route, placeStation);
		
		AIRoad.SetCurrentRoadType(currentRoadType);
		HogeAI.Get().supressInterval = false;
	}
	
	function _CreateTransferRoutes(route, placeStation) {
		if(stations.len() < 2 || !GetDepot()) {
			return;
		}
		if(HogeAI.Get().CanExtendCoverageAreaInTowns()) {
			for(local i=0; i<stations.len(); i++) {
				local hgStation = GetHgStation(stations[i]);
				if(hgStation == null) continue;
				hgStation.BuildSpreadPieceStations();
			}
		}
		
		
		for(local i=0; i<stations.len(); i++) {
			local hgStation = GetHgStation(stations[i]);
			if(hgStation != null) {
				local exists = false;
				foreach(checkRoute in hgStation.GetUsingRoutes()) {
					if(checkRoute.destHgStation.stationGroup == placeStation.stationGroup) {
						exists = true;
						break;
					}
				}
				if(exists) {
					continue;
				}
			}
				
			local toHgStation = null;
			local toHgSubStation = null;
			local placeStationCanBeTransfer = false;
			foreach(station in placeStation.stationGroup.hgStations) {
				if((station instanceof PieceStation || station instanceof RoadStation) && station.cargo == cargo) {
					if(AIRoad.HasRoadType(station.platformTile, GetRoadType())) {
						if(station == placeStation) {
							placeStationCanBeTransfer = true;
						} else {
							toHgSubStation = station;
							if(station.CanShareByMultiRoute(GetRoadType(),cargo)) {
								toHgStation = station;
								break;
							}
						}
					}
				}
			}
			if(toHgStation == null) {
				toHgStation = RoadStationFactory(cargo).CreateBest( placeStation.stationGroup, cargo, GetPlace().GetLocation() );
				if(toHgStation == null && !placeStationCanBeTransfer/*road stationに無理にpiace stationをくっつけない*/) {
					toHgStation = RoadStationFactory(cargo,true/*piaceStation*/).CreateBest(
							placeStation.stationGroup, cargo, GetPlace().GetLocation() );
				}
				
				local execMode = AIExecMode();
				if(toHgStation == null || !toHgStation.BuildExec()) {
					if(placeStationCanBeTransfer) {
						toHgStation = placeStation;
					} else if(toHgSubStation != null) {
						toHgStation = toHgSubStation;
					} else {
						HgLog.Warning("Not found town transfer station for "+placeStation+" "+this);
						return;
					}
				}
			}
			local busEngine = TownBus.GetStandardBusEngine(cargo); /*Road typeの識別で使う*/
			if(busEngine == null) {
				HgLog.Warning("Cannot detect road type(Not found bus engine)"+this);
				return;
			}
			if(CanBuildNewBusStop()) { // 探索に時間がかかるので5つまでにする。沢山あっても渋滞しだす
				// TODO: joinできるのならjoinした方が有利
				local busStop = FindNewBusStop(HogeAI.GetPassengerCargo() == cargo ? 60 : 30, placeStation);
				if(busStop != null) {
					busStop.name = CreateNewBusStopName(stations.len()+1);
					local execMode = AIExecMode();
					if(!busStop.BuildExec() || !MakeRouteToDepot(busStop.platformTile)) {
						HgLog.Warning("Create new busstop failed."+busStop+" "+this+" "+AIError.GetLastErrorString());
					} else {
						stations.push(busStop.platformTile);
					}
				}
			}
			
			
			if(Place.IsNgPathFindPair(stations[i],toHgStation.platformTile, AIVehicle.VT_ROAD)) {
				continue;
			}
			HgLog.Info("CreateTransfer:"+this+" (used route:"+route+")");
			local roadBuilder = CreateRoadBuilder(busEngine);
			if(roadBuilder.BuildPath([toHgStation.platformTile], [stations[i]], true)) {
				CreateTransferRoadRoute(1+i, stations[i], toHgStation, route, roadBuilder.path);
			} else {
				if(AITown.GetRating(town, AICompany.COMPANY_SELF) <= 3) {
					Place.AddNgPathFindPair(stations[i],toHgStation.platformTile,AIVehicle.VT_ROAD,365);
				} else {
					Place.AddNgPathFindPair(stations[i],toHgStation.platformTile,AIVehicle.VT_ROAD);
				}
			}
		}
		isTransfer = true;
		Save();
	}
	
	function IsNgStation(platformTile) {
		foreach(station in stations) {
			if(Place.IsNgPathFindPair(station, platformTile, AIVehicle.VT_ROAD)) {
				return true;
			}	
		}
		return false;
	}
	
	function CreateRoadBuilder(busEngine) {
		local result = RoadBuilder(busEngine);
		//result.maxCost = 5000; // 50tile以内 実際に届かない場合、limit限界まで探索し続けるので遅い
		result.costDrivethroughstation = 0;
		result.pathFindLimit = 30;
		return result;
	}
	
	function CanBuildNewBusStop() {
		local poplulationMultiplier = 1.0;
		if(HogeAI.Get().CanExtendCoverageAreaInTowns()) {
			poplulationMultiplier = HogeAI.Get().maxStationSpread.tofloat() / 6;
			if(poplulationMultiplier < 1.0) poplulationMultiplier = 1.0;
		}
		local population = (AITown.GetPopulation(town) / poplulationMultiplier).tointeger();
		local numStation = stations.len();
		if(population < 6000) {
			return false;
		}
		if(population < 9000 && numStation >= 3) {
			return false;
		}
		if(population < 17000 && numStation >= 4) {
			return false;
		}
		if(population < 26000 && numStation >= 5) {
			return false;
		}
		if(population < 37000 && numStation >= 6) {
			return false;
		}
		if(numStation >= 7) {
			return false;
		}
		return true;
	}
	
	//static
	function GetRoadType() {
		return HogeAI.Get().townRoadType;
		//return AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD).Begin();	
	}
	
	function CheckTownRoadType() {
		local town = AITownList().Begin();
		local tile = AITown.GetLocation(town);
		foreach(roadType,_ in AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD )) {
			if(AIRoad.ConvertRoadType(tile,tile,roadType)) {
				return roadType;
			}
			if(AIError.GetLastError() == AIRoad.ERR_UNSUITABLE_ROAD) {
				return roadType;
			}
		}
		HgLog.Warning("Unknown town roadType");
		return AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD ).Begin();
	}
	
	function CanUseTownBus() {
		return RoadRoute.EstimateEngineSet(RoadRoute, HogeAI.GetPassengerCargo(), 10,  50, true, null, true ) != null;
	}
	
	
	function FindNewBusStop(acceptanceThreshold,placeStation) {
		local testMode = AITestMode();
		local roadRadius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
		local stationTileMap = {};
		local place = GetPlace();
		foreach(s in this.stations) {
			stationTileMap.rawset(s,0);
		}
		local stations = clone place.GetStations();
		stations.push(placeStation);
		foreach(station in stations) {
			if(AIStation.HasCargoRating(station.stationId,cargo) || station == placeStation/*出来立てでRating無い*/) {
				foreach(t in station.GetPlatformRectangle().GetCorners()) {
					stationTileMap.rawset(t.tile,0);
				}
			}
		}
		local stationTiles = [];
		foreach(t,_ in stationTileMap) {
			stationTiles.push(t);
		}
		
		local rectangle = place.GetRectangle();
		local tileList = AITileList();
		tileList.AddRectangle(rectangle.lefttop.tile, rectangle.rightbottom.tile);
		tileList.Valuate(AIRoad.IsRoadTile);
		tileList.KeepValue(1);
		tileList.Valuate(AIMap.DistanceManhattan, rectangle.GetCenter().tile);
		tileList.Sort( AIList.SORT_BY_VALUE, true );
		foreach(tile,_ in tileList) {
			local ok = true;
			foreach(s in stationTiles) {
				if(AIMap.DistanceMax(tile,s) < 7) {
					ok = false;
					break;
				}
			}
			if(ok && AITile.GetCargoAcceptance(tile, cargo, 1, 1, roadRadius) >= acceptanceThreshold) {
				local station = PieceStation(tile);
				station.cargo = cargo;
				station.place = place;
				if(station.Build(true,true)) {
					return station;
				}
			}
		}
		return null;
	}

	function _tostring() {
		return "TownBus["+AITown.GetName(town)+":"+AICargo.GetName(cargo)+"]";
	}
}



