module("luci.passwall.util_hysteria", package.seeall)
local api = require "luci.passwall.api"
local uci = api.uci
local jsonc = api.jsonc

function gen_config_server(node)
	local config = {
		listen = ":" .. node.port,
		protocol = node.protocol or "udp",
		obfs = node.hysteria_obfs,
		cert = node.tls_certificateFile,
		key = node.tls_keyFile,
		auth = (node.hysteria_auth_type == "string") and {
			mode = "password",
			config = {
				password = node.hysteria_auth_password
			}
		} or nil,
		disable_udp = (node.hysteria_udp == "0") and true or false,
		alpn = node.hysteria_alpn or nil,
		up_mbps = tonumber(node.hysteria_up_mbps) or 10,
		down_mbps = tonumber(node.hysteria_down_mbps) or 50,
		recv_window_conn = (node.hysteria_recv_window_conn) and tonumber(node.hysteria_recv_window_conn) or nil,
		recv_window = (node.hysteria_recv_window) and tonumber(node.hysteria_recv_window) or nil,
		disable_mtu_discovery = (node.hysteria_disable_mtu_discovery) and true or false
	}
	return config
end

function gen_config(var)
	local node_id = var["-node"]
	if not node_id then
		print("-node 不能为空")
		return
	end
	local node = uci:get_all("passwall", node_id)
	local local_tcp_redir_port = var["-local_tcp_redir_port"]
	local local_udp_redir_port = var["-local_udp_redir_port"]
	local local_socks_address = var["-local_socks_address"] or "0.0.0.0"
	local local_socks_port = var["-local_socks_port"]
	local local_socks_username = var["-local_socks_username"]
	local local_socks_password = var["-local_socks_password"]
	local local_http_address = var["-local_http_address"] or "0.0.0.0"
	local local_http_port = var["-local_http_port"]
	local local_http_username = var["-local_http_username"]
	local local_http_password = var["-local_http_password"]
	local tcp_proxy_way = var["-tcp_proxy_way"]
	local server_host = var["-server_host"] or node.address
	local server_port = var["-server_port"] or node.port

	if api.is_ipv6(server_host) then
		server_host = api.get_ipv6_full(server_host)
	end
	local server = server_host .. ":" .. server_port

	if (node.hysteria_hop) then
		server = server .. "," .. node.hysteria_hop
	end

	local config = {
		server = server,
		protocol = node.protocol or "udp",
		obfs = (node.hysteria_obfs) and {
			type = "salamander",
			salamander = {
				password = node.hysteria_obfs
			}
		},
		auth = (node.hysteria_auth_type == "base64") and node.hysteria_auth_password or nil,
		auth_str = (node.hysteria_auth_type == "string") and node.hysteria_auth_password or nil,
		alpn = node.hysteria_alpn or nil,
		server_name = node.tls_serverName,
		insecure = (node.tls_allowInsecure == "1") and true or false,
		bandwidth = {
			up = (tonumber(node.hysteria_up_mbps) or 10) .. " mbps",
			down = (tonumber(node.hysteria_down_mbps) or 50) .. " mbps"
		},
		retry = -1,
		retry_interval = 5,
		quic = (node.hysteria_recv_window_conn or node.hysteria_recv_window) and {
			initStreamReceiveWindow = (node.hysteria_recv_window) and tonumber(node.hysteria_recv_window) or nil,
			maxStreamReceiveWindow = (node.hysteria_recv_window) and tonumber(node.hysteria_recv_window) or nil,
		      	initConnReceiveWindow = (node.hysteria_recv_window_conn) and tonumber(node.hysteria_recv_window_conn) or nil,
		      	maxConnReceiveWindow = (node.hysteria_recv_window_conn) and tonumber(node.hysteria_recv_window_conn) or nil,
			maxIdleTimeout = (node.hysteria_idle_timeout) and (tonumber(node.hysteria_idle_timeout) .. "s") or nil,
			disablePathMTUDiscovery = (node.hysteria_disable_mtu_discovery) and true or false
		} or nil,
		recv_window_conn = (node.hysteria_recv_window_conn) and tonumber(node.hysteria_recv_window_conn) or nil,
		recv_window = (node.hysteria_recv_window) and tonumber(node.hysteria_recv_window) or nil,
		handshake_timeout = (node.hysteria_handshake_timeout) and tonumber(node.hysteria_handshake_timeout) or nil,
		transport = (node.hysteria_hop_interval) and {
			type = "udp",
			udp = {
				hop_interval = tonumber(node.hysteria_hop_interval) .. "s"
			}
		} or nil,
		fastOpen = (node.fast_open == "1") and true or false,
		lazy = (node.hysteria_lazy_start) and true or false,
		socks5 = (local_socks_address and local_socks_port) and {
			listen = local_socks_address .. ":" .. local_socks_port,
			timeout = 300,
			disableUDP = false,
			username = (local_socks_username and local_socks_password) and local_socks_username,
			password = (local_socks_username and local_socks_password) and local_socks_password,
		} or nil,
		http = (local_http_address and local_http_port) and {
			listen = local_http_address .. ":" .. local_http_port,
			timeout = 300,
			username = (local_http_username and local_http_password) and local_http_username,
			password = (local_http_username and local_http_password) and local_http_password,
		} or nil,
		tcpRedirect = ("redirect" == tcp_proxy_way and local_tcp_redir_port) and {
			listen = "0.0.0.0:" .. local_tcp_redir_port,
			timeout = 300
		} or nil,
		tcpTproxy = ("tproxy" == tcp_proxy_way and local_tcp_redir_port) and {
			listen = "0.0.0.0:" .. local_tcp_redir_port,
			timeout = 300
		} or nil,
		udpTproxy = (local_udp_redir_port) and {
			listen = "0.0.0.0:" .. local_udp_redir_port,
			timeout = 60
		} or nil
	}

	return jsonc.stringify(config, 1)
end

_G.gen_config = gen_config

if arg[1] then
	local func =_G[arg[1]]
	if func then
		print(func(api.get_function_args(arg)))
	end
end
