package org.rtc.servlet;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

import javax.servlet.ServletException;
import javax.servlet.ServletInputStream;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import net.sf.json.JSONObject;

import org.rtc.room.WebRTCRoomManager;
import org.rtc.websocket.WebRTCMessageInboundPool;

@WebServlet(urlPatterns = {"/message"})
public class WebRTCMessageServlet extends HttpServlet {

	private static final long serialVersionUID = 1L;

	public void doGet(HttpServletRequest request, HttpServletResponse response)
			throws ServletException, IOException {
		super.doPost(request, response);
	}

	public void doPost(HttpServletRequest request, HttpServletResponse response)
			throws ServletException, IOException {
		String r = request.getParameter("r");//房间号
		String u = request.getParameter("u");//通话人
	    BufferedReader br = request.getReader();
        String line = null;
        StringBuilder sb = new StringBuilder();
        while((line = br.readLine())!=null){
            sb.append(line); //获取输入流，主要是视频定位的信息
        }
		
		String message = sb.toString();
		JSONObject json = JSONObject.fromObject(message);
		if (json != null) {
			String type = json.getString("type");
			if ("bye".equals(type)) {//客户端退出视频聊天
				System.out.println("user :" + u + " exit..");
				WebRTCRoomManager.removeUser(r, u);
			}
		}
		String otherUser = WebRTCRoomManager.getOtherUser(r, u);//获取通话的对象
		if (u.equals(otherUser)) {
			message = message.replace("\"offer\"", "\"answer\"");
			message = message.replace("a=crypto:0 AES_CM_128_HMAC_SHA1_32",
					"a=xrypto:0 AES_CM_128_HMAC_SHA1_32");
			message = message.replace("a=ice-options:google-ice\\r\\n", "");
		}
		//向对方发送连接数据
		WebRTCMessageInboundPool.sendMessage(otherUser, message);
	}
}
