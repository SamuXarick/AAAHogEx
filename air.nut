﻿
class Air {
	static instance_ = GeneratorContainer(function() { 
		return Air(); 
	});
	static function Get() {
		return Air.instance_.Get();
	}

	static airportTraits = [
		{
			level = 1
			airportType = AIAirport.AT_SMALL
			supportBigPlane = false
			population = 800
			terminals = 2
			runways = 1
			stationDateSpan = 20
			cost = 5500
			maintenanceCost = 59000
		},{
			level = 2
			airportType = AIAirport.AT_COMMUTER
			supportBigPlane = false
			population = 1000
			terminals = 3
			runways = 1
			stationDateSpan = 16
			cost = 10000
			maintenanceCost = 169000
		},{
			level = 3
			airportType = AIAirport.AT_LARGE
			supportBigPlane = true
			population = 2000
			terminals = 3
			runways = 1
			stationDateSpan = 10
			cost = 16000
			maintenanceCost = 202000
		},{
			level = 4
			airportType = AIAirport.AT_METROPOLITAN
			supportBigPlane = true
			population = 4000
			terminals = 3
			runways = 2
			stationDateSpan = 8
			cost = 17000
			maintenanceCost = 236000
		},{
			level = 5
			airportType = AIAirport.AT_INTERNATIONAL
			supportBigPlane = true
			population = 10000
			terminals = 6			
			runways = 2
			stationDateSpan = 5
			cost = 22000
			maintenanceCost = 354000
		},{
			level = 6
			airportType = AIAirport.AT_INTERCON
			supportBigPlane = true
			population = 20000
			terminals = 8
			runways = 4
			stationDateSpan = 4
			cost = 46000
			maintenanceCost = 607000
		}
	];
	static allAirportTypes = [
		AIAirport.AT_SMALL, AIAirport.AT_COMMUTER, AIAirport.AT_LARGE, AIAirport.AT_METROPOLITAN, AIAirport.AT_INTERNATIONAL, AIAirport.AT_INTERCON
	];
	
	type2Traits = null;
	totalMaintenanceCosts = null;
	engineMailCapacity = null;
	
	constructor() {
		totalMaintenanceCosts = 0;
		engineMailCapacity = {};
	}
	

	function GetAvailableAiportTraits() {
		local result = [];
		foreach(t in Air.airportTraits) {
			if(AIAirport.IsValidAirportType(t.airportType) && AIAirport.IsAirportInformationAvailable(t.airportType)) {
				result.push(t);
			}
		}
		return result;
	}
	
	function GetMinimumAiportType(isBigPlane=false) {
		local a = GetAvailableAiportTraits();
		if(a.len()==0) {
			return null;
		}
		if(isBigPlane) {
			foreach(t in Air.airportTraits) {
				if(t.supportBigPlane) {
					return t.airportType;
				}
			}
			return null;
		} else {
			return a[0].airportType;
		}
	}
	
	function GetAiportTraits(airportType) {
		if(type2Traits == null) {
			type2Traits = {};
			foreach(t in Air.airportTraits) {
				type2Traits.rawset(t.airportType, t);
			}
		}
		return type2Traits.rawget(airportType);
	}
	
	function IsCoverAiportType(airportType1,airportType2) {
		return GetAiportTraits(airportType1).level >= GetAiportTraits(airportType2).level;
	}
	
	function AddAirStation(airStation) {
		totalMaintenanceCosts += GetAiportTraits(airStation.airportType).maintenanceCost;
	}
	
	function RemoveAirStation(airStation) {
		totalMaintenanceCosts -= GetAiportTraits(airStation.airportType).maintenanceCost;
	}
	
	function GetMailSubcargoCapacity(engine) {
		if(engineMailCapacity.rawin(engine)) {
			return engineMailCapacity.rawget(engine);
		}
		local real = GetMailSubcargoCapacityReal(engine);
		if(real == -1) {
			return AIEngine.GetCapacity(engine) / 8; //不明なので適当
		}
		engineMailCapacity.rawset(engine,real);
		return real;
	}
	
