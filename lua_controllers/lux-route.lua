local http = require('lux-http')
local lux_verify = require('lux-verify')
local lux_auth_ctrl = require('lux-auth-ctrl')
local lux_cellular_ctrl = require('lux-cellular-ctrl')
local lux_bluetooth_ctrl = require('lux-bluetooth-ctrl')
local lux_esim_ctrl = require('lux-esim-ctrl')
local lux_device_ctrl = require('lux-device-ctrl')
local lux_lan_ctrl = require('lux-lan-ctrl')
local lux_radvd_ctrl = require('lux-radvd-ctrl')
local lux_system_ctrl = require('lux-system-ctrl')
local lux_firewall_ctrl = require('lux-firewall-ctrl')
local lux_alg_ctrl = require('lux-alg-ctrl')
local lux_sms_ctrl = require('lux-sms-ctrl')
local lux_pmip_ctrl = require('lux-pmip-ctrl')
local lux_ipsec_ctrl = require('lux-ipsec-ctrl')
local lux_openvpn_ctrl = require('lux-openvpn-ctrl')
local lux_eogre_ctrl = require('lux-eogre-ctrl')
local lux_mac_address_ctrl = require('lux-mac-address-ctrl')
local lux_ip_filter_ctrl = require('lux-ip-filter-ctrl')
local lux_url_filter_ctrl = require('lux-url-filter-ctrl')
local lux_upnp_ctrl = require('lux-upnp-ctrl')
local lux_diagnostic_ctrl = require('lux-diagnostic-ctrl')

local route = {}

