#!/usr/bin/env nix-shell
#! nix-shell -i bash -p evtest

# 监听键盘类设备, 排除鼠标/触摸板/触屏
# 用法: sudo ./capture-keys.sh

echo "=== 功能键捕获工具 ==="
echo "只监听键盘类设备, 只显示按键按下事件"
echo "=== 开始监听 (按 Ctrl+C 退出) ==="
echo "请依次按下不工作的功能键, 每个键之间停顿2秒..."
echo ""

# 排除: mouse(14,16), touchpad(8), stylus(12), 触屏(9,10,11,17,18,19), audio(5,6,7,13)
# 只监听键盘和热键相关设备
for dev in event0 event1 event2 event3 event4 event15 event20 event21 event22; do
    evtest "/dev/input/$dev" 2>/dev/null | grep --line-buffered -E "EV_KEY|MSC_SCAN" | sed "s/^/[$dev] /" &
done

wait
