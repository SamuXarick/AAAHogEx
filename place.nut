
class PlaceProduction {
	static instance = GeneratorContainer(function() { 
		return PlaceProduction(); 
	});

	static function Get() {
		return PlaceProduction.instance.Get();
	}
	
	lastCheckMonth = null;
	history = null;
	ngPlaces = null;
	
	constructor() {
		history = {};
		ngPlaces = {};
	}
	
	static function Save(data) {
		data.placeProduction <- {
			lastCheckMonth = lastCheckMonth
			history = history
		};
	}

	static function Load(data) {
		local t = data.placeProduction;
		lastCheckMonth = t.lastCheckMonth;
		history = t.history;
	}
	
	function GetCurrentMonth () {
		local currentDate = AIDate.GetCurrentDate();
		return (AIDate.GetMonth(currentDate)-1) + AIDate.GetYear(currentDate) * 12;
	}
	
	function Check() {
		local currentMonth = GetCurrentMonth();
		if(lastCheckMonth == null || lastCheckMonth < currentMonth) {
			foreach(cargo,v in AICargoList()) {
				foreach(industry,v in AIIndustryList_CargoProducing(cargo)) {
					local production = AIIndustry.GetLastMonthProduction (industry, cargo);
					//HgLog.Info("GetLastMonthProduction "+AIIndustry.GetName(industry)+" "+AICargo.GetName(cargo)+" "+production);
					if(!history.rawin(industry+"-"+cargo)) {
						history[industry+"-"+cargo] <- [];
					}
					local a = history[industry+"-"+cargo];
					if(a.len() < 12) {
						a.push(0);
					}
					for(local i=a.len()-2;i>=0;i--) {
						a[i+1] = a[i]
					}
					a[0] = production;
				}
			}
			lastCheckMonth = currentMonth;
		}
	}
	
	function GetLastMonthProduction(industry,cargo) {
		Check();
		if(history.rawin(industry+"-"+cargo)) {
			local sum = 0;
			local a = history[industry+"-"+cargo];
			foreach(p in a) {
				sum += p;
			}
			return sum / a.len();
		}
		return 0;
	}
}

class PlaceDictionary {
	static instance = GeneratorContainer(function() { 
		return PlaceDictionary(); 
	});

	static function Get() {
		return PlaceDictionary.instance.Get();
	}
	
	sources = null;
	dests = null;
	nearWaters = null;
	
	constructor() {
		sources = {};
		dests = {};
		nearWaters = {};
	}
	
	function AddRoute(route) {
		if(route.srcHgStation.place != null) {
			AddRouteTo(sources, route.srcHgStation.place, route);
		}
		if(route.destHgStation.place != null) {
			if(route.IsBiDirectional()) {
				AddRouteTo(sources, route.destHgStation.place.GetProducing(), route);
			} else {
				AddRouteTo(dests, route.destHgStation.place, route);
			}
		}
		route.srcHgStation.AddUsingRoute(route);
		route.destHgStation.AddUsingRoute(route);
	}

	function RemoveRoute(route) {
		if(route.srcHgStation.place != null) {
			RemoveRouteFrom(sources, route.srcHgStation.place, route);
		}
		if(route.destHgStation.place != null) {
			if(route.IsBiDirectional()) {
				RemoveRouteFrom(sources, route.destHgStation.place.GetProducing(), route);
			} else {
				RemoveRouteFrom(dests, route.destHgStation.place, route);
			}
		}
		route.srcHgStation.RemoveUsingRoute(route);
		route.destHgStation.RemoveUsingRoute(route);
	}
	
	function RemoveRouteFrom(dictionary, place, route) {
		local id = place.Id();
		if(dictionary.rawin(id)) {
			ArrayUtils.Remove(dictionary[id], route);
		}
	}
	
	function AddRouteTo(dictionary, place, route) {
		local id = place.Id();
		if(!dictionary.rawin(id)) {
			dictionary[id] <- [];
		}
		ArrayUtils.Add(dictionary[id], route);
	}
	
	function CanUseAsSource(place, cargo) {
		local routes = GetRoutesBySource(place);
		foreach(route in routes) {
			if(route.cargo == cargo && (route instanceof TrainRoute) && !route.IsOverflow()) {
				return false;
			}
		}
		return !Place.IsRemovedDestPlace(place);	
	}
	
