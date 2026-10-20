import 'package:flutter/material.dart';

// 加载中弹窗工具类
class LoadingDialog {
  // 显示加载中弹窗，message 默认"加载中..."
  static void show(BuildContext context, {String message = "加载中..."}) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          // 去掉 Dialog 默认白底，用下面自绘的圆角卡片
          backgroundColor: Colors.transparent,
          // 松掉 Dialog 默认最小宽度(280)约束，让白卡片收缩到内容大小
          child: Center(
            child: Container(
              padding: EdgeInsets.all(20),
              // 白色圆角卡片
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                // 高度包裹内容，避免撑满
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(), // 转圈
                  SizedBox(height: 10),
                  Text(message), // 提示文案
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  // 关闭弹窗
  static void hide(BuildContext context) {
    Navigator.pop(context);
  }
}