	function GetMailSubcargoCapacityReal(engine) {
		if(AirRoute.instances.len() == 0) return -1;
		local execMode = AIExecMode();
		local sampleDepot = AirRoute.instances[0].depot; // TODO:ヘリパッドだとバグるけど今のところ無い
		local price = AIEngine.GetPrice(engine);
		if(price > HogeAI.GetUsableMoney()) {
			HgLog.Warning("Not enough money (Air.GetMailSubcargoCapacity) "+AIEngine.GetName(engine)+" price:"+price);
			return -1;
		}
		HogeAI.WaitForPrice(price,0);
		local vehicle = AIVehicle.BuildVehicle(sampleDepot,engine);
		if(!AIVehicle.IsValidVehicle(vehicle)) {
			HgLog.Warning("Failed to BuildVehicle (Air.GetMailSubcargoCapacity) "+AIEngine.GetName(engine)+" "+AIError.GetLastErrorString());
			return -1;
		}
		local result = AIVehicle.GetCapacity(vehicle, HogeAI.GetMailCargo())
		AIVehicle.SellVehicle(vehicle);
		return result;
	}
}


class AirRoute extends CommonRoute {
	static instances = [];
	

	static function SaveStatics(data) {
		local a = [];
		foreach(route in AirRoute.instances) {
			a.push(route.Save());
		}
		data.airRoutes <- a;
		data.airTotalMaintenanceCosts <- Air.Get().totalMaintenanceCosts;
	}
	
	static function LoadStatics(data) {
		AirRoute.instances.clear();
		foreach(t in data.airRoutes) {
			local route = AirRoute();
			route.Load(t);
			
			HgLog.Info("load:"+route);
			
			AirRoute.instances.push(route);	
			PlaceDictionary.Get().AddRoute(route);
		}
		if("airTotalMaintenanceCosts" in data) Air.Get().totalMaintenanceCosts = data.airTotalMaintenanceCosts;
	}
	
	constructor() {
		CommonRoute.constructor();
		useDepotOrder = false;
		useServiceOrder = false;
		isDestFullLoadOrder = true;
	}
	
	function Save() {
		local t = CommonRoute.Save();
		return t;
	}
	
	function Load(t) {
		CommonRoute.Load(t);
	}
	
	function GetVehicleType() {
		return AIVehicle.VT_AIR;
	}	
	
	function GetMaxTotalVehicles() {
		return HogeAI.Get().maxAircraft;
	}
	
	function GetThresholdVehicleNumRateForNewRoute() {
		return 0.95;
	}

	function GetThresholdVehicleNumRateForSupportRoute() {
		return 0.9;
	}

	function GetLabel() {
		return "Air";
	}
	
	function GetBuilderClass() {
		return AirRouteBuilder;
	}
	
	
	function GetDefaultInfrastractureTypes() {
		local result = [];
		foreach(traints in Air.Get().GetAvailableAiportTraits()) {
			result.push(traints.airportType);
		}	
	
		return result;
	}

	function GetInfrastractureTypes(engine) {
		local result = [];
		local isBigPlane = AIEngine.GetPlaneType(engine) == AIAirport.PT_BIG_PLANE;
		foreach(traints in Air.Get().GetAvailableAiportTraits()) {
			if(!isBigPlane || traints.supportBigPlane) {
				result.push(traints.airportType);
			}
		}
		return result;
	}
	
	function GetSuitableInfrastractureTypes(src, dest, cargo) { //TODO: 何度も呼ばれるのでキャッシュなりを検討
		local result = [];
		foreach(traints in Air.Get().GetAvailableAiportTraits()) {
			if(src.CanBuildAirport(traints.airportType, cargo) && dest.CanBuildAirport(traints.airportType, cargo)) {
				result.push(traints.airportType);
			}
		}
		return result;
	}
	