	function IsUsedAsSourceCargo(place,cargo) {
		foreach(route in GetRoutesBySource(place)) {
			if(route.cargo == cargo) {
				return true;
			}
		}
		return false;
	}
	
	function IsUsedAsSrouceByTrain(place, except=null) {
		foreach(route in GetRoutesBySource(place)) {
			if(route instanceof TrainRoute && route != except) {
				return true;
			}
		}
		return false;
	}
	
	function IsUsedAsSrouceCargoByTrain(place,cargo) {
		foreach(route in GetRoutesBySource(place)) {
			if(route instanceof TrainRoute && route.cargo == cargo) {
				return true;
			}
		}
		return false;
	}
	
	function GetUsedAsSourceCargoByRailOrAir(place,cargo) {
		local result = [];
		foreach(route in GetRoutesBySource(place)) {
			local vehicleType = route.GetVehicleType();
			if((vehicleType == AIVehicle.VT_RAIL || vehicleType == AIVehicle.VT_AIR) && route.cargo == cargo) {
				result.push(route);
			}
		}
		return result;
	}
	
	function GetUsedAsSourceByTrain(place) {
		local result = [];
		foreach(route in GetRoutesBySource(place)) {
			if(route instanceof TrainRoute) {
				result.push(route);
			}
		}
		return result;
	}

	function GetRoutesByDestCargo(place, cargo) {
		local result = [];
		foreach(route in GetRoutesByDest(place)) {
			if(route.cargo == cargo) {
				result.push(route);
			}
		}
		return result;
		
	}

	function GetRoutesBySource(place) {
		return GetRoutes(sources,place);
	}

	function GetRoutesByDest(place) {
		return GetRoutes(dests,place);
	}

	function GetRoutes(dictionary, place) {
		local id = place.Id();
		if(!dictionary.rawin(id)) {
			dictionary[id] <- [];
		}
		return dictionary[id];
/*		local result = [];
		foreach(route in dictionary[id]) {
			if(!route.IsClosed()) {
				result.push(route);
			}
		}
		return result;*/
	}
}


class Place {

	static removedDestPlaceDate = [];
	static ngPathFindPairs = {};
	static productionHistory = [];
	static needUsedPlaceCargo = [];
	static ngPlaces = {};
	
	static function SaveStatics(data) {
		local array = [];

		array = [];
		foreach(placeDate in Place.removedDestPlaceDate){
			local t = placeDate[0].Save();
			t.date <- placeDate[1];
			array.push(t);
		}
		data.removedDestPlaceDate <- array;
		
		array = [];
		foreach(t in Place.needUsedPlaceCargo){
			array.push([t[0].Save(),t[1]]);
		}
		data.needUsedPlaceCargo <- array;
		
		data.ngPathFindPairs <- Place.ngPathFindPairs;
		
		array = [];
		foreach(industry,v in HgIndustry.closedIndustries){
			array.push(industry);
		}
		data.closedIndustries <- array;
		
		
		PlaceProduction.Get().Save(data);

		data.nearWaters <- PlaceDictionary.Get().nearWaters;
		data.ngPlaces <- Place.ngPlaces;
	}

	
	static function LoadStatics(data) {
		
		Place.removedDestPlaceDate.clear();
		foreach(t in data.removedDestPlaceDate) {
			Place.removedDestPlaceDate.push([Place.Load(t),t.date]);
		}
		
		
		Place.needUsedPlaceCargo.clear();
		foreach(t in data.needUsedPlaceCargo) {
			Place.needUsedPlaceCargo.push([Place.Load(t[0]) ,t[1]]);
		}
		
		Place.ngPathFindPairs.clear();
		foreach(k,v in data.ngPathFindPairs) {
			Place.ngPathFindPairs.rawset(k,v);
		}

		HgIndustry.closedIndustries.clear();
		foreach(industry in data.closedIndustries){
			HgIndustry.closedIndustries[industry] <- true;
		}
		PlaceProduction.Get().Load(data);
		
		PlaceDictionary.Get().nearWaters = data.nearWaters;
		if(data.rawin("ngPlaces")) {
			HgTable.Extend(Place.ngPlaces, data.ngPlaces);
		}
	}
	
	static function Load(t) {		
		switch(t.name) {
			case "HgIndustry":
				return HgIndustry(t.industry,t.isProducing);
			case "TownCargo":
				return TownCargo(t.town,t.cargo,t.isProducing);
		}
	}
	
