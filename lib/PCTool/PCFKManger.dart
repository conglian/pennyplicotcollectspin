import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_tba_info/flutter_tba_info.dart';
import 'package:http/http.dart' as http;
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../PCModel/PCFKModel.dart';
import 'package:pennyplicotollespinFK/pennyplicotollespinFK.dart';
import 'PCLogger.dart';
import 'PCAnalytics.dart';
import 'pc_extension_help.dart';

class PCFKManger {
  static final PCFKManger _instance = PCFKManger._internal();

  factory PCFKManger() {
    return _instance;
  }

  PCFKManger._internal();

  PCFkModel fkModel = PCFkModel();

  Future<void> initFKJson() async {
    if (fkModel.ui.device == 0) {
      String jsonString = await rootBundle.loadString("c177_risk_control".jsons());
      asLog.info('risk_control=$jsonString');
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      fkModel = PCFkModel.fromJson(jsonMap);
    }
  }

  Future<void> initFK() async {
    pc_checkRoot();
    pc_checkVpn();
    pc_checkSim();
    pc_checkSimulator();
    pc_checkDeveloper();
    pc_checkStore();
    pc_checkIP();
    pc_checkNum();
  }

  // 是否需要打开风控
  Future<bool> pc_checkAllStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String types = 'number';
    // behavior
    // bool behavior = await pc_checkUser();
    // asLog.info('behavior=$behavior');
    // if (behavior){
    //   types = 'behavior';
    // }
    // number
    bool number = prefs.getBool('pc_fk_number_status') ?? false;
    asLog.info('number=$number');
    if (number){
      types = 'number';
    }
    // device
    bool device = prefs.getBool('pc_fk_decvice_status') ?? false;
    asLog.info('device=$device');
    if (device){
      types = 'device';
    }
    if (number || device){
      PCAnalytics.event(
        "nkmdl_fk_head_off",
        {
          "types": types,
        },
      );
      return true;
    }
    return false;
  }

  // 获取用户异常行为状态
  Future<bool> pc_checkUser() async {
    // 开关未打开
    // if(fkModel.ui.behavior == 0){
    //   return false;
    // }
    // final prefs = await SharedPreferences.getInstance();
    // 两次rv间隔时间小于30s，3次以上
    // if(prefs.getBool('pc_fk_ad_short_show') == true){
    //   return true;
    // }
    // RV 从播放到收到关闭回调时间小于20s，3次以上
    // if(prefs.getBool('pc_fk_ad_short_close') == true){
    //   return true;
    // }
    // // //现金金额达到提现门槛,视频数少于3次
    // if((prefs.getInt('pc_ad_all_number') ?? 0) < fkModel.behavior.wrong_deem_ad_less && (prefs.getInt('pc_dolpc_old_number') ?? 0) >= 1000){
    //   PCAnalytics.event('risk_chance', {'risk_from' : 'wrong_deem_ad_less'});
    //   return true;
    // }
    // // 用户观看90次RV(不包含插屏)，未到提现门槛
    // if((prefs.getInt('pc_ad_reawrd_all_number') ?? 0) >= fkModel.behavior.wrong_deem_ad_more && (prefs.getInt('pc_dolpc_old_number') ?? 0) < 1000){
    //   PCAnalytics.event('risk_chance', {'risk_from' : 'wrong_deem_ad_more'});
    //   return true;
    // }
    return false;
  }

  // 数字联盟
  pc_checkNum()async{
    var numberUnitID = await PennyplicotollespinFK.instance.pc_getNumberUnitID();
    var url = Uri.parse('https://sg-ddi.shuzilm.cn/q');
    try {
      var response = await http.post(
        url,
        headers: eventHeader,
        body: jsonEncode({"protocol":2,"pkg":await FlutterTbaInfo.instance.getBundleId(),"did":numberUnitID}),
      );
      asLog.success("upload event [Number] success ${response.body}");

      try{
        //{"protocol":2,"ver":"1.0.1","err":0,"device_type":0,"normal_times":0,
        // "duplicate_times":0,"update_times":1,"recall_times":0}
        var json = jsonDecode(response.body);
        if(json["err"] == 0 && json["device_type"] != 0 && fkModel.ui.number == 1){
          PCAnalytics.event('risk_chance', {'risk_from' : 'number'});
          await PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_number_statusName,true);
        }else{
          await PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_number_statusName,false);
        }
      }catch(e){
        await PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_number_statusName,false);
      }

    } catch (e) {
      await PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_number_statusName,false);
      asLog.error('upload event [Number] faild');
    }

  }

  Map<String, String> eventHeader = {
    'Content-Type': 'application/json',
  };

  // 设备 Ip
  pc_checkIP()async{

    var url = Uri.parse('https://ip-prod.moolashjarpiggypro.com/api/czebra');
    try {
      var response = await http.post(
        url,
        headers: eventHeader,
        body: jsonEncode({
          "asnake" : await FlutterTbaInfo.instance.getAndroidId(),
        }),
      );
      asLog.success("upload event [IP] success ${response.body}");
      //{"code":200,"msg":"Success","data":{"blion":false}}
      var result = BoomUniqueStringUtil.decrypt(response.body, 69);
      asLog.success("upload event [IP] success ${result}");
      try{
        var bduck = jsonDecode(result)["data"]["bduck"];
        if(bduck && fkModel.device.contains('ip') && fkModel.ui.device == 1){
          PCAnalytics.event('risk_chance', {'risk_from' : 'ip'});
          await PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_ip_statusName,true);
        }
      }catch(e){
        await PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_ip_statusName,false);
      }

    } catch (e) {
      await PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_ip_statusName,false);
      asLog.error('upload event [IP] faild');
    }
  }

  pc_add_tabsession_custom() async {

    bool root = await pc_checkRoot();
    bool vpn = await pc_checkVpn();
    bool sim = await pc_checkSim();
    bool simulator = await pc_checkSimulator();
    bool developer = await pc_checkDeveloper();
    bool googleplay = await pc_checkStore();
    Map<String, dynamic> customer = {
      'root' : root ? 1 : 0,
      'vpn' : vpn ? 1 : 0,
      'sim' : sim ? 1 : 0,
      'simulator' : simulator ? 1 : 0,
      'developer' : developer ? 1 : 0,
      'googleplay' : googleplay ? 1 : 0,
    };
    PCAnalytics.event('session_custom', customer);

  }

  Future<bool> pc_checkRoot() async {
    var result = await PennyplicotollespinFK.instance.pc_root();
    if(fkModel.ui.device == 0){
      return false;
    }
    if(result && fkModel.device.contains('root')){
      PCAnalytics.event('risk_chance', {'risk_from' : 'root'});
      PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_decvice_statusName,true);
      return true;
    }
    return false;
  }

  Future<bool> pc_checkVpn() async {
    var result = await PennyplicotollespinFK.instance.pc_vpn();
    if(fkModel.ui.device == 0){
      return false;
    }
    if(result && fkModel.device.contains('vpn')){
      PCAnalytics.event('risk_chance', {'risk_from' : 'vpn'});
      PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_decvice_statusName,true);
      return true;
    }
    return false;
  }

  Future<bool> pc_checkSim() async {
    var result = await PennyplicotollespinFK.instance.pc_sim();
    if(fkModel.ui.device == 0){
      return false;
    }
    if(!result && fkModel.device.contains('sim')){
      PCAnalytics.event('risk_chance', {'risk_from' : 'sim'});
      PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_decvice_statusName,true);
      return true;
    }
    return false;
  }

  Future<bool> pc_checkSimulator() async {
    var result = await PennyplicotollespinFK.instance.pc_simulator();
    if(fkModel.ui.device == 0){
      return false;
    }
    if(result && fkModel.device.contains('simulator')){
      PCAnalytics.event('risk_chance', {'risk_from' : 'simulator'});
      PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_decvice_statusName,true);
      return true;
    }
    return false;
  }

  Future<bool> pc_checkDeveloper() async {
    var result = await PennyplicotollespinFK.instance.pc_developer();
    if(fkModel.ui.device == 0){
      return false;
    }
    if(result && fkModel.device.contains('developer')){
      PCAnalytics.event('risk_chance', {'risk_from' : 'developer'});
      PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_decvice_statusName,true);
      return true;
    }
    return false;
  }

  Future<bool> pc_checkStore() async {
    var result = await PennyplicotollespinFK.instance.pc_store();
    if(fkModel.ui.device == 0){
      return false;
    }
    if(!result && fkModel.device.contains('googleplay')){
      PCAnalytics.event('risk_chance', {'risk_from' : 'googleplay'});
      PCLocalProvider.instance.updateBool(PCLocalProvider.instance.pc_fk_decvice_statusName,true);
      return true;
    }
    return false;
  }
}