	function EstimateMaxRouteCapacity(infrastractureType, engineCapacity) {
		if(infrastractureType == null) {
			return 0;
		}
		return 30 * engineCapacity / Air.Get().GetAiportTraits(infrastractureType).stationDateSpan;
	}
	
	function GetInfrastractureCost(infrastractureType, distance) {
		if(!HogeAI.Get().IsInfrastructureMaintenance()) {
			return 0;
		}
		return InfrastructureCost.Get().GetCostPerAirport(infrastractureType) * 2;
	}

	function GetRouteInfrastractureCost() {
		if(!HogeAI.Get().IsInfrastructureMaintenance()) {
			return 0;
		}
		return InfrastructureCost.Get().GetCostPerAirport(srcHgStation.airportType) 
			+ InfrastructureCost.Get().GetCostPerAirport(destHgStation.airportType);
	}
	
	function GetPathDistance() {
		local p1 = srcHgStation.platformTile;
		local p2 = destHgStation.platformTile;
		
		local w = abs(AIMap.GetTileX(p1) - AIMap.GetTileX(p2));
		local h = abs(AIMap.GetTileY(p1) - AIMap.GetTileY(p2));
		
		return (min(w,h).tofloat() * 0.414 + max(w,h)).tointeger();
	}

	function SetPath(path) {
	}
	
	function AppendSrcToDestOrder(vehicle) {
	}
	
	function AppendDestToSrcOrder(vehicle) {
	}
	
	
	function CanCreateNewRoute() {
		return true;

		if(HogeAI.Get().IsInfrastructureMaintenance()) {
			return HogeAI.Get().IsRich() /*&& InfrastructureCost.Get().CanExtendAirport()*/;
		} else {
			return true;
		}
	}
	
	function BuildDepot(path) {
		depot = AIAirport.GetHangarOfAirport(srcHgStation.platformTile);
		return true;
	}
	
	function BuildDestDepot(path) {
		destDepot = AIAirport.GetHangarOfAirport(destHgStation.platformTile);
		return true;
	}
	
	function GetStationDateSpan(self) {
		if((typeof self) == "instance" && self instanceof AirRoute) {	
			local srcUsings = ArrayUtils.Without(srcHgStation.GetUsingRoutes(),this).len()+1; // srcHgStation.GetUsingRoutesにまだthisが含まれていない事があるので
			local destUsings = ArrayUtils.Without(destHgStation.GetUsingRoutes(),this).len()+1;
			return max( Air.Get().GetAiportTraits(srcHgStation.airportType).stationDateSpan * srcUsings,
				Air.Get().GetAiportTraits(destHgStation.airportType).stationDateSpan * destUsings );
		} else {
			local traits = Air.Get().GetAvailableAiportTraits();
			if(traits.len() >= 1) {
				return traits[traits.len()-1].stationDateSpan + (HogeAI.Get().IsEnableVehicleBreakdowns() ? 10 : 0);
			} else {
				return 30;
			}
		}
	}
	
	function IsBigPlane() {
		local vehicle = GetLatestVehicle();
		if(vehicle == null) {
			return false;
		} else {
			return AIEngine.GetPlaneType(AIVehicle.GetEngineType(vehicle)) == AIAirport.PT_BIG_PLANE;
		}
	}

	function OnVehicleLost(vehicle) {
	}
	
}


class AirRouteBuilder extends CommonRouteBuilder {
	infrastractureType = null;

	constructor(dest, src, cargo, options = {}) {
		CommonRouteBuilder.constructor(dest, src, cargo, options);
		makeReverseRoute = false;
		isNotRemoveStation = HogeAI.Get().IsInfrastructureMaintenance() == false;
		isNotRemoveDepot = true;
		checkSharableStationFirst = true;
	}

	function GetRouteClass() {
		return AirRoute;
	}
	/*
	function Build() {
		if(!InfrastructureCost.Get().CanExtendAirport()) {
			HgLog.Warning("CanExtendAirport false."+this);
			return null;
		}
		return CommonRouteBuilder.Build();
	}*/
	