	static function DumpData(data) {
		if(typeof data == "table" || typeof data == "array") {
			local result = "[";
			foreach(k,v in data) {
				result += (k+"="+Place.DumpData(v))+",";
			}
			result += "]";
			return result;
		} else {
			return data;
		}
		
	}
	
			
	static function SetRemovedDestPlace(place) {
		Place.removedDestPlaceDate.push([place,AIDate.GetCurrentDate()]);
	}
	
	
	static function IsRemovedDestPlace(place) {
		local current = AIDate.GetCurrentDate();
		foreach(placeDate in Place.removedDestPlaceDate) {
			if(placeDate[0].IsSamePlace(place) && current < placeDate[1]+60) {
				return true;
			}
		}
		return false;
	}
	
	static function AddNgPlace(facility, vehicleType) {
		Place.ngPlaces.rawset(facility.GetLocation() + ":" + vehicleType, 
			AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES ? AIDate.GetCurrentDate() + 60 : AIDate.GetCurrentDate() + 1500);
	}

	static function IsNgPlace(facility, vehicleType) {
		local key = facility.GetLocation() + ":" + vehicleType;
		if(Place.ngPlaces.rawin(key)) {
			local date = Place.ngPlaces[key];
			if(date == -1) {
				return true;
			} else {
				return AIDate.GetCurrentDate() < date;
			}
		}
		return false;
	}
	
	static function AddNgPathFindPair(from, to, vehicleType) {
		if(AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
			return;
		}
		local fromTile = typeof from == "integer" ? from : from.GetLocation();
		local toTile = typeof to == "integer" ? to : to.GetLocation();
		
		Place.ngPathFindPairs.rawset(fromTile+"-"+toTile+"-"+vehicleType,true);
	}
	
	static function IsNgPathFindPair(from, to, vehicleType) {
		local fromTile = typeof from == "integer" ? from : from.GetLocation();
		local toTile = typeof to == "integer" ? to : to.GetLocation();
		return Place.ngPathFindPairs.rawin(fromTile+"-"+toTile+"-"+vehicleType);
	}
	
	static function AddNeedUsed(place, cargo) {
		Place.needUsedPlaceCargo.push([place, cargo]);
	}
	
	static function GetCargoProducing(cargo, isIncreasableProcessingOrRaw = true) {
		local result = [];
		foreach(industry,v in AIIndustryList_CargoProducing(cargo)) {
			local hgIndustry = HgIndustry(industry,true);
			if(!(isIncreasableProcessingOrRaw && !hgIndustry.IsIncreasableProcessingOrRaw())) {
				result.push(hgIndustry);
			}
		}
		if(Place.IsProducedByTown(cargo)) {
			local townList = AITownList();
			townList.Valuate(AITown.GetPopulation);
			townList.KeepAboveValue( 600 );
			foreach(town, v in townList) {
				result.push(TownCargo(town,cargo,true));
			}
		}
		return HgArray(result);
	}

	static function IsAcceptedByTown(cargo) {
		return /*AIIndustryList_CargoAccepting(cargo).Count()==0 &&*/ AICargo.GetTownEffect(cargo) != AICargo.TE_NONE;
	}
	
	static function IsProducedByTown(cargo) {
		return cargo == HogeAI.GetPassengerCargo() || cargo == HogeAI.GetMailCargo();
	}

	static function SearchNearProducingPlaces(cargo, fromTile, maxDistance) {
		return Place.GetCargoProducing(cargo,false).Filter(function(place):(cargo,fromTile,maxDistance) {
			return place.DistanceManhattan(fromTile) <= maxDistance && place.GetLastMonthProduction(cargo) >= 1;
		});
	}
	

	static function GetNotUsedProducingPlaces(cargo, isIncreasableProcessingOrRaw = true) {
		return Place.GetCargoProducing(cargo,isIncreasableProcessingOrRaw).Filter(function(place):(cargo) {
			return PlaceDictionary.Get().CanUseAsSource(place,cargo);
		});
	}
	
