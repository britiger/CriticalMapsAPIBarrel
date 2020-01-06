using Toybox.Application;
using Toybox.System;
using Toybox.Position;
using Toybox.Time;
using Toybox.Communications;
using Toybox.Math;
using Toybox.Lang;

(:background)
module CriticalMapsAPIBarrel {
 
    const BASEURL = "https://api.criticalmaps.net/";

    var lastResponse = -1;
    var numResponse = 0;
    var lastLocation = {};
    var nearestCM = 0;
    var countCM10 = 0;
    var chatText = "";
    
    function getDeviceId() {
    	var propDeviceId = "";
    	try {
        	propDeviceId =  Application.Properties.getValue("deviceId");
        } catch (e instanceof Lang.Exception) {
        	System.println("Need to define Property deviceId in your Application");
        	propDeviceId = "";
        }
        if (propDeviceId == null || propDeviceId.equals("")) {
            // need initalisation
            // call in non-background for inital set value
            // setValue is not possible in background
            var mySettings = System.getDeviceSettings();
            propDeviceId = mySettings.uniqueIdentifier;
            try {
            	Application.Properties.setValue("deviceId", propDeviceId);
            } catch (e instanceof Application.ObjectStoreAccessException) {
            	System.println("Need to set deviceId in app or view.");
            }
        }
        return propDeviceId;
    }
    
    function sendPositionData(callbackMethod) {
        var url = BASEURL + "postv2";
    
        var positionInfo = Position.getInfo();    	
        if (positionInfo.accuracy < Position.QUALITY_POOR) {
            // Location not good enough
            return -1; // use last position
        }
        var myLocation = positionInfo.position.toDegrees();
        System.println("Latitude: " + myLocation[0]); 
        System.println("Longitude: " + myLocation[1]); 
        System.println("Accu: " + positionInfo.accuracy);    

        if (myLocation[0] >= 179 || (myLocation[0] == 0 && myLocation[1] == 0)){
            return -2;
        }
        var location =  {
            "latitude" => myLocation[0]*1000000,
            "longitude" => myLocation[1]*1000000
        };
        lastLocation = location;
        var parms = {
            "location" => location,
            "device" => getDeviceId()
        };
        // parms = {}; // For TESTing, don't send
        var options = {                                             // set the options
           :method => Communications.HTTP_REQUEST_METHOD_POST,      // set HTTP method
           :headers => {                                            // set headers
                   "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON},
                                                                    // set response type
           :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
           };
        Communications.makeWebRequest(url, parms, options, callbackMethod);
        return 0;
    }
    
    function callbackCM(responseCode, data) {
        System.println("Response: " + responseCode);
        lastResponse = responseCode;
        numResponse += 1; 
        if (responseCode == 200) {
            System.println("Data: " + data);
            // Check Structure of response
            if(data instanceof Toybox.Lang.Dictionary && data.hasKey("locations")) {
                parseData(data);
            }
        }
        return {"responseCode" => responseCode, "nearestCM" => nearestCM, "countCM10" => countCM10, "chatText" => chatText};
    }
    
    function parseData(data) {		
        var locations = data["locations"];
        var devices = locations.keys();
        var nearest = 9999;
        var count10 = 0;
        for( var i = 0; i < devices.size(); i += 1 ) {
            var entry = locations.get(devices[i]);
            
            var dist = distanceToLastLocation(entry["latitude"], entry["longitude"]);
            nearest = MathMin(nearest, dist);
            if (dist < 10) { // TODO: Should be configurable
                count10 += 1;
            }
        }
        nearestCM = nearest;
        countCM10 = count10;
        parseChat(data);
    }
    
    function parseChat(data) {
        if(data.hasKey("chatMessages") && data["chatMessages"] instanceof Toybox.Lang.Dictionary && data["chatMessages"].size()>0){
            var msgs = data["chatMessages"].keys().reverse();
            if(data["chatMessages"][msgs[0]].hasKey("message")) {
                chatText = data["chatMessages"][msgs[0]]["message"];
            } else {
                chatText = "";
            }
            chatText = stringReplace(chatText, "+", " ");
            chatText = stringReplace(chatText, "%3F", "?"); // TODO: Generic translate for %
            System.println("Last Chat: " + chatText);
        } else {
            chatText = "";
        } 
    }
    
    function distanceToLastLocation(lat2, lon2) {
        // TODO: Check values
        var lat1 = lastLocation["latitude"]/1000000.0;
        var lon1 = lastLocation["longitude"]/1000000.0;
        lat2 = lat2/1000000.0;
        lon2 = lon2/1000000.0;

        // source: https://stackoverflow.com/a/21623206
          var p = 0.017453292519943295;    // Math.PI / 180
        var a = 0.5 - Math.cos((lat2 - lat1) * p)/2 + 
                  Math.cos(lat1 * p) * Math.cos(lat2 * p) * 
                  (1 - Math.cos((lon2 - lon1) * p))/2;

          return 12742 * Math.asin(Math.sqrt(a)); // 2 * R; R = 6371 km
      }
      
      function stringReplace(str, find, replace) {
          var result = str;

        while (true) {
            var index = result.find(find);
    
            if (index != null) {
                var index2 = index+find.length();
                result = result.substring(0, index) + replace + result.substring(index2, result.length());
            } else {
                return result;
            }
        }

        return null; 
      }

    function MathMin(val1, val2) {
        return val1<val2 ? val1 : val2;
    }
}