	function CreateStationFactory(target,engineSet) { 
		return AirportStationFactory([infrastractureType]);
		/*infrastractureTypeには見積もり結果を使う
		local airportTypes = GetUsingAirportTypes();
		if(airportTypes.len() == 0) {
			return null;
		}
		return AirportStationFactory(airportTypes);*/
	}
	
	function CreatePathBuilder(engine, cargo) {
		return AirPathBuilder();
	}
	
	function GetUsingAirportTypes() {
		local usableAiportTypesDest = GetUsableAirportTypes(dest);
		local usableAiportTypesSrc = GetUsableAirportTypes(srcPlace);
		if(usableAiportTypesDest.len()==0) {
			if(GetUsableStation(dest, cargo) != null) {
				usableAiportTypesDest = Air.allAirportTypes;
			} else {
				HgLog.Info("AddNgPlace. No usable airportTypes:"+dest.GetName());
				Place.AddNgPlace(dest,cargo,AIVehicle.VT_AIR);
			}
		}
		if(usableAiportTypesSrc.len()==0) {
			if(GetUsableStation(srcPlace, cargo) != null) {
				usableAiportTypesSrc = Air.allAirportTypes;
			} else {
				HgLog.Info("AddNgPlace. No usable airportTypes:"+srcPlace.GetName());
				Place.AddNgPlace(dest,cargo,AIVehicle.VT_AIR);
			}
		}
		local usableAiportTypeTable = HgTable.FromArray(usableAiportTypesDest);
		local result = [];
		foreach(t in usableAiportTypesSrc) {
			if(usableAiportTypeTable.rawin(t)) {
				result.push(t);
			}
		}
		result.reverse();
		return result;
	}

	function GetUsableAirportTypes(placeOrGroup) {
		local result = [];
		local distanceCorrection = HogeAI.Get().isUseAirportNoise ? 1 : 0;
		local limitCost = HogeAI.Get().GetUsableMoney() / 4;
		foreach(traits in Air.Get().GetAvailableAiportTraits()) {
			if(traits.cost * 2 > limitCost) {
				continue;
			}
			if(placeOrGroup instanceof Place) {
				if(placeOrGroup.CanBuildAirport(traits.airportType, cargo)) {
					result.push(traits.airportType);
				}
			} else {
				local noiseLevelIncrease = AIAirport.GetNoiseLevelIncrease( location, traits.airportType );
				local town;
				if( HogeAI.Get().isUseAirportNoise ) {
					town = AIAirport.GetNearestTown( location, traits.airportType );
				} else {
					town = AITile.GetClosestTown( location );
				}
				
				
				if( noiseLevelIncrease <= AITown.GetAllowedNoise(town) + distanceCorrection) {
					result.push(traits.airportType);
				}
			}
		}
		return result;
	}
	
	function GetUsableStation(placeOrGroup, cargo) {
		foreach(station in HgStation.SearchStation(placeOrGroup, AIStation.STATION_AIRPORT, cargo, placeOrGroup instanceof Place ? placeOrGroup.IsAccepting() : null)) {
			if(station.CanShareByMultiRoute(null, cargo)) {
				return station;
			}
		}
		return null;
	}
	
	
	function BuildStart(engineSet) {
		infrastractureType = engineSet.infrastractureType;
	}
}

class ExchangeAirsBuilder {
	cargo = null;
	s1 = null;
	d1 = null;
	s2 = null;
	d2 = null;
	route1 = null;
	route2 = null;

	constructor(cargo,stations,route1,route2) {
		this.cargo = cargo;
		this.s1 = stations[0];
		this.d1 = stations[1];
		this.s2 = stations[2];
		this.d2 = stations[3];
		this.route1 = route1;
		this.route2 = route2;
	}