	static function GetProducingPlaceDistance(cargo, fromTile, isIncreasableProcessingOrRaw = true, maxDistance=200) {
		return Place.GetNotUsedProducingPlaces(cargo, isIncreasableProcessingOrRaw).Map(function(place):(fromTile) {
			return [place,place.DistanceManhattan(fromTile)];
		}).Filter(function(placeDistance):(maxDistance) {
			return placeDistance[1] < maxDistance;
		})
	}
	
	static function AdjustProduction(place,production) {
		
		local accepting = place.GetAccepting();
		local canInclease = false;
		if(accepting.IsRaw() && accepting.IsNearAnyOneNeeds()) {
			production *= 2;
		}
		if(accepting.IsProcessing() && accepting.IsNearAllNeeds()) {
			production *= 2;
		}
		return production;
	}
	

	static function SearchSrcAdditionalPlaces(src, destTile, cargo, minDistance=20, maxDistance=200, minProduction=60, maxCost=100, minScore=200, vehicleType=AIVehicle.VT_RAIL) {
		local middleTile;
		if(src instanceof HgStation && src.place != null) {
			middleTile = src.place.GetLocation(); // srcとdestが同じになるのを防ぐため
		} else {
			middleTile = src.GetLocation();
		}
		local existingDistance = destTile == null ? 0 : AIMap.DistanceManhattan(destTile, middleTile);
		return Place.GetProducingPlaceDistance(cargo, middleTile, vehicleType == AIVehicle.VT_RAIL, maxDistance).Map(function(placeDistance):(cargo, destTile) {
			local t = {};
			t.place <- placeDistance[0];
			t.distance <- placeDistance[1];
			t.totalDistance <- destTile == null ? t.distance : AIMap.DistanceManhattan(destTile, t.place.GetLocation());
			t.production <- t.place.GetLastMonthProduction(cargo);
			return t;
		}).Filter(function(t):(middleTile, minDistance, minDistance, minProduction, existingDistance, vehicleType){
			return minDistance <= t.distance 
				&& (existingDistance==0 || t.totalDistance - t.distance > existingDistance / 2)
				&& minProduction <= t.production 
				&& t.place.GetLocation() != middleTile 
				&& !Place.IsNgPathFindPair(t.place, middleTile, vehicleType);
		}).Map(function(t):(middleTile,vehicleType,cargo){
			t.cost <- vehicleType == AIVehicle.VT_WATER ? 1 : HgTile(middleTile).GetPathFindCost(HgTile(t.place.GetLocation()),vehicleType != AIVehicle.VT_RAIL);
			t.score <- t.totalDistance * 100 / t.cost; //TODO GetMaxCargoPlacesの結果を使う
			if(vehicleType == AIVehicle.VT_WATER && !t.place.IsNearWater(cargo)) {
				t.score = -1;
			}
			t.production = Place.AdjustProduction(t.place, t.production);
			return t;
		}).Filter(function(t):(maxCost, minScore) {
//			HgLog.Info("place:"+t.place.GetName()+" cost:"+t.cost+" dist:"+t.distance+" score:"+t.score);
			return t.cost <= maxCost// && minScore <= t.score 
		}).Sort(function(a,b) {
			return b.score * b.production - a.score * a.production;
		}).array;
	}
	

	static function GetCargoAccepting(cargo) {
		local result = HgArray([]);
		local limitPopulation = AICargo.GetTownEffect(cargo) == AICargo.TE_GOODS ? 1000 : 600;
		if(Place.IsAcceptedByTown(cargo)) {
			result = HgArray.AIListKey(AITownList()).Map(function(town) : (cargo) {
				return TownCargo(town,cargo,false);
			}).Filter(function(place) : (limitPopulation) {
				return AITown.GetPopulation (place.town) >= limitPopulation;
			});
		}
		result.array.extend(HgArray.AIListKey(AIIndustryList_CargoAccepting(cargo)).Map(function(a) {
			return HgIndustry(a,false);
		}).Filter(function(place):(cargo) {
			return place.IsCargoAccepted(cargo); //CAS_TEMP_REFUSEDを除外する
		}).array);
		return result;
	}
	
	static function GetAcceptingPlaceDistance(cargo, fromTile, maxDistance=1000 /*350*/) {
		return Place.GetCargoAccepting(cargo).Map(function(place):(fromTile) {
			return [place, place.DistanceManhattan(fromTile)];
		}).Filter(function(placeDistance):(maxDistance) {
			return placeDistance[1] < maxDistance;
		})
	}

