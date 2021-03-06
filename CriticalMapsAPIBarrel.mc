using Toybox.Application;
using Toybox.System;
using Toybox.Position;
using Toybox.Time;
using Toybox.Cryptography;
using Toybox.Communications;
using Toybox.Math;
using Toybox.Lang;
using Toybox.StringUtil;
using Toybox.WatchUi;

(:background)
module CriticalMapsAPIBarrel {
 
    const BASEURL = "https://api.criticalmaps.net/";
    const INVALID_NEAREST = 9999;
    const INVALID_DISTANCE = 9999;

    var lastResponse = -1;
    var lastLocation = {};
    var nearestCM = 0;
    var countCM10 = 0;
    var chatText = "";
    var deviceIdHash = "";
    var mapMarkers = [];

    function getDeviceId() {
        if (!deviceIdHash.equals("")) {
            return deviceIdHash;
        }
        if(Toybox has :Cryptography) {
            System.println("Device have Cryptography.");
        } else {
            // Compatibilty mode for old devices
            // Use same deviceId every day
            System.println("Device have no Cryptography! Use DeviceId only.");
            deviceIdHash = getDeviceIdRaw();
            return deviceIdHash;
        }
        
        var hashValue = new Cryptography.Hash({:algorithm => Cryptography.HASH_MD5});
        var deviceId = getDeviceIdRaw() + Time.today().value();
        var byteA = StringUtil.convertEncodedString(deviceId, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT, 
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY });
            
        hashValue.update(byteA);
        deviceIdHash = StringUtil.convertEncodedString(hashValue.digest(), {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX });
        return deviceIdHash;
    }
    
    function getDeviceIdRaw() {
        // Get non hashed deviceId
        var propDeviceId = "";
        try {
            propDeviceId =  Application.Properties.getValue("deviceId");
        } catch (e instanceof Lang.Exception) {
            System.println("Need to define Property deviceId in your Application");
            propDeviceId = "";
        }
        if (propDeviceId == null || propDeviceId.equals("")) {
            // initalisation of application property
            // need to call in non-background for inital set value
            // setValue is not possible in background!
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
    
        var positionInfo = Position.getInfo(); // get current Postion
        // Check position
        if (positionInfo.accuracy < Position.QUALITY_POOR) {
            // Location not good enough
            return -1; // use last position
        }
        var myLocation = positionInfo.position.toDegrees();
        System.println("Latitude: " + myLocation[0]); 
        System.println("Longitude: " + myLocation[1]); 
        System.println("Accu: " + positionInfo.accuracy);    

        // Check Position can be real or it's only a dummy
        if (myLocation[0] >= 179 || (myLocation[0] == 0 && myLocation[1] == 0)){
            return -2;
        }
        var location =  {
            "latitude" => myLocation[0]*1000000,
            "longitude" => myLocation[1]*1000000
        };
        // save valid location
        lastLocation = location;
        // setting parameters for sending to critical maps api
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
        if(callbackMethod == null) {
            callbackMethod = new Lang.Method(CriticalMapsAPIBarrel, :onReceive);
        }
        Communications.makeWebRequest(url, parms, options, callbackMethod);
        return 0;
    }
    
    function callbackCM(responseCode, data) {
        System.println("Response: " + responseCode);
        lastResponse = responseCode;
        mapMarkers = [];
        if (responseCode == 200) {
            System.println("Data: " + data);
            // Check Structure of response
            if(data instanceof Toybox.Lang.Dictionary && data.hasKey("locations")) {
                parseData(data);
            }
        }
        return {"responseCode" => responseCode, "nearestCM" => nearestCM, "countCM10" => countCM10, "chatText" => chatText, "mapMarkers" => mapMarkers};
    }
    
    // dummy-callback function
    function onReceive(responseCode, data) {
       if (responseCode == 200) {
           System.println("Request Successful");                   // print success
       }
       else {
           System.println("Response: " + responseCode);            // print response code
       }
    }

    function parseData(data) {
        var locations = data["locations"];
        var devices = locations.keys();
        var nearest = INVALID_NEAREST;
        var count10 = 0;
        for( var i = 0; i < devices.size(); i += 1 ) {
            var entry = locations.get(devices[i]);
            
            var dist = distanceToLastLocation(entry["latitude"], entry["longitude"]);
            nearest = MathMin(nearest, dist);
            if (dist < 10) { // TODO: Should be configurable
                count10 += 1;
            }
            // Add location to list of marker
            mapMarkers.add(new WatchUi.MapMarker(
                new Position.Location({
                    :latitude  => entry["latitude"]/1000000.0,
                    :longitude => entry["longitude"]/1000000.0,
                    :format => :degrees
                })
              )
            );
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
        // Check lastLocation
        if (lastLocation.isEmpty() || 
                !lastLocation.hasKey("latitude") || 
                !lastLocation.hasKey("longitude") ||
                !(lastLocation["latitude"] instanceof Lang.Number || lastLocation["latitude"] instanceof Lang.Float || lastLocation["latitude"] instanceof Lang.Double) || 
                !(lastLocation["longitude"] instanceof Lang.Number || lastLocation["longitude"] instanceof Lang.Float || lastLocation["longitude"] instanceof Lang.Double)) {
            return INVALID_DISTANCE;
        }
        // Check lat2 / lon2 input
        if (lat2 == null || !(lat2 instanceof Lang.Number || lat2 instanceof Lang.Float || lat2 instanceof Lang.Double) ||
                lon2 == null || !(lon2 instanceof Lang.Number || lon2 instanceof Lang.Float || lon2 instanceof Lang.Double)) {
            return INVALID_DISTANCE;
        }

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