	function Build() {
		local options = {
			pendingToDoPostBuild = false
			destRoute = null
			transfer = false
		};
		local newRoute1 = AirRouteBuilder(s1,d1,cargo,options).DoBuild();
		if(newRoute1 == null) {
			return [];
		}
		local newRoute2 = AirRouteBuilder(s2,d2,cargo,options).DoBuild();
		if(newRoute2 == null) {
			newRoute1.Remove();
			return [];
		}
		HgLog.Warning("ExchangeAirsBuilder remove route:"+route1);
		HgLog.Warning("ExchangeAirsBuilder remove route:"+route2);
		route1.Remove();
		route2.Remove();
		return [newRoute1, newRoute2];
	}

}

class AirportStationFactory extends StationFactory {
	airportTypes = null;
	
	currentAirportType = null;
	currentNum = null;
	currentLength = null;
	
	constructor(airportTypes) {
		StationFactory.constructor();
		this.ignoreDirectionScore = true;
		this.ignoreDirection = true;
		this.airportTypes = airportTypes;
	}

	function GetStationType() {
		return AIStation.STATION_AIRPORT;
	}
	
	function GetVehicleType() {
		return AIVehicle.VT_AIR;
	}
	
	function GetPlatformNum() {
		return currentNum;
	}
	
	function GetPlatformLength() {
		return currentLength;
	}
	
	function Create(platformTile,stationDirection) {
		return AirStation(platformTile, currentAirportType);
	}
	
	function GetCoverageRadius() {
		return AIAirport.GetAirportCoverageRadius( currentAirportType );
	}
	
	function SetAirportType(airportType) {
		currentAirportType = airportType;
		currentNum = AIAirport.GetAirportWidth(airportType);
		currentLength = AIAirport.GetAirportHeight(airportType);
		HgLog.Info("SetAirportType:"+airportType+" "+currentNum+"x"+currentLength);
	}
	
	
	function CreateBest( target, cargo, toTile ) {
		foreach(airportType in airportTypes) {			
			SetAirportType(airportType);
			local result = StationFactory.CreateBest(target, cargo, toTile);
			if(result != null) {
				return result;
			}
		}
		return null;
	}
	function GetTypeName() {
		return "AirStation";
	}
}


class AirStation extends HgStation {
	airportType = null;
	
	constructor(platformTile, airportType) {
		HgStation.constructor(platformTile, 0);
		this.originTile = platformTile;
		this.airportType = airportType;
		this.platformNum = AIAirport.GetAirportWidth(airportType);
		this.platformLength = AIAirport.GetAirportHeight(airportType);
	}
	
	
	function Save() {
		local t = HgStation.Save();
		t.airportType <- airportType;
		return t;
	}
	
	function GetTypeName() {
		return "AirStation";
	}
	
	function GetAirportType() {
		return airportType;
	}
	
	function GetStationType() {
		return AIStation.STATION_AIRPORT;
	}
	
	function GetCoverageRadius() {
		return AIAirport.GetAirportCoverageRadius( airportType );
	}

	function IsBuildablePreCheck() {
		if(!HogeAI.IsBuildable(platformTile)) {
			return false;
		}
		if(!HogeAI.IsBuildable(platformTile + AIMap.GetTileIndex(platformNum-1,0))) {
			return false;
		}
		if(!HogeAI.IsBuildable(platformTile + AIMap.GetTileIndex(0,platformLength-1))) {
			return false;
		}
		if(!HogeAI.IsBuildable(platformTile + AIMap.GetTileIndex(platformNum-1,platformLength-1))) {
			return false;
		}
		return true;
	}
	
	function BuildStation(joinStation,isTestMode) {
		HogeAI.WaitForPrice(AIAirport.GetPrice(airportType));
		return AIAirport.BuildAirport(platformTile, airportType, joinStation);
	}
	