	static function AdjustAcceptingPlaceScore(score, place, cargo) {
		if(place.IsProcessing()) {
			local usedRoutes = PlaceDictionary.Get().GetUsedAsSourceByTrain(place.GetProducing());
			if(usedRoutes.len()>0) {
				if(usedRoutes[0].NeedsAdditionalProducing()) {
					score *= 3;
				}
			} else {
				if(place.IsNearAllNeedsExcept(cargo)) {
					score *= 3;
				}
			}
		}
		//TODO rawでcargoが不足していて使用中の場合も
		return score;
	}

	static function SearchAcceptingPlaces(cargo,fromTile,vehicleType) {
		local hgArray = Place.GetAcceptingPlaceDistance(cargo,fromTile).Map(function(placeDistance) : (cargo,fromTile)  {
			local t = {};
			t.cargo <- cargo;
			t.place <- placeDistance[0];
			t.distance <- placeDistance[1];
			t.cost <- HgTile(fromTile).GetPathFindCost(HgTile(t.place.GetLocation()));
			t.score <- t.distance * 10000 / t.cost;
			return t;
		}).Filter(function(t):(fromTile,vehicleType) {
			if(vehicleType == AIVehicle.VT_RAIL && t.place.IsRaw()) {
				return false;
			}
			return 60 <= t.distance && t.cost < 300 && !Place.IsNgPathFindPair(t.place,fromTile,vehicleType) && t.place.IsAccepting();
		}).Map(function(t) {
			//t.score = Place.AdjustAcceptingPlaceScore(t.score,t.place,t.cargo);
			return t;
		});
		return hgArray.array;
/*		return hgArray.Sort(function(a,b) {
			return b.score - a.score;
		}).array;*/
	}
	static function SearchAdditionalAcceptingPlaces(cargo, srcTiles ,lastAcceptingTile, maxDistance) {
		
		local hgArray = null;
		
		local srcTilesScores = [];
		foreach(tile in srcTiles) {
			srcTilesScores.push([tile, HgTile(lastAcceptingTile).DistanceManhattan( HgTile(tile))]);
		}
		hgArray = Place.GetAcceptingPlaceDistance(cargo,lastAcceptingTile,maxDistance).Map(function(placeDistance) : (cargo, lastAcceptingTile, srcTilesScores)  {
			local t = {};
			t.cargo <- cargo;
			t.place <- placeDistance[0];
			t.distance <- placeDistance[1];
			t.cost <- HgTile(lastAcceptingTile).GetPathFindCost(HgTile(t.place.GetLocation()));
			local score = 0;
			foreach(tileScore in srcTilesScores) {
				score += (t.place.DistanceManhattan(tileScore[0]) - tileScore[1]) * 10000 / t.cost;
			}
			t.score <- score;
			return t;
		}).Filter(function(t):(lastAcceptingTile) {
			return 40 <= t.distance && t.cost < 200 && 10000 <= t.score && !Place.IsNgPathFindPair(t.place,lastAcceptingTile,AIVehicle.VT_RAIL) && t.place.IsAccepting();
		}).Map(function(t) {
			return [t.place,Place.AdjustAcceptingPlaceScore(t.score,t.place,t.cargo)];
		});
		return hgArray.Sort(function(a,b) {
				return b[1] - a[1];
			}).array;
		
	}
	
	static function GetLastMonthProduction(industry,cargo) {
		return PlaceProduction.Get().GetLastMonthProduction(industry,cargo);
	}
	
	
	function DistanceManhattan(tile) {
		return HgTile(GetLocation()).DistanceManhattan(HgTile(tile));
	}
	
	function GetStationGroups() {
		local result = {};
		foreach(hgStaion in GetHgStations()) {
			result[hgStaion.stationGroup] <- hgStaion.stationGroup;
		}
		return result;
	}
	
	function GetHgStations() {
		local result = [];
		foreach(id,hgStation in HgStation.worldInstances) {
			if(hgStation.place != null && hgStation.place.IsSamePlace(this)) {
				result.push(hgStation);
			}
		}
		return result;
	}
	
	function IsNearAnyOneNeeds() {
		foreach(cargo in GetAccepting().GetCargos()) {
			if(Place.SearchNearProducingPlaces(cargo, this.GetLocation(), 200).Count() >= 1) {
				return true;
			}
		}
		return false;
	}
	
