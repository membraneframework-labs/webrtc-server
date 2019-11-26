const webSocketUrl = "wss://" + window.location.host + "/server/";
var webSocket;
var localStream;
var rtcConnections = {};
const offerOptions = {
    offerToReceiveAudio: 1,
    offerToReceiveVideo: 1
};

const rtcConfig = {
    // iceServers: [
    //     urls: [
    //         YOUR TURN AND STUN URL
    //     ]
    // }]
};

function startLocalVideo() {
    navigator.getUserMedia(
        {audio: true, video: true},
        (stream) => {setupLocalVideo(stream); openConnection();}, 
        (e) => {alert(e)});
}

startLocalVideo();

function setupLocalVideo(stream) {
    setupVideo("local", stream);
    localStream = stream;
    document.getElementById("local").muted = true;
}

function setupVideo(id, stream) {
    if(!document.getElementById(id)) {
        var template = document.querySelector("#template");
        var child = document.importNode(template.content, true);
        child.querySelector("video").id = id; 
        document.getElementById("videochat").appendChild(child);
    }
    document.getElementById(id).srcObject = stream;
} 

function openConnection() {
    socket = new WebSocket(webSocketUrl);
    socket.onopen = socketOpen;
    socket.onmessage = socketMessage;
    socket.onclose = socketClose;
}

function socketOpen(event) {
    console.log("Starting WebSocket connection.");
}

function socketClose(event) {
   console.log("Closing WebSocket connection.");
}

function onAnswer(data, from) {
    console.log("Got answer from " + from);
    rtcConnections[from].setRemoteDescription(data);
}

function onAuthenticated(data, from) {
    console.log("Authenticated.");
}

function onError(data, from) {
    console.dir(data);
}

function onJoined(data, from) {
    let peer_id = data.peer_id;
    console.log(peer_id + " joined.");
    startRTCConnection(peer_id);
    rtcConnections[peer_id].createOffer(
        getHandleDescription(peer_id, "offer"),
        console.dir, 
        offerOptions
    );    
}

function onCandidateMessage(data, from) {
    console.log("Got candidate from " + from, data);
    try {
        var candidate = new RTCIceCandidate(data);
        rtcConnections[from].addIceCandidate(candidate);
    } catch (e) {
        console.dir(e);
    } 
}

function onLeft(data, from) {
    console.log(data.peer_id + " left.");
    delete rtcConnections[data.peer_id];
    var videoElement = document.getElementById(data.peer_id);
    videoElement.parentNode.removeChild(videoElement);
}

function onOffer(data, from) {
    console.log("Got offer from " + from, data);
    startRTCConnection(from);
    let connection = rtcConnections[from];
    connection.setRemoteDescription(data) 
    connection.createAnswer(
        getHandleDescription(from, "answer"),
        console.dir,
    );    
}

const messageEventListeners = {
    answer: onAnswer,
    authenticated: onAuthenticated,
    candidate: onCandidateMessage,
    error: onError,
    joined: onJoined,
    left: onLeft,
    offer: onOffer
};

function socketMessage(event) {
    message = JSON.parse(event.data);
    messageEventListeners[message.event](message.data, message.from);
}

function startRTCConnection(peer_id) {
    let connection = new RTCPeerConnection(rtcConfig);
    connection.addStream(localStream);
    connection.onicecandidate = getOnIceCandidate(peer_id);
    connection.ontrack = getHandleTrack(peer_id);
    rtcConnections[peer_id] = connection;
}

function getHandleTrack(peer_id) {
    return (event) => {setupVideo(peer_id, event.streams[0]);};
}

function getOnIceCandidate(peer_id) {
    return function (event) {
        if(event.candidate != null) {
            var message = {to: [peer_id], event: "candidate", data: event.candidate};
            socket.send(JSON.stringify(message));
        }
    }
}

function getHandleDescription(peer_id, event) {
    return function(description) {
        rtcConnections[peer_id].setLocalDescription(description);
        message = {to: [peer_id], event: event, data: description};
        socket.send(JSON.stringify(message));
    }
}