	function GetAuthorityTown() {
		if( HogeAI.Get().isUseAirportNoise ) {
			return AIAirport.GetNearestTown( platformTile, airportType );
		} else {
			return AITile.GetClosestTown( platformTile );
		}
	}
	
	
	function Build(levelTiles=true,isTestMode=true) {
		if(levelTiles) {
			if(isTestMode) {
				local allowdNoise = AITown.GetAllowedNoise( GetAuthorityTown() );
				if(AIAirport.GetNoiseLevelIncrease( platformTile, airportType ) > allowdNoise) {
					return false;
				}
				local tilesGen = GetTilesGen();
				local tile;
				while((tile = resume tilesGen) != null) {
					if(!HogeAI.IsBuildable(tile)) {
						return false;
					}
				}
				if(!BuildPlatform(isTestMode) 
					&& ( AIError.GetLastError() == AIStation.ERR_STATION_TOO_MANY_STATIONS_IN_TOWN
						|| AIError.GetLastError() == AIStation.ERR_STATION_TOO_CLOSE_TO_ANOTHER_STATION ) ) {
					return false;
				}
			}
			if(!Rectangle(HgTile(platformTile), HgTile(platformTile + AIMap.GetTileIndex(platformNum, platformLength))).LevelTiles(AIRail.RAILTRACK_NW_SE, isTestMode)) {
				if(!isTestMode) {
					HgLog.Warning("LevelTiles(AirStation) failed");
				}
				return false;
			}
			if(isTestMode) {
				return true;
			}
		}

		if(!BuildPlatform(isTestMode)) {
			if(!isTestMode) {
				HgLog.Warning("BuildPlatform(AirStation) failed (town:"+AITown.GetName(GetAuthorityTown())+")");
			}
			return false;
		}
		if(!isTestMode) Air.Get().AddAirStation(this);
		return true;
	}

	function Demolish() {
		local execMode = AIExecMode();
		if(!BuildUtils.RemoveAirportSafe(platformTile)) {
			HgLog.Warning("AIAirport.RemoveAirport failed "+this+" "+AIError.GetLastErrorString());
		}
		Air.Get().RemoveAirStation(this);
		return true;
	}
	
	function IsClosed() {
		return AIStation.IsAirportClosed(stationId);
	}
	
	function Open() {
		if(IsClosed()) {
			AIStation.OpenCloseAirport(stationId);
		}
	}

	function Close() {
		if(!IsClosed()) {
			AIStation.OpenCloseAirport(stationId);
		}
	}

	function GetTilesGen() {
		for(local i=0; i<platformNum; i++) {
			for(local j=0; j<platformLength; j++) {
				yield platformTile + AIMap.GetTileIndex(i,j);
			}
		}
		return null;
	}
	
	function GetTiles() {
		return HgArray.Generator(GetTilesGen()).array;
	}
	
	function GetEntrances() {
		return [];
	}
	
	function GetBuildableScore() {
		return 0;
	}
	
	function CanShareByMultiRoute(infrastractureType = null, cargo = null) {
		local traits = GetAirportTraits();
		if(infrastractureType != null) {
			if( traits.level < Air.Get().GetAiportTraits(infrastractureType).level ) {
				return false;
			}
		}
		usingRoutes = GetUsingRoutes();
		if(usingRoutes.len() >= traits.terminals - 1) {
			return false;
		}
		local arrivesPerYear = 0;
		foreach(route in usingRoutes) {
			if(route.IsBiDirectional()) {
				if(cargo == null || route.cargo == cargo) {
					return false;
				}
			}
			if(route.GetLatestEngineSet() == null) continue;
			arrivesPerYear += 365 / route.GetLatestEngineSet().GetInterval();
			if(arrivesPerYear > 365 / traits.stationDateSpan / 2) { // 半分以上空いている時のみ新規航路を受け入れる
				return false;
			}
		}
		return true;
	}
	
	function GetAirportTraits() {
		return Air.Get().GetAiportTraits(airportType);
	}
}

class AirPathBuilder {
	path = null;
	
	function BuildPath(starts ,goals, suppressInterval=false) {
		return true;
	}
}