	function IsNearAllNeeds() {
		return IsNearAllNeedsExcept(null);
	}
	
	function IsNearAllNeedsExcept(expectCargo) {
		local lack = false;
		foreach(cargo in GetAccepting().GetCargos()) {
			if(cargo == expectCargo) {
				continue;
			}
			if(Place.SearchNearProducingPlaces(cargo, this.GetLocation(), 200).Count() == 0) {
				lack = true;
			}
		}
		return !lack;
	}
	
	function IsTreatCargo(cargo) {
		foreach(eachCargo in GetCargos()) {
			if(eachCargo == cargo) {
				return true;
			}
		}
		return false;
	}
	
	function IsAcceptingAndProducing(cargo) {
		return GetAccepting().IsTreatCargo(cargo) && GetProducing().IsTreatCargo(cargo);
	}
	
	function CanUseNewRoute(cargo) {
		local result = true;
		foreach(route in PlaceDictionary.Get().GetRoutesBySource(this)) {
			if(route.cargo != cargo) {
				continue;
			}
			result = route.IsOverflowPlace(this); // 単体の新規ルートは何かに使用されていた場合（余っていない場合）、全て禁止
			//HgLog.Info("CanUseNewRoute "+this+" used:"+route+" isOverflow:"+result);
			if(!result) {
				break;
			}
		}
		if(result) {
			//HgLog.Info("CanUseNewRoute "+this+" result:"+result);
		}
		return result;
	}
	
	function CanUseTrainSource() {
		if(this instanceof TownCargo) {
			return true;
		} else {
			return IsIncreasable();
		}
	}
	
	function IsNearWater(cargo) {
		local placeDictionary = PlaceDictionary.Get();
		local id = Id()+":"+cargo;
		local result;
		if(!placeDictionary.nearWaters.rawin(id)) {
			result = CheckNearWater(cargo);
			placeDictionary.nearWaters[id] <- result;
			return result;
		} else {
			return placeDictionary.nearWaters[id];
		}
	}
	
	function CheckNearWater(cargo) {		
		//HgLog.Info("CheckNearWater "+this+" "+AICargo.GetName(cargo));
		if(IsBuiltOnWater()) {
			return true;
		}

		local dockRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
		local tile;
		local gen = GetTiles(dockRadius,cargo)
		while((tile = resume gen) != null) {
			if(AITile.IsCoastTile (tile)) {
				return true;
			}
		}
		return false;
	}
	
	function GetSuppliedRoutes(cargo) {
		local result = [];
		foreach(route in PlaceDictionary.Get().GetRoutesByDest(this)) {
			if(route.IsRemoved()) {
				continue;
			}
			if(route.cargo == cargo) {
				result.push(route);
			}
		}
		return result;
	}

	function IsCargoNotAcceptedRecently(cargo) {
		if(!IsCargoAccepted(cargo)) {
			return false;
		}
		foreach(route in PlaceDictionary.Get().GetRoutesByDestCargo(this, cargo)) {
			if(route.lastDestClosedDate != null && route.lastDestClosedDate > AIDate.GetCurrentDate() - 365) {
				return;
			}
		}
		return false;
	}
	
	function _tostring() {
		return GetName();
	}
}

class HgIndustry extends Place {
	static closedIndustries = {};
	
	industry = null;
	isProducing = null;
	
	constructor(industry,isProducing) {
		this.industry = industry;
		this.isProducing = isProducing;
	}
	
	function Save() {
		local t = {};
		t.name <-  "HgIndustry";
		t.industry <- industry;
		t.isProducing <- isProducing;
		return t;
	}
	
	function Id() {
		return "Industry:" + industry + ":" + isProducing;
	}
	
	function IsSamePlace(other) {
		if(!(other instanceof HgIndustry)) {
			return false;
		}
		return industry == other.industry && isProducing == other.isProducing;
	}
	
	function GetName() {
		return AIIndustry.GetName(industry);
	}
	
	function GetLocation() {
		return AIIndustry.GetLocation(industry);
	}
	
	function GetRadius() {
		return 3;
	}
	
	function GetTiles(coverageRadius,cargo) {
		local list = GetTileList(coverageRadius);
		if(isProducing) {
			list.Valuate( AITile.GetCargoProduction,cargo,1,1,coverageRadius);
			list.RemoveValue(0)
		} else {
			list.Valuate( AITile.GetCargoAcceptance,cargo,1,1,coverageRadius);
			list.RemoveBelowValue(8)
		}
		
		foreach(k,v in list) {
			yield k;
		}
		return null;
	}
	
