<%@ page language="java" pageEncoding="UTF-8"%>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<%
	String ctx = request.getContextPath() + "/";
	pageContext.setAttribute("ctx", ctx);
%>
<html>
<head>
<link rel="canonical" href="${roomLink}" />
<meta http-equiv="X-UA-Compatible" content="chrome=1" />
<script src="js/channel.js"></script>
<!-- type="text/javascript">
  (function() {
    var po = document.createElement('script'); po.type = 'text/javascript'; po.async = true;
    po.src = 'js/plusone.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);
  })();
-->
<link rel="stylesheet" type="text/css" href="css/style.css" />
</head>
<body>
	<script type="text/javascript">
		var localVideo;
		var miniVideo;
		var remoteVideo;
		var localStream;
		var remoteStream;
		var channel;
		var channelReady = false;
		var pc;
		var socket;
		var initiator = ${initiator};
		var started = false;
		var isRTCPeerConnection = true;
		var mediaConstraints = {
			'has_audio' : true,
			'has_video' : true
		};
		var isVideoMuted = false;
		var isAudioMuted = false;

		function initialize() {
			console.log("Initializing; room=${roomKey}.");
			card = document.getElementById("card");
			localVideo = document.getElementById("localVideo");
			miniVideo = document.getElementById("miniVideo");
			remoteVideo = document.getElementById("remoteVideo");
			resetStatus();
			openChannel();
			getUserMedia();
		}
		
		function getUserMedia() {
			try {
				navigator.webkitGetUserMedia({
					'audio' : true,
					'video' : true
				}, onUserMediaSuccess, onUserMediaError);
				console.log("Requested access to local media with new syntax.");
			} catch (e) {
				try {
					navigator.webkitGetUserMedia("video,audio",
							onUserMediaSuccess, onUserMediaError);
					console
							.log("Requested access to local media with old syntax.");
				} catch (e) {
					alert("webkitGetUserMedia() failed. Is the MediaStream flag enabled in about:flags?");
					console.log("webkitGetUserMedia failed with exception: "
							+ e.message);
				}
			}
		}
		
		function onUserMediaSuccess(stream) {
			console.log("User has granted access to local media.");
			var url = webkitURL.createObjectURL(stream);
			localVideo.style.opacity = 1;
			localVideo.src = url;
			localStream = stream;
			// Caller creates PeerConnection.
			if (initiator)
				maybeStart();
		}
		
		function maybeStart() {
			if (!started && localStream && channelReady) {
				setStatus("连接中...");
				console.log("Creating PeerConnection.");
				createPeerConnection();
				console.log("Adding local stream.");
				pc.addStream(localStream);
				started = true;
				// Caller initiates offer to peer.
				if (initiator)
					doCall();
			}
		}

		function doCall() {
			console.log("Sending offer to peer.");
			if (isRTCPeerConnection) {
				pc.createOffer(setLocalAndSendMessage, null, mediaConstraints);
			} else {
				var offer = pc.createOffer(mediaConstraints);
				pc.setLocalDescription(pc.SDP_OFFER, offer);
				sendMessage({
					type : 'offer',
					sdp : offer.toSdp()
				});
				pc.startIce();
			}
		}

		function setLocalAndSendMessage(sessionDescription) {
			pc.setLocalDescription(sessionDescription);
			sendMessage(sessionDescription);
		}

		function sendMessage(message) {
			var msgString = JSON.stringify(message);
			console.log('发出信息 : ' + msgString);
			path = 'message?r=${roomKey}' + '&u=${user}';
			var xhr = new XMLHttpRequest();
			xhr.open('POST', path, true);
			xhr.send(msgString);
		}

		function openChannel() {
			console.log("Opening channel.");
			socket = new WebSocket(
					"ws://"+window.location.host+"${ctx}websocket?u=${user}");
			socket.onopen = onChannelOpened;
			socket.onmessage = onChannelMessage;
			socket.onclose = onChannelClosed;
		}

		function resetStatus() {
			if (!initiator) {
				setStatus("让别人加入视频聊天: <a href=\"${roomLink}\">${roomLink}</a>");
			} else {
				setStatus("初始化...");
			}
		}

		function createPeerConnection() {
			var pc_config = {
				"iceServers" : [ {
					"url" : "stun:stun.l.google.com:19302"
				} ]
			};
			try {
				pc = new webkitRTCPeerConnection(pc_config);
				pc.onicecandidate = onIceCandidate;
				console.log("Created webkitRTCPeerConnnection with config \""
						+ JSON.stringify(pc_config) + "\".");
			} catch (e) {
				try {
					var stun_server = "";
					if (pc_config.iceServers.length !== 0) {
						stun_server = pc_config.iceServers[0].url.replace(
								'stun:', 'STUN ');
					}
					pc = new webkitPeerConnection00(stun_server,
							onIceCandidate00);
					isRTCPeerConnection = false;
					console
							.log("Created webkitPeerConnnection00 with config \""
									+ stun_server + "\".");
				} catch (e) {
					console.log("Failed to create PeerConnection, exception: "
							+ e.message);
					alert("Cannot create PeerConnection object; Is the 'PeerConnection' flag enabled in about:flags?");
					return;
				}
			}

			pc.onconnecting = onSessionConnecting;
			pc.onopen = onSessionOpened;
			pc.onaddstream = onRemoteStreamAdded;
			pc.onremovestream = onRemoteStreamRemoved;
		}

		function setStatus(state) {
			footer.innerHTML = state;
		}

		function doAnswer() {
			console.log("Sending answer to peer.");
			if (isRTCPeerConnection) {
				pc.createAnswer(setLocalAndSendMessage, null, mediaConstraints);
			} else {
				var offer = pc.remoteDescription;
				var answer = pc.createAnswer(offer.toSdp(), mediaConstraints);
				pc.setLocalDescription(pc.SDP_ANSWER, answer);
				sendMessage({
					type : 'answer',
					sdp : answer.toSdp()
				});
				pc.startIce();
			}
		}

		function processSignalingMessage00(message) {
			var msg = JSON.parse(message);

			// if (msg.type === 'offer') should not happen here.
			if (msg.type === 'answer' && started) {
				pc.setRemoteDescription(pc.SDP_ANSWER, new SessionDescription(
						msg.sdp));
			} else if (msg.type === 'candidate' && started) {
				var candidate = new IceCandidate(msg.label, msg.candidate);
				pc.processIceMessage(candidate);
			} else if (msg.type === 'bye' && started) {
				onRemoteHangup();
			}
		}

		var channelOpenTime;
		var channelCloseTime;

		function onChannelOpened() {
			channelOpenTime = new Date();
			console.log("Channel opened.Open time is : "
					+ channelOpenTime.toLocaleString());
			channelReady = true;
			if (initiator)
				maybeStart();
		}
		function onChannelMessage(message) {
			console.log('收到信息 : ' + message.data);
			if (isRTCPeerConnection)
				processSignalingMessage(message.data);//建立视频连接
			else
				processSignalingMessage00(message.data);
		}
		
		function processSignalingMessage(message) {
			var msg = JSON.parse(message);

			if (msg.type === 'offer') {
				// Callee creates PeerConnection
				if (!initiator && !started)
					maybeStart();

				// We only know JSEP version after createPeerConnection().
				if (isRTCPeerConnection)
					pc.setRemoteDescription(new RTCSessionDescription(msg));
				else
					pc.setRemoteDescription(pc.SDP_OFFER,
							new SessionDescription(msg.sdp));

				doAnswer();
			} else if (msg.type === 'answer' && started) {
				pc.setRemoteDescription(new RTCSessionDescription(msg));
			} else if (msg.type === 'candidate' && started) {
				var candidate = new RTCIceCandidate({
					sdpMLineIndex : msg.label,
					candidate : msg.candidate
				});
				pc.addIceCandidate(candidate);
			} else if (msg.type === 'bye' && started) {
				onRemoteHangup();
			}
		}
		
		function onChannelError() {
			console.log('Channel error.');
		}
		function onChannelClosed() {
			if(!channelOpenTime){
				channelOpenTime = new Date();
			}
			channelCloseTime = new Date();
			console
					.log("Channel closed.Close time is "
							+ channelOpenTime.toLocaleString()
							+ " ,Keep time : "
							+ ((channelCloseTime.getTime() - channelOpenTime
									.getTime()) / 1000 + "s"));
			openChannel();
		}

		function onUserMediaError(error) {
			console.log("Failed to get access to local media. Error code was "
					+ error.code);
			alert("Failed to get access to local media. Error code was "
					+ error.code + ".");
		}

		function onIceCandidate(event) {
			if (event.candidate) {
				sendMessage({
					type : 'candidate',
					label : event.candidate.sdpMLineIndex,
					id : event.candidate.sdpMid,
					candidate : event.candidate.candidate
				});
			} else {
				console.log("End of candidates.");
			}
		}

		function onIceCandidate00(candidate, moreToFollow) {
			if (candidate) {
				sendMessage({
					type : 'candidate',
					label : candidate.label,
					candidate : candidate.toSdp()
				});
			}

			if (!moreToFollow) {
				console.log("End of candidates.");
			}
		}

		function onSessionConnecting(message) {
			console.log("Session connecting.");
		}
		function onSessionOpened(message) {
			console.log("Session opened.");
		}

		function onRemoteStreamAdded(event) {
			console.log("Remote stream added.");
			var url = webkitURL.createObjectURL(event.stream);
			miniVideo.src = localVideo.src;
			remoteVideo.src = url;
			remoteStream = event.stream;
			waitForRemoteVideo();
		}
		function onRemoteStreamRemoved(event) {
			console.log("Remote stream removed.");
		}

		function onHangup() {
			console.log("Hanging up.");
			transitionToDone();
			stop();
			socket.close();

		}

		function onRemoteHangup() {
			console.log('Session terminated.');
			transitionToWaiting();
			stop();
			initiator = 0;
		}

		function stop() {
			started = false;
			isRTCPeerConnection = true;
			isAudioMuted = false;
			isVideoMuted = false;
			pc.close();
			pc = null;
		}

		function waitForRemoteVideo() {
			if (remoteStream.videoTracks.length === 0
					|| remoteVideo.currentTime > 0) {
				transitionToActive();
			} else {
				setTimeout(waitForRemoteVideo, 100);
			}
		}
		function transitionToActive() {
			remoteVideo.style.opacity = 1;
			card.style.webkitTransform = "rotateY(180deg)";
			setTimeout(function() {
				localVideo.src = "";
			}, 500);
			setTimeout(function() {
				miniVideo.style.opacity = 1;
			}, 1000);
			setStatus("<input type=\"button\" id=\"hangup\" value=\"Hang up\" onclick=\"onHangup()\" />");
		}
		function transitionToWaiting() {
			card.style.webkitTransform = "rotateY(0deg)";
			setTimeout(function() {
				localVideo.src = miniVideo.src;
				miniVideo.src = "";
				remoteVideo.src = ""
			}, 500);
			miniVideo.style.opacity = 0;
			remoteVideo.style.opacity = 0;
			resetStatus();
		}
		function transitionToDone() {
			localVideo.style.opacity = 0;
			remoteVideo.style.opacity = 0;
			miniVideo.style.opacity = 0;
			setStatus("You have left the call. <a href=\"{{ room_link }}\">Click here</a> to rejoin.");
		}
		function enterFullScreen() {
			container.webkitRequestFullScreen();
		}

		function toggleVideoMute() {
			if (localStream.videoTracks.length === 0) {
				console.log("No local video available.");
				return;
			}

			if (isVideoMuted) {
				for (i = 0; i < localStream.videoTracks.length; i++) {
					localStream.videoTracks[i].enabled = true;
				}
				console.log("Video unmuted.");
			} else {
				for (i = 0; i < localStream.videoTracks.length; i++) {
					localStream.videoTracks[i].enabled = false;
				}
				console.log("Video muted.");
			}

			isVideoMuted = !isVideoMuted;
		}

		function toggleAudioMute() {
			if (localStream.audioTracks.length === 0) {
				console.log("No local audio available.");
				return;
			}

			if (isAudioMuted) {
				for (i = 0; i < localStream.audioTracks.length; i++) {
					localStream.audioTracks[i].enabled = true;
				}
				console.log("Audio unmuted.");
			} else {
				for (i = 0; i < localStream.audioTracks.length; i++) {
					localStream.audioTracks[i].enabled = false;
				}
				console.log("Audio muted.");
			}

			isAudioMuted = !isAudioMuted;
		}

		setTimeout(initialize, 1);

		// Send BYE on refreshing(or leaving) a demo page
		// to ensure the room is cleaned for next session.
		window.onbeforeunload = function() {
			sendMessage({
				type : 'bye'
			});
		}

		// Ctrl-D: toggle audio mute; Ctrl-E: toggle video mute.
		// On Mac, Command key is instead of Ctrl.
		// Return false to screen out original Chrome shortcuts.
		document.onkeydown = function() {
			if (navigator.appVersion.indexOf("Mac") != -1) {
				if (event.metaKey && event.keyCode === 68) {
					toggleAudioMute();
					return false;
				}
				if (event.metaKey && event.keyCode === 69) {
					toggleVideoMute();
					return false;
				}
			} else {
				if (event.ctrlKey && event.keyCode === 68) {
					toggleAudioMute();
					return false;
				}
				if (event.ctrlKey && event.keyCode === 69) {
					toggleVideoMute();
					return false;
				}
			}
		}
	</script>
	<div id="container" ondblclick="enterFullScreen()">
		<div id="card">
			<div id="local">
				<video width="100%" height="100%" id="localVideo"
					autoplay="autoplay" />
			</div>
			<div id="remote">
				<video width="100%" height="100%" id="remoteVideo"
					autoplay="autoplay"> </video>
				<div id="mini">
					<video width="100%" height="100%" id="miniVideo"
						autoplay="autoplay" />
				</div>
			</div>
		</div>
		<div id="footer"></div>
		<a href="http://www.webrtc.org"> <img id="logo" alt="WebRTC"
			src="${ctx}images/webrtc_black_20p.png"> </a>
	</div>
</body>
</html>
