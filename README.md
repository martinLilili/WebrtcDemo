webrtcDemo，实现了两台手机在局域网视频通信的功能


使用方法：

准备两台手机A和B，连接相同局域网

修改Demo的IP和端口号，并分别运行于A和B

	struct SocketModel {
	    static let targetHost = B的IP
	    static let targetPort : UInt16 = B监听的端口号
	}

B点击开启监听

A点击发起offer

如上即可实现A和B通信


文档地址：[WebRTCDemo](http://moonlspace.com/2016/12/WebRTCDemo/)