function route.handle_request(env)
  local path, method = http.parse_path_and_method(env)
  if path == '/jiooscc/auth/login' and method == 'POST' then
    lux_auth_ctrl.login()
  elseif path == '/cgi-bin/app/account/auth' and method == 'POST' then
    lux_auth_ctrl.app_login()
  elseif path == '/jiooscc/api/cellular/network' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.get_network_info()
  elseif path == '/jiooscc/api/cellular/network/neighbourCell' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_cellular_ctrl.get_neighbour_cell_info()
  elseif path == '/jiooscc/api/cellular/network/neighbourCellCache' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.get_neighbour_cell_cache()
  elseif path == '/jiooscc/api/cellular/networkInterface' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.get_network_interface_info()
  elseif path == '/jiooscc/api/cellular/networkInterfaceStats/reset' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_cellular_ctrl.reset_network_interface_stats()
  elseif path == '/jiooscc/api/cellular/config' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.get_config()
  elseif path == '/jiooscc/api/cellular/config' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_cellular_ctrl.set_config()
  elseif path == '/jiooscc/api/cellular/defaultAPN' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.get_default_apn()
  elseif path == '/jiooscc/api/cellular/defaultAPN' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_cellular_ctrl.update_default_apn()
  elseif path == '/jiooscc/api/cellular/apns' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.list_apns()
  elseif path == '/jiooscc/api/cellular/apns' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_cellular_ctrl.create_apns()
  elseif path == '/jiooscc/api/cellular/apns' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_cellular_ctrl.update_apns()
  elseif path == '/jiooscc/api/cellular/apns' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_cellular_ctrl.delete_apns(env)
  elseif path == '/jiooscc/api/cellular/verifyPin' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_cellular_ctrl.verify_pin()
  elseif path == '/jiooscc/api/cellularInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.get_app_info()
  elseif path == '/cgi-bin/app/installer/cur_cell_id_list' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_cellular_ctrl.get_app_cell_list()
  elseif path == '/cgi-bin/app/installer/cell_id_info' and method == 'POST' then
    lux_auth_ctrl.app_verify_token(env)
    lux_cellular_ctrl.get_app_cell_info()
  elseif path == '/cgi-bin/app/installer/noSimCellInfo' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_cellular_ctrl.get_no_sim_cell_info()
  elseif path == '/jiooscc/api/noSimCellInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.get_no_sim_cell_info()
  elseif path == '/jiooscc/api/connectionInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_cellular_ctrl.get_app_connection_info()
  elseif path == '/jiooscc/api/bluetooth' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_bluetooth_ctrl.get_info()
  elseif path == '/jiooscc/api/bluetooth' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_bluetooth_ctrl.set_info()
  elseif path == '/cgi-bin/app/esim/release_bt' and method == 'POST' then
    lux_auth_ctrl.app_verify_token(env)
    lux_bluetooth_ctrl.disconnect()
  elseif path == '/cgi-bin/app/esim/network_info' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.get_app_network_info()
  elseif path == '/cgi-bin/app/esim/eid' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.get_eid()
  elseif path == '/jiooscc/api/esim/profiles' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_esim_ctrl.get_profiles()
  elseif path == '/jiooscc/api/esim/profiles' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_esim_ctrl.add_profile()
  elseif path == '/cgi-bin/app/esim/profiles' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.get_app_profiles()
  elseif path == '/cgi-bin/app/esim/profile_install_by_default_smdp' and method == 'POST' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.install_profile_by_default_smdp()
  elseif path == '/jiooscc/api/esim/profile_install' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_esim_ctrl.install_profile()
  elseif path == '/cgi-bin/app/esim/profile_install' and method == 'POST' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.app_install_profile()
  elseif path == '/cgi-bin/app/esim/euicc_info' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.get_euicc_info()
  elseif path == '/cgi-bin/app/esim/memory_reset' and method == 'POST' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.reset_memory()
  elseif path == '/cgi-bin/app/esim/profile_install_state' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.get_profile_install_state()
  elseif path == '/cgi-bin/app/esim/pending_notification' and method == 'POST' then
    lux_auth_ctrl.app_verify_token(env)
    lux_esim_ctrl.send_pending_notification()
  elseif lux_verify.startsWith(path, '/jiooscc/api/esim/profile/') and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    local service_iccid = string.gsub(path, '/jiooscc/api/esim/profile/', '')
    lux_esim_ctrl.update_profile(service_iccid)
  elseif lux_verify.startsWith(path, '/cgi-bin/app/esim/profile/') and method == 'PUT' then
    lux_auth_ctrl.app_verify_token(env)
    local service_iccid = string.gsub(path, '/cgi%-bin/app/esim/profile/', '')
    lux_esim_ctrl.update_profile(service_iccid)
  elseif lux_verify.startsWith(path, '/jiooscc/api/esim/profile/') and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    local service_iccid = string.gsub(path, '/jiooscc/api/esim/profile/', '')
    lux_esim_ctrl.delete_profile(service_iccid)
  elseif path == '/jiooscc/api/web/deviceInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_device_ctrl.get_info()
  elseif path == '/jiooscc/api/deviceInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_device_ctrl.get_app_info()
  elseif path == '/cgi-bin/app/esim/device_info' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_device_ctrl.get_app_esim_device_info()
  elseif path == '/jiooscc/api/softwareInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_device_ctrl.get_software_info()
  elseif path == '/jiooscc/api/deviceConfig' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_device_ctrl.backup_config()
  elseif path == '/jiooscc/api/deviceConfig' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_device_ctrl.restore_config()
  elseif path == '/jiooscc/api/rebootDevice' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_device_ctrl.get_api_reboot()
  elseif path == '/cgi-bin/app/esim/reboot' and method == 'POST' then
    lux_auth_ctrl.app_verify_token(env)
    lux_device_ctrl.get_app_reboot()
  elseif path == '/jiooscc/api/deviceUtilization' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_device_ctrl.get_utilization()
  elseif path == '/jiooscc/api/device/initParams' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_device_ctrl.get_init_params()
  elseif path == '/jiooscc/api/isConnectionAlive' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_device_ctrl.is_connection_alive()
  elseif path == '/jiooscc/api/ethStatus' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_lan_ctrl.get_ethernet_status()
  elseif path == '/jiooscc/api/cdtInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.web_get_cdt()
  elseif path == '/jiooscc/api/cdtInfo' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.web_trigger_cdt()
  elseif path == '/jiooscc/api/lanInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_lan_ctrl.get_status()
  elseif path == '/jiooscc/api/lanMode' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_lan_ctrl.get_mode()
  elseif path == '/jiooscc/api/lanMode' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