	function GetTileList(coverageRadius) {
		if(isProducing) {
			return AITileList_IndustryProducing(industry, coverageRadius);
		} else {
			return AITileList_IndustryAccepting(industry, coverageRadius);
		}
	}
	
	function GetLastMonthProduction(cargo) {
		return Place.GetLastMonthProduction(industry,cargo); 
	}
	
	function IsClosed() {
		return closedIndustries.rawin(industry);
	}
	
	function GetCargos() {
		if(isProducing) {
			return HgArray.AIListKey(AICargoList_IndustryProducing (industry)).array;
		} else {
			return HgArray.AIListKey(AICargoList_IndustryAccepting (industry)).array;
		}
	}
	
	function IsCargoAccepted(cargo) {
		return AIIndustry.IsCargoAccepted(industry, cargo) == AIIndustry.CAS_ACCEPTED;
	}
	
	function IsAccepting() {
		return !isProducing;
	}
	
	function IsProducing() {
		return isProducing;
	}
	
	function GetAccepting() {
		if(isProducing) {
			return HgIndustry(industry,false);
		} else {
			return this;
		}
	}
	
	function GetProducing() {
		if(isProducing) {
			return this;
		} else {
			return HgIndustry(industry,true);
		}
	}
	
	function IsIncreasable() {
		local traits = GetIndustryTraits();
/*		if(traits=="PASS,/FOOD,BEER,PASS,") { 
			return false;
		}*/
		if(HgArray(GetAccepting().GetCargos()).Contains(HogeAI.GetPassengerCargo()) && HgArray(GetProducing().GetCargos()).Contains(HogeAI.GetPassengerCargo())) {
			return false;//FIRSのHOTELは生産量は増えない
		}
		
		local industryType = AIIndustry.GetIndustryType(industry);
		return AIIndustryType.ProductionCanIncrease(industryType);

	}
	
	function IsIncreasableProcessingOrRaw() {
		local industryType = AIIndustry.GetIndustryType(industry);
		return AIIndustryType.ProductionCanIncrease(industryType) 
					&& (AIIndustryType.IsProcessingIndustry (industryType) || AIIndustryType.IsRawIndustry(industryType));
	}
	
	function IsRaw() {
		local industryType = AIIndustry.GetIndustryType(industry);
		return AIIndustryType.IsRawIndustry(industryType);
	}
	
	function IsProcessing() {
		if(HogeAI.Get().ecs && GetIndustryTraits()=="WDPR,/WOOD,") {//ECSの製材所
			return true;
		}
	
		local industryType = AIIndustry.GetIndustryType(industry);
		return AIIndustryType.IsProcessingIndustry(industryType);
	}
	
	function GetStockpiledCargo(cargo) {
		return AIIndustry.GetStockpiledCargo(industry, cargo);
	}
		
	function IsBuiltOnWater() {
		return AIIndustry.IsBuiltOnWater(industry);
	}
	
	function HasStation(vehicleType) {
		return vehicleType == AIVehicle.VT_WATER && (AIIndustry.HasDock(industry) || AIIndustry.IsBuiltOnWater(industry));
	}

	function GetStationLocation(vehicleType) {
		if(vehicleType == AIVehicle.VT_WATER) {
			if(AIIndustry.HasDock(industry)) {
				return AIIndustry.GetDockLocation (industry);
			} else {
				return GetLocation();
			}
		}
		return null;
	}
	
	function GetLastMonthTransportedPercentage(cargo) {
		return AIIndustry.GetLastMonthTransportedPercentage(industry, cargo);
	}
	
	function GetIndustryTraits() {
		local industryType = AIIndustry.GetIndustryType(industry);
		if(!AIIndustryType.IsValidIndustryType(industryType)) {
			return ""; // たぶんcloseしてる
		}
		local s = "";
		foreach(cargo,v in AIIndustryType.GetProducedCargo(industryType)) {
			s += AICargo.GetCargoLabel(cargo)+",";
		}
		s += "/";
		foreach(cargo,v in AIIndustryType.GetAcceptedCargo(industryType)) {
			s += AICargo.GetCargoLabel(cargo)+",";
		}
		return s;
	}
	function CanBuildAirport(airportType) {
		local town = AIAirport.GetNearestTown(GetLocation(), airportType);
		return AITown.GetAllowedNoise(town) >= AIAirport.GetNoiseLevelIncrease(GetLocation(),airportType);
	}
}

