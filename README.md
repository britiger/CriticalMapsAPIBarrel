Monkey C Barrel for CriticalMaps API
====================================

This barrel give you some function to communicate with the API [CriticalMaps](https://www.criticalmaps.net/) and is build for Garmin Edge devices. After sending your position 

If you use the barrel as a background service for a DataField you will only be able to send a position every 5 minutes. This limitation is for saving battery of the devices. If you use this barrel for a widget you don't have this limitation. The suggested interval for sending the position is about 30 seconds. When using more than one DataField or Widget on same device at same time, pay attention that every application have an own unique id and you will get a different hash and you will get 2 positions on the map. See the implementations how to reuse one of unique ids for the other application using the Properties which you can change in the Connect App if you app installed via the official store (non-public beta should be also work).

The following applications using the barrel:
  - DataField: [PauseTimer](https://github.com/britiger/PauseTimer-connectiq-cm) with background service, you don't see anything of CriticalMaps
  - Widget: [CriticalMaps Widget](https://github.com/britiger/criticalmaps-garmin-widget) show next 

Restrictions:
  - Due to limitations of memory within the devices, you'll get a `responseCode` of `-402` if there are more than 100 positions. In this case your position was send correctly to CriticalMaps.
  - If you use this Barrel with an device only support SDK version older than 3.0.0 you always have the same hash (deviceId) every day. E.g. Edge 1000 (supports only up to 2.4.0)