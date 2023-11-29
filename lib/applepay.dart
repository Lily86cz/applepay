import 'package:flutter/services.dart';
abstract class ApplePayListener {
  void showTost(String?tip);
  void showLoading();
  void hideLoading();
  void applePaySuccess();
  void hasNoRestorePay();
}


class Applepay {
  
  ///flutter调用原生函数
  static const INITAPPLEPAY = 'initApplePay'; // 初始化苹果支付启动补偿机制或者调version接口更新域名
  static const APPLEPAYSTARTTOPAY = 'applePayStartToPay'; //内购开始下单
  static const RESTOREAPPLEPAY = 'restoreApplePay'; //点击恢复购买下单

  ///原生调用Flutter函数
  static const TOAST = 'toast';
  static const SHOW_LOADING = 'showLoading'; //打开loading
  static const HIDE_LOADING = 'hideLoading'; //关闭loading
  static const APPLEPAY = 'APPLEPAY'; //内购购买成功
  static const HASNORESTORE = 'HASNORESTORE'; //恢复购买没有单


  static const MethodChannel _methodChannel = MethodChannel('applepay');
  static ApplePayListener? _applePayListener;

  Applepay._privateConstructor();

  static final Applepay _instance = Applepay._privateConstructor();

  factory Applepay() {
    return _instance;
  }

  void initChannel() {
    _methodChannel.setMethodCallHandler(methodCallHandler);
  }

  static void addApplePayListener(ApplePayListener applePayListener) {
    _applePayListener = applePayListener;
  }
  
  ///原生调用-原生主动发送数据
  Future<dynamic> methodCallHandler(MethodCall call) async {
    if (call.method == TOAST) {
      //弹出提示
      _applePayListener?.showTost(call.arguments);
     
    } else if (call.method == SHOW_LOADING) {
      //加载loading
       _applePayListener?.showLoading();
    } else if (call.method == HIDE_LOADING) {
      //隐藏loading
     _applePayListener?.hideLoading();
    } else if (call.method == APPLEPAY) {
      //苹果支付成功回调
      _applePayListener?.applePaySuccess();
    } else if (call.method == HASNORESTORE) {
      //没有恢复购买处理
     _applePayListener?.hasNoRestorePay();
    } else {}
  }
  //初始化苹果支付启动补偿机制或者调version接口更新域名
  void initApplePay(Map<String, dynamic> prePayInfo) {
    _methodChannel.invokeMethod(INITAPPLEPAY, prePayInfo);
  }
  
  //下单
  void applePayStartToPay(Map<String, dynamic> payInfo, int type) {
    Map<String, dynamic> info = {
      'description': payInfo["productDetails"].description,
      'id': payInfo["productDetails"].id,
      'currencyCode': payInfo["productDetails"].currencyCode,
      'currencySymbol': payInfo["productDetails"].currencySymbol,
      'price': payInfo["productDetails"].price,
      'rawPrice': payInfo["productDetails"].rawPrice,
      'payTransactionsId': payInfo,
      'type': type, //1钱包2vip3前置付费
    };
    _methodChannel.invokeMethod(APPLEPAYSTARTTOPAY, info);
  }
  //恢复购买
  void restoreApplePay(Map<String, dynamic> restorePayInfo) {
    _methodChannel.invokeMethod(RESTOREAPPLEPAY, '');
  }
}