class TownCargo extends Place {
	town = null;
	cargo = null;
	isProducing = null;
	
	constructor(town,cargo,isProducing) {
		this.town = town;
		this.cargo = cargo;
		this.isProducing = isProducing;
	}

	function Save() {
		local t = {};
		t.name <- "TownCargo";
		t.town <- town;
		t.cargo <- cargo;
		t.isProducing <- isProducing;
		return t;
	}

	function IsSamePlace(other) {
		if(!(other instanceof TownCargo)) {
			return false;
		}
		return town == other.town;
	}
	
	function Id() {
		return "TownCargo:" + town + ":" + cargo + ":" + isProducing;
	}

	function GetName() {
		return AITown.GetName(town);
	}
	
	function GetLocation() {
		return AITown.GetLocation(town);
	}
	

	function GetCargos() {
		if(cargo==null) {
			return [];
		}
		return [cargo];
	}
	
	function GetRadius() {
		return (sqrt(AITown.GetPopulation(town))/5).tointeger() + 2;
	}
	
	function GetTiles(coverageRadius,cargo) {
		if(cargo != this.cargo) {
			HgLog.Warning("Cargo not match. expect:"+AICargo.GetName(this.cargo)+" but:"+AICargo.GetName(cargo));
			return null;
		}
		
		local maxRadius = GetRadius();
		local tiles = Rectangle.Center(HgTile(GetLocation()),maxRadius).GetTilesOrderByOutside();
		if(IsProducing()) {
			tiles.reverse();
			foreach(tile in tiles) {
				if(AITile.GetCargoProduction(tile, cargo, 1, 1, coverageRadius) >= 8) {
					yield tile;
				}
			}
		} else {
			local bottom = AICargo.GetTownEffect (cargo) == AICargo.TE_GOODS ? 8 : 8;
			foreach(tile in tiles) {
				if(AITile.GetCargoAcceptance(tile, cargo, 1, 1, coverageRadius) >= bottom) {
					yield tile;
				}
			}
		}
		return null;
/*		
		result.Valuate(HogeAI.IsBuildable);
		result.KeepValue(1);
		result.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, coverageRadius);
		result.KeepAboveValue(17);
		return result;*/
	}
	
	function GetLastMonthProduction(cargo) {
		return AITown.GetLastMonthProduction( town, cargo ); // / 2;
	}
	
	function GetLastMonthTransportedPercentage(cargo) {
		return AITown.GetLastMonthTransportedPercentage(town, cargo);
	}
	
	function IsAccepting() {
		return !isProducing;
/*		//TODO: STATION_TRUCK_STOP以外のケース
		local gen = this.GetTiles(AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP),cargo);
		return resume gen != null;*/
	}
	
	function IsCargoAccepted(cargo) {
		return this.cargo == cargo;
	}
	
	
	function IsClosed() {
		return false;
	}
	
	function IsProducing() {
		return isProducing;
	}	
	
	function GetAccepting() {
		if(!isProducing) {
			return this;
		} else {
			return TownCargo(town,cargo,false);
		}
	}

	function GetProducing() {
		if(isProducing) {
			return this;
		} else {
			if(Place.IsProducedByTown(cargo)) {
				return TownCargo(town,cargo,true);
			} else {
				return TownCargo(town,null,true);
			}
		}
	}

	function IsIncreasable() {
		return false;

	}
	
	function IsIncreasableProcessingOrRaw() {
		return false;
	}
	
	function IsRaw() {
		return false;
	}
	
	function IsProcessing() {
		return false;
	}
	
	function GetStockpiledCargo(cargo) {
		return 0;
	}
	
	function IsBuiltOnWater() {
		return false;
	}

	function HasStation(vehicleType) {
		return false;
	}

	function GetStationLocation(vehicleType) {
		return null;
	}
	
	function CanBuildAirport(airportType) {
		return AITown.GetAllowedNoise(town) >= AIAirport.GetNoiseLevelIncrease(GetLocation() + GetRadius(), airportType);
	}
	
}
