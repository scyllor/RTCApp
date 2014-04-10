package org.rtc.servlet;

import java.io.IOException;
import java.util.UUID;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.lang.StringUtils;
import org.rtc.room.WebRTCRoomManager;

@WebServlet(urlPatterns = {"/room"})
public class WebRTCRoomServlet extends HttpServlet {

	private static final long serialVersionUID = 1L;
	
	public void doGet(HttpServletRequest request, HttpServletResponse response)
			throws ServletException, IOException {
		this.doPost(request, response);
	}

	public void doPost(HttpServletRequest request, HttpServletResponse response)
			throws ServletException, IOException {
		String r = request.getParameter("r");
		if(StringUtils.isEmpty(r)){
			//如果房间为空，则生成一个新的房间号
			r = String.valueOf(System.currentTimeMillis());
			response.sendRedirect("room?r=" + r);
		}else{
			Integer initiator = 1;
			String user = UUID.randomUUID().toString().replace("-", "");//生成一个用户ID串
			if(!WebRTCRoomManager.haveUser(r)){//第一次进入可能是没有人的，所以就要等待连接，如果有人进入了带这个房间好的页面就会发起视频通话的连接
				initiator = 0;//如果房间没有人则不发送连接的请求
			}
			WebRTCRoomManager.addUser(r, user);//向房间中添加一个用户
			String roomLink = request.getScheme()+"://"+request.getServerName()+":"+request.getServerPort() +  request.getContextPath() +"/room?r=" + r;
			String roomKey = r;//设置一些变量
			request.setAttribute("initiator", initiator);
			request.setAttribute("roomLink", roomLink);
			request.setAttribute("roomKey", roomKey);
			request.setAttribute("user", user);
			request.getRequestDispatcher("index.jsp").forward(request, response);
		}
	}
}
