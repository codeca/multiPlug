"use strict"
// All configurations in the server side
module.exports = {
	// External host to save your local ip
	// sitegui.com.br will work for free
	externalHost: "http://sitegui.com.br/multiPlug",
	
	// Your app identifier, as shown by [[NSBundle mainBundle] bundleIdentifier]
	bundleIdentifier: "company.app",
	
	// Port to listen to
	port: 8081,
	
	// Show information about connections and matching in the console
	logConnections: true,
	
	// Show information about broadcasts in the console
	logBroadcasts: false,
	
	// Minimum number of player to form a match
	minPlayers: 2,
	
	// Maximum number of player to form a match
	maxPlayers: 4,
	
	// Executed when the server is up and running
	onstart: function () {
	},
	
	// Executed when a match is found
	// data is the object that will be broadcasted to all players
	// It contains only a property, "players":
	// an array of elements with the format {name: "", id: ""}
	// This callback can put more fields in this object, to return more data to all players 
	onmatch: function (data) {
	}
}