--     Due to production testing requirements, mode change cannot be locked
    lux_lan_ctrl.update_mode()
  elseif path == '/jiooscc/api/lanIPv4' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_lan_ctrl.get_ipv4()
  elseif path == '/jiooscc/api/lanIPv4' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.update_ipv4()
  elseif path == '/jiooscc/api/lanIPv4/staticAddresses' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.create_ipv4_static_address()
  elseif path == '/jiooscc/api/lanIPv4/staticAddresses' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.update_ipv4_static_address()
  elseif path == '/jiooscc/api/lanIPv4/staticAddresses' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.delete_ipv4_static_address(env)
  elseif path == '/jiooscc/api/lanIPv4/leaseReservations' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.delete_ipv4_lease_reservation(env)
  elseif path == '/jiooscc/api/lanIPv6' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_lan_ctrl.get_ipv6()
  elseif path == '/jiooscc/api/lanIPv6' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.update_ipv6()
  elseif path == '/jiooscc/api/lanIPv6/leaseReservations' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.delete_ipv6_lease_reservation(env)
  elseif path == '/jiooscc/api/triggerCDT' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_lan_ctrl.trigger_cdt()
  elseif path == '/jiooscc/api/CDTStatus' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_lan_ctrl.get_cdt()
  elseif path =='/cgi-bin/app/installer/CDTStatus' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_lan_ctrl.app_get_cdt()
  elseif path == '/jiooscc/api/radvd' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_radvd_ctrl.get_info()
  elseif path == '/jiooscc/api/radvd' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_radvd_ctrl.update_info()
  elseif path == '/jiooscc/api/system/checkSoftwareUpgrade' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.start_online_upgrade()
  elseif path == '/jiooscc/api/system/checkDownloadSoftware' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.check_online_download_status()
  elseif path == '/jiooscc/api/system/checkSoftwareUpgrade' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.check_upgrade_status()
  elseif path == '/jiooscc/api/system/firmware/initUpgrade' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.init_upgrade()
  elseif path == '/jiooscc/api/system/firmware/checkFOTAStatus' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.check_fota_status()
  elseif path == '/jiooscc/api/system/firmware/upgrade' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.firmware_upgrade()
  elseif path == '/jiooscc/api/system/reset' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.reset()
  elseif path == '/cgi-bin/app/esim/factory_reset' and method == 'POST' then
    lux_auth_ctrl.app_verify_token(env)
    lux_system_ctrl.app_reset()
  elseif path == '/jiooscc/api/factoryReset' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.reset()
  elseif path == '/jiooscc/api/system/reboot' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.reboot()
  elseif path == '/jiooscc/api/system/soc_reboot' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.soc_reboot()
  elseif path == '/jiooscc/api/system/autoReboot' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.get_auto_reboot()
  elseif path == '/jiooscc/api/system/autoReboot' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_system_ctrl.set_auto_reboot()
  elseif path == '/jiooscc/api/system/healthMonitor' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.get_health_monitor()
  elseif path == '/jiooscc/api/system/healthMonitor' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_system_ctrl.set_health_monitor()
  elseif path == '/jiooscc/api/firewallInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_firewall_ctrl.get_info()
  elseif path == '/jiooscc/api/firewallInfo' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_firewall_ctrl.update_info()
  elseif path == '/jiooscc/api/algInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_alg_ctrl.get_info()
  elseif path == '/jiooscc/api/algInfo' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_alg_ctrl.update_info()
  elseif path == '/jiooscc/api/users/info' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.get_user_mgmt_info(env)
  elseif path == '/jiooscc/api/users/info' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.update_user_mgmt_info(env)
  elseif path == '/jiooscc/api/users/password' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.change_pwd()
  elseif path == '/jiooscc/api/users/password' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.check_pwd()

    --  Log Settings API starts
  elseif path == '/jiooscc/api/logs' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.get_app_log()
  elseif path == '/cgi-bin/app/installer/logs' and method == 'GET' then
    lux_auth_ctrl.app_verify_token(env)
    lux_system_ctrl.get_app_log()
  elseif path == '/jiooscc/api/system/logSettings' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.get_log_settings()
  elseif path == '/jiooscc/api/system/logSettings' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.set_log_settings()
  elseif path == '/jiooscc/api/system/tcpDumpSettings' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.get_tcp_dump_settings()
  elseif path == '/jiooscc/api/system/tcpDumpSettings' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.set_tcp_dump_settings()
  elseif path == '/jiooscc/api/system/logFiles/clear' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.clear_log()
  elseif path == '/jiooscc/api/system/logFiles' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.download_logs()
  elseif path == '/jiooscc/api/tcpDump/download' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.download_tcp_dump()
    --  Log Settings API ends

    --  Soc Log Settings API starts
  elseif path == '/jiooscc/api/system/socLogSettings' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.get_soc_log_settings()
  elseif path == '/jiooscc/api/system/socLogSettings' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.set_soc_log_settings()
  elseif path == '/jiooscc/api/system/socLogFiles/clear' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.clear_soc_log()
  elseif path == '/jiooscc/api/system/socLogFiles' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.download_soc_logs()
    -- Soc Log Settings API ends

    --  SMS Settings API starts
  elseif path == '/jiooscc/api/sms/settings' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_sms_ctrl.get_sms_settings()
  elseif path == '/jiooscc/api/sms/settings' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.set_sms_settings()
  elseif path == '/jiooscc/api/sms/inbox' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_sms_ctrl.get_inbox_sms()
  elseif path == '/jiooscc/api/sms/inbox' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.delete_inbox_sms(env)
  elseif path == '/jiooscc/api/sms/sentMessages' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.delete_sms_sent(env)
  elseif path == '/jiooscc/api/sms/send' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.send_sms()
  elseif path == '/jiooscc/api/sms/sentMessages' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_sms_ctrl.get_sent_messages()
  elseif path == '/jiooscc/api/sms/contacts' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_sms_ctrl.get_contact_list()
  elseif path == '/jiooscc/api/sms/contacts' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.create_contact()
  elseif path == '/jiooscc/api/sms/contacts' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.update_contact()
  elseif path == '/jiooscc/api/sms/contacts' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.delete_contact(env)
  elseif path == '/jiooscc/api/sms/contacts/groups' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.move_to_group()
  elseif path == '/jiooscc/api/sms/groups' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_sms_ctrl.get_group_list()
  elseif path == '/jiooscc/api/sms/groups' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.create_group()
  elseif path == '/jiooscc/api/sms/groups' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.update_group()
  elseif path == '/jiooscc/api/sms/groups' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.delete_group(env)
  elseif path == '/jiooscc/api/sms/groups/send' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.send_group_sms()
  elseif path == '/jiooscc/api/sendSMS' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_sms_ctrl.app_send_sms()
    --  SMS Settings API ends

    --  PMIPv6 Settings API starts
  elseif path == '/jiooscc/api/pmipv6' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_pmip_ctrl.get_pmipv6()
  elseif path == '/jiooscc/api/pmipv6' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_pmip_ctrl.set_pmipv6()
    --  PMIPv6 Settings API ends

    --  IPSec Settings API starts
  elseif path == '/jiooscc/api/ipsecInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_ipsec_ctrl.get_info()
  elseif path == '/jiooscc/api/ipsecStatus' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_ipsec_ctrl.update_ipsec_status()
  elseif path == '/jiooscc/api/ipsecRules' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_ipsec_ctrl.add_ipsec_rule()
  elseif path == '/jiooscc/api/ipsecRules' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_ipsec_ctrl.update_ipsec_rule()
  elseif path == '/jiooscc/api/ipsecRules' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_ipsec_ctrl.delete_ipsec_rule(env)
    --  IPSec Settings API ends

    --  OpenVPN Settings API starts
  elseif path == '/jiooscc/api/openVpnInfo' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_openvpn_ctrl.get_info()
  elseif path == '/jiooscc/api/openVpnStatus' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_openvpn_ctrl.update_openvpn_status()
  elseif path == '/jiooscc/api/openVpnRules' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_openvpn_ctrl.add_openvpn_rule()
  elseif path == '/jiooscc/api/openVpnRules' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_openvpn_ctrl.update_openvpn_rule()
  elseif path == '/jiooscc/api/openVpnRules' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_openvpn_ctrl.delete_openvpn_rule(env)
    --  OpenVPN Settings API ends

    --  EoGRE Settings API starts
  elseif path == '/jiooscc/api/eogre' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_eogre_ctrl.get_info()
  elseif path == '/jiooscc/api/eogre' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_eogre_ctrl.update_eogre_status()
  elseif path == '/jiooscc/api/eogre/rules' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_eogre_ctrl.add_eogre_rule()
  elseif path == '/jiooscc/api/eogre/rules' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_eogre_ctrl.update_eogre_rule()
  elseif path == '/jiooscc/api/eogre/rules' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_eogre_ctrl.delete_eogre_rule(env)
    --  EoGRE Settings API ends

    --  ipFilter Settings API starts
  elseif path == '/jiooscc/api/firewall/ipFilter' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_ip_filter_ctrl.get_info()
  elseif path == '/jiooscc/api/firewall/ipFilter' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_ip_filter_ctrl.update_info()
  elseif path == '/jiooscc/api/firewall/ipFilter/entries' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_ip_filter_ctrl.create_entry()
  elseif path == '/jiooscc/api/firewall/ipFilter/entries' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_ip_filter_ctrl.delete_entry(env)
    --  ipFilter Settings API ends

    --  URLFilter Settings API starts
  elseif path == '/jiooscc/api/firewall/urlFilter' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_url_filter_ctrl.get_info()
  elseif path == '/jiooscc/api/firewall/urlFilter' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_url_filter_ctrl.update_info()
  elseif path == '/jiooscc/api/firewall/urlFilter/entries' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_url_filter_ctrl.create_entry()
  elseif path == '/jiooscc/api/firewall/urlFilter/entries' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_url_filter_ctrl.delete_entry(env)
  --  URLFilter Settings API ends

  --  MACAddressFilter Settings API starts
  elseif path == '/jiooscc/api/firewall/availableMacAddressFilter' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_mac_address_ctrl.get_available_mac_address_filter()
  elseif path == '/jiooscc/api/firewall/macAddressFilter' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_mac_address_ctrl.get_info()
  elseif path == '/jiooscc/api/firewall/macAddressFilter' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_mac_address_ctrl.update_info()
  elseif path == '/jiooscc/api/firewall/macAddressFilter/entries' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_mac_address_ctrl.create_entry()
  elseif path == '/jiooscc/api/firewall/macAddressFilter/entries' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_mac_address_ctrl.delete_mac_address_filter(env)
  --  MACAddressFilter Settings API ends

  --  UPnP and port forwarding Settings API starts
  elseif path == '/jiooscc/api/firewall/upnp' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_upnp_ctrl.get_upnp_info()
  elseif path == '/jiooscc/api/firewall/upnp' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_upnp_ctrl.update_upnp_status()
  elseif path == '/jiooscc/api/firewall/portForward' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_upnp_ctrl.get_port_forward()
  elseif path == '/jiooscc/api/firewall/portForward' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_upnp_ctrl.update_port_forward_status()
  elseif path == '/jiooscc/api/firewall/portForward/entries' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_upnp_ctrl.create_port_forwarding_rule()
  elseif path == '/jiooscc/api/firewall/portForward/entries' and method == 'PUT' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_upnp_ctrl.update_port_forwarding_rule()
  elseif path == '/jiooscc/api/firewall/portForward/entries' and method == 'DELETE' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_upnp_ctrl.delete_port_forwarding_rule(env)
  --  UPnP and port forwarding Settings API ends

  --  Diagnostic Settings API starts
  elseif path == '/jiooscc/api/diagnostic/pingTracerouteStatus' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.get_ping_traceroute_status()
  elseif path == '/jiooscc/api/diagnostic/startPingTraceroute' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.start_ping_traceroute()
  elseif path == '/jiooscc/api/diagnostic/pingTraceroute6Status' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.get_ping_traceroute6_status()
  elseif path == '/jiooscc/api/diagnostic/startPingTraceroute6' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.start_ping_traceroute6()
  elseif path == '/jiooscc/api/diagnostic/dnsLookupStatus' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.get_dns_lookup_status()
  elseif path == '/jiooscc/api/diagnostic/dnsLookup' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.dns_lookup()
  elseif path == '/jiooscc/api/diagnostic/displayRoutingTableStatus' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.get_display_routing_table_status()
  elseif path == '/jiooscc/api/diagnostic/displayRoutingTable' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.display_routing_table()
  elseif path == '/jiooscc/api/diagnostic/printResultMessage' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_diagnostic_ctrl.print_result_message()
  --  Diagnostic Settings API ends

  --  Speed Test API starts
  elseif path == '/jiooscc/api/system/speedTest/status' and method == 'GET' then
    lux_auth_ctrl.verify_token(env)
    lux_system_ctrl.get_speed_test_status()
  elseif path == '/jiooscc/api/system/speedTest/start' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_system_ctrl.start_speed_test()
  elseif path == '/jiooscc/api/system/speedTest/stop' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_system_ctrl.stop_speed_test()
  elseif path == '/jiooscc/api/speedtest' and method == 'POST' then
    lux_auth_ctrl.verify_token(env)
    lux_auth_ctrl.verify_control()
    lux_system_ctrl.trigger_rpc_speed_test()
  --  Speed Test API ends

  elseif path == '/jiooscc/health' and method == 'GET' then
    if lux_system_ctrl.is_firmware_upgrade() then
      error({
        code = 500,
        message = 'Device is in firmware upgrade flow.',
      })
    else
      local result = lux_auth_ctrl.check_first_login()
      http:status(200):json({
        result = 'SUCCESS',
        never_logged_in = result
      })
    end
  else
    error({
      code = 404,
      message = 'Not Found',
    })
  end
end

return